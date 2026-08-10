import Combine
import Foundation

@MainActor
final class AuthenticationManager: ObservableObject {
    private struct PendingAccountDeletion {
        let accountID: String
        let idempotencyKey: String
    }

    @Published private(set) var status: AuthenticationStatus
    @Published private(set) var isBusy = false
    @Published private(set) var guestSummary = GuestPersonalizationSummary(
        progressCount: 0,
        favoriteCount: 0
    )
    @Published private(set) var lastError: AuthenticationError?
    @Published private(set) var lastMergeResult: GuestMergeResult?

    private let isAvailable: Bool
    private let client: any AuthenticationClient
    private let sessionCoordinator: any AuthSessionCoordinating
    private let guestStore: any PersonalVideoStateStoring
    private let defaults: UserDefaults
    private var didBootstrap = false
    private var pendingAccountDeletion: PendingAccountDeletion?

    init(
        isAvailable: Bool,
        client: any AuthenticationClient,
        sessionCoordinator: any AuthSessionCoordinating,
        guestStore: any PersonalVideoStateStoring,
        defaults: UserDefaults = .standard
    ) {
        self.isAvailable = isAvailable
        self.client = client
        self.sessionCoordinator = sessionCoordinator
        self.guestStore = guestStore
        self.defaults = defaults
        status = isAvailable ? .loading : .unavailable
    }

    func bootstrap() async {
        if defaults.bool(forKey: Keys.accountDeletionCleanupPending) {
            didBootstrap = true
            isBusy = true
            status = isAvailable ? .signedOut : .unavailable
            let cleanupCompleted = await completeDeletedAccountLocalCleanup()
            lastError = cleanupCompleted ? nil : .secureStorageUnavailable
            isBusy = false
            return
        }
        guard isAvailable else {
            await refreshGuestSummary()
            return
        }
        guard !didBootstrap else {
            await refreshSessionIfNeeded()
            await refreshGuestSummary()
            return
        }
        didBootstrap = true
        isBusy = true
        defer { isBusy = false }

        do {
            guard try await sessionCoordinator.session() != nil else {
                status = .signedOut
                await refreshGuestSummary()
                return
            }
            let usable = try await sessionCoordinator.validSession()
            status = .authenticated(usable.user)
            lastError = nil
        } catch let error as AuthenticationError {
            await handleBootstrapFailure(error)
        } catch {
            status = .signedOut
            lastError = .secureStorageUnavailable
        }
        await refreshGuestSummary()
    }

    func signIn(with credential: AppleSignInCredential) async {
        guard isAvailable, !isBusy else { return }
        isBusy = true
        lastError = nil
        lastMergeResult = nil
        defer { isBusy = false }

        do {
            let session = try await client.signInWithApple(credential)
            try await sessionCoordinator.saveSession(session)
            pendingAccountDeletion = nil
            status = .authenticated(session.user)
            await refreshGuestSummary()
            publishPersonalStateChange()
        } catch let error as AuthenticationError {
            lastError = error
        } catch {
            lastError = .serverUnavailable
        }
    }

    func reportSignInFailure(_ error: AuthenticationError) {
        guard error != .cancelled else { return }
        lastError = error
    }

    func refreshSessionIfNeeded() async {
        if defaults.bool(forKey: Keys.accountDeletionCleanupPending) {
            guard !isBusy else { return }
            isBusy = true
            status = isAvailable ? .signedOut : .unavailable
            let cleanupCompleted = await completeDeletedAccountLocalCleanup()
            lastError = cleanupCompleted ? nil : .secureStorageUnavailable
            isBusy = false
            publishPersonalStateChange()
            return
        }
        guard isAvailable,
              !isBusy,
              case .authenticated = status else {
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            guard try await sessionCoordinator.session() != nil else {
                status = .signedOut
                return
            }
            let usable = try await sessionCoordinator.validSession()
            status = .authenticated(usable.user)
            lastError = nil
        } catch let error as AuthenticationError {
            if error == .unauthorized {
                await clearInvalidSession()
            } else {
                lastError = error
            }
        } catch {
            lastError = .serverUnavailable
        }
    }

    func mergeGuestPersonalization() async {
        guard isAvailable,
              !isBusy,
              case .authenticated = status else {
            return
        }
        isBusy = true
        lastError = nil
        lastMergeResult = nil
        defer { isBusy = false }

        do {
            let guestState = try await guestStore.exportGuestPersonalization()
            guard guestState.summary.hasMergeableData else {
                await refreshGuestSummary()
                return
            }
            var result = GuestMergeResult(
                progressUpserted: 0,
                favoritesUpserted: 0,
                articleFavoritesUpserted: 0,
                followsUpserted: 0,
                serverNewerRetained: 0
            )
            for batch in guestState.mergeBatches() {
                let session = try await sessionCoordinator.validSession()
                let batchResult = try await client.mergeGuestPersonalization(
                    batch,
                    accessToken: session.accessToken
                )
                result = GuestMergeResult(
                    progressUpserted: result.progressUpserted + batchResult.progressUpserted,
                    favoritesUpserted: result.favoritesUpserted + batchResult.favoritesUpserted,
                    articleFavoritesUpserted: result.articleFavoritesUpserted
                        + batchResult.articleFavoritesUpserted,
                    followsUpserted: result.followsUpserted + batchResult.followsUpserted,
                    serverNewerRetained: result.serverNewerRetained
                        + batchResult.serverNewerRetained
                )
            }
            try await eraseGuestPersonalizationFromDevice()
            lastMergeResult = result
            publishPersonalStateChange()
        } catch let error as AuthenticationError {
            if error == .unauthorized {
                await clearInvalidSession()
            } else {
                lastError = error
            }
        } catch is SportsDataError {
            lastError = .deviceStorageUnavailable
        } catch {
            lastError = .serverUnavailable
        }
    }

    @discardableResult
    func clearDeviceGuestPersonalization() async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        lastError = nil
        lastMergeResult = nil
        defer { isBusy = false }

        do {
            try await eraseGuestPersonalizationFromDevice()
            publishPersonalStateChange()
            return true
        } catch {
            lastError = .deviceStorageUnavailable
            return false
        }
    }

    func signOut() async {
        guard isAvailable, !isBusy else { return }
        isBusy = true
        lastError = nil
        lastMergeResult = nil
        defer { isBusy = false }

        var signOutError: AuthenticationError?
        do {
            let storedSession = try await sessionCoordinator.session()
            if storedSession != nil {
                do {
                    let session = try await sessionCoordinator.validSession()
                    try await client.revokeSession(
                        accessToken: session.accessToken,
                        refreshToken: session.refreshToken
                    )
                } catch let error as AuthenticationError {
                    if error != .unauthorized {
                        signOutError = error
                    }
                } catch {
                    signOutError = .serverUnavailable
                }
            }
        } catch let error as AuthenticationError {
            if error != .unauthorized {
                signOutError = error
            }
        } catch {
            signOutError = .secureStorageUnavailable
        }
        do {
            try await sessionCoordinator.clearSession()
        } catch {
            signOutError = .secureStorageUnavailable
        }
        pendingAccountDeletion = nil
        status = .signedOut
        lastError = signOutError
        await refreshGuestSummary()
        publishPersonalStateChange()
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        guard isAvailable,
              !isBusy,
              case .authenticated = status else {
            return false
        }
        isBusy = true
        lastError = nil
        lastMergeResult = nil
        defer { isBusy = false }

        do {
            let session = try await sessionCoordinator.validSession()
            let deletion = pendingAccountDeletion.flatMap { pending in
                pending.accountID == session.user.id ? pending : nil
            } ?? PendingAccountDeletion(
                accountID: session.user.id,
                idempotencyKey: UUID().uuidString
            )
            pendingAccountDeletion = deletion
            try await client.deleteAccount(
                accessToken: session.accessToken,
                idempotencyKey: deletion.idempotencyKey
            )
        } catch let error as AuthenticationError {
            if error == .unauthorized {
                pendingAccountDeletion = nil
                await clearInvalidSession()
            } else {
                lastError = error
            }
            return false
        } catch {
            lastError = .serverUnavailable
            return false
        }

        pendingAccountDeletion = nil
        defaults.set(true, forKey: Keys.accountDeletionCleanupPending)
        status = .signedOut
        let cleanupCompleted = await completeDeletedAccountLocalCleanup()
        lastError = cleanupCompleted ? nil : .secureStorageUnavailable
        publishPersonalStateChange()
        return true
    }

    @discardableResult
    func refreshGuestSummary() async -> Bool {
        do {
            guestSummary = try await guestStore.guestPersonalizationSummary()
            if lastError == .deviceStorageUnavailable {
                lastError = nil
            }
            return true
        } catch {
            lastError = .deviceStorageUnavailable
            return false
        }
    }

    func dismissError() {
        lastError = nil
    }

    func dismissMergeResult() {
        lastMergeResult = nil
    }

    private func handleBootstrapFailure(_ error: AuthenticationError) async {
        if error == .unauthorized {
            await clearInvalidSession()
            return
        }
        do {
            let cachedSession = try await sessionCoordinator.session()
            if let cached = cachedSession {
                status = .authenticated(cached.user)
            } else {
                status = .signedOut
            }
        } catch {
            status = .signedOut
        }
        lastError = error
    }

    private func clearInvalidSession() async {
        do {
            try await sessionCoordinator.clearSession()
            pendingAccountDeletion = nil
            status = .signedOut
            lastError = .unauthorized
            publishPersonalStateChange()
        } catch {
            pendingAccountDeletion = nil
            status = .signedOut
            lastError = .secureStorageUnavailable
            publishPersonalStateChange()
        }
    }

    private func publishPersonalStateChange() {
        NotificationCenter.default.post(name: .authenticationStateDidChange, object: nil)
    }

    private func completeDeletedAccountLocalCleanup() async -> Bool {
        var cleanupFailed = false
        do {
            try await sessionCoordinator.clearSession()
        } catch {
            cleanupFailed = true
        }
        do {
            try await eraseGuestPersonalizationFromDevice()
        } catch {
            cleanupFailed = true
            await refreshGuestSummary()
        }
        if !cleanupFailed {
            defaults.removeObject(forKey: Keys.accountDeletionCleanupPending)
        }
        return !cleanupFailed
    }

    private func eraseGuestPersonalizationFromDevice() async throws {
        let legacyFollowIDs = defaults.stringArray(
            forKey: GuestPersonalizationDefaults.followedTeamIDs
        )
        // Remove the legacy migration source first so a process termination after
        // file deletion cannot resurrect follows that the user already cleared.
        defaults.removeObject(forKey: GuestPersonalizationDefaults.followedTeamIDs)
        do {
            try await guestStore.clearGuestPersonalization()
        } catch {
            if let legacyFollowIDs {
                defaults.set(
                    legacyFollowIDs,
                    forKey: GuestPersonalizationDefaults.followedTeamIDs
                )
            }
            throw error
        }
        guestSummary = GuestPersonalizationState.empty.summary
    }

    private enum Keys {
        static let accountDeletionCleanupPending =
            "authentication.account-deletion-local-cleanup-pending"
    }
}
