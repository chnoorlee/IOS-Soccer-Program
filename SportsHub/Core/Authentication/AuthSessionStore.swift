import Foundation
import Security

protocol AuthSessionStoring: Sendable {
    func session() async throws -> AuthSession?
    func saveSession(_ session: AuthSession) async throws
    func clearSession() async throws
}

protocol AuthSessionCoordinating: AuthSessionStoring {
    func validSession() async throws -> AuthSession
}

actor KeychainAuthSessionStore: AuthSessionStoring {
    private let service: String
    private let account: String
    private let invalidationDefaults: UserDefaults
    private let invalidationKey: String
    private let cleanupPendingKey: String

    init(
        service: String = (Bundle.main.bundleIdentifier ?? "SportsHub") + ".authentication",
        account: String = "authenticated-session-v1",
        invalidationDefaults: UserDefaults = .standard
    ) {
        self.service = service
        self.account = account
        self.invalidationDefaults = invalidationDefaults
        invalidationKey = service + ".session-locally-invalidated"
        cleanupPendingKey = service + ".session-keychain-cleanup-pending"
    }

    func session() async throws -> AuthSession? {
        if invalidationDefaults.bool(forKey: invalidationKey) {
            if invalidationDefaults.bool(forKey: cleanupPendingKey) {
                let status = SecItemDelete(baseQuery as CFDictionary)
                guard status == errSecSuccess || status == errSecItemNotFound else {
                    throw AuthenticationError.secureStorageUnavailable
                }
                invalidationDefaults.set(false, forKey: cleanupPendingKey)
            }
            return nil
        }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(readQuery as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw AuthenticationError.secureStorageUnavailable
        }

        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            throw AuthenticationError.secureStorageUnavailable
        }
    }

    func saveSession(_ session: AuthSession) async throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(session)
        } catch {
            throw AuthenticationError.secureStorageUnavailable
        }

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            invalidationDefaults.set(false, forKey: invalidationKey)
            invalidationDefaults.set(false, forKey: cleanupPendingKey)
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw AuthenticationError.secureStorageUnavailable
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else {
            throw AuthenticationError.secureStorageUnavailable
        }
        invalidationDefaults.set(false, forKey: invalidationKey)
        invalidationDefaults.set(false, forKey: cleanupPendingKey)
    }

    func clearSession() async throws {
        invalidationDefaults.set(true, forKey: invalidationKey)
        invalidationDefaults.set(true, forKey: cleanupPendingKey)
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationError.secureStorageUnavailable
        }
        invalidationDefaults.set(false, forKey: cleanupPendingKey)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private var readQuery: [String: Any] {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }
}

actor AuthSessionCoordinator: AuthSessionCoordinating {
    private struct RefreshOperation {
        let id: UUID
        let task: Task<AuthSession, Error>
    }

    private struct MutationOperation {
        let id: UUID
        let task: Task<Void, Error>
    }

    private enum SessionMutation: Sendable {
        case save(AuthSession)
        case clear
    }

    private let store: any AuthSessionStoring
    private let client: any AuthenticationClient
    private let now: @Sendable () -> Date
    private var refreshOperation: RefreshOperation?
    private var mutationOperation: MutationOperation?
    private var mutationGeneration = 0
    private var sessionSuppressed = false

    init(
        store: any AuthSessionStoring,
        client: any AuthenticationClient,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.store = store
        self.client = client
        self.now = now
    }

    func session() async throws -> AuthSession? {
        while true {
            guard !sessionSuppressed else { return nil }
            try await waitForPendingMutation()
            guard !sessionSuppressed else { return nil }
            let generation = mutationGeneration
            let storedSession: AuthSession?
            do {
                storedSession = try await store.session()
            } catch {
                guard generation == mutationGeneration else { continue }
                throw error
            }
            guard generation == mutationGeneration else { continue }
            return storedSession
        }
    }

    func saveSession(_ session: AuthSession) async throws {
        try await enqueue(.save(session))
        sessionSuppressed = false
    }

    func clearSession() async throws {
        sessionSuppressed = true
        try await enqueue(.clear)
    }

    func validSession() async throws -> AuthSession {
        while true {
            guard !sessionSuppressed else { throw AuthenticationError.unauthorized }
            try await waitForPendingMutation()
            guard !sessionSuppressed else { throw AuthenticationError.unauthorized }
            if let refreshOperation {
                return try await finish(refreshOperation)
            }

            let generation = mutationGeneration
            let storedSession: AuthSession?
            do {
                storedSession = try await store.session()
            } catch {
                guard generation == mutationGeneration else { continue }
                throw error
            }
            guard generation == mutationGeneration else { continue }
            guard let session = storedSession else {
                throw AuthenticationError.unauthorized
            }

            // Another reentrant caller may have begun rotation while this actor
            // was awaiting the Keychain read.
            if let refreshOperation {
                return try await finish(refreshOperation)
            }
            if session.hasUsableAccessToken(at: now()) {
                return session
            }
            guard session.hasUsableRefreshToken(at: now()) else {
                throw AuthenticationError.unauthorized
            }

            let operationID = UUID()
            let client = client
            let store = store
            let refreshToken = session.refreshToken
            let task = Task<AuthSession, Error> {
                let refreshed = try await client.refreshSession(refreshToken: refreshToken)
                try Task.checkCancellation()
                try await store.saveSession(refreshed)
                return refreshed
            }
            let operation = RefreshOperation(id: operationID, task: task)
            refreshOperation = operation
            return try await finish(operation)
        }
    }

    private func finish(_ operation: RefreshOperation) async throws -> AuthSession {
        do {
            let refreshed = try await operation.task.value
            if refreshOperation?.id == operation.id {
                refreshOperation = nil
            }
            return refreshed
        } catch {
            if refreshOperation?.id == operation.id {
                refreshOperation = nil
            }
            throw error
        }
    }

    private func enqueue(_ mutation: SessionMutation) async throws {
        mutationGeneration += 1

        let cancelledRefresh = refreshOperation?.task
        cancelledRefresh?.cancel()
        refreshOperation = nil

        let previousMutation = mutationOperation?.task
        let operationID = UUID()
        let store = store
        let task = Task<Void, Error> {
            // A newer explicit login/logout must be the last Keychain writer.
            // Waiting also covers a refresh that passed its cancellation check
            // immediately before the explicit mutation began.
            if let previousMutation {
                _ = try? await previousMutation.value
            }
            if let cancelledRefresh {
                _ = try? await cancelledRefresh.value
            }

            switch mutation {
            case let .save(session):
                try await store.saveSession(session)
            case .clear:
                try await store.clearSession()
            }
        }
        let operation = MutationOperation(id: operationID, task: task)
        mutationOperation = operation

        do {
            try await operation.task.value
            if mutationOperation?.id == operation.id {
                mutationOperation = nil
            }
        } catch {
            if mutationOperation?.id == operation.id {
                mutationOperation = nil
            }
            throw error
        }
    }

    private func waitForPendingMutation() async throws {
        while let operation = mutationOperation {
            do {
                try await operation.task.value
                if mutationOperation?.id == operation.id {
                    mutationOperation = nil
                }
            } catch {
                if mutationOperation?.id == operation.id {
                    mutationOperation = nil
                }
                throw error
            }
        }
    }
}

struct CoordinatedSessionAccessTokenProvider: AccessTokenProviding {
    let coordinator: any AuthSessionCoordinating

    func accessToken() async -> String? {
        guard let session = try? await coordinator.validSession() else { return nil }
        return session.accessToken
    }

    func accessToken(forAccountID accountID: String) async -> String? {
        guard let session = try? await coordinator.validSession(),
              session.user.id == accountID else {
            return nil
        }
        return session.accessToken
    }

    func accountSessionExists() async -> Bool {
        do {
            return try await coordinator.session() != nil
        } catch {
            // Unknown Keychain state must fail closed as an account session.
            return true
        }
    }
}
