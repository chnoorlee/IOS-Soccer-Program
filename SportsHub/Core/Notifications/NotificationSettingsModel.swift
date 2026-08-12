import Combine
import Foundation

enum PushRegistrationState: Equatable, Sendable {
    case idle
    case registering
    case registered
    case failed
}

enum NotificationSettingsError: Equatable, Sendable {
    case accountRequired
    case permissionRequestFailed
    case settingsUnavailable
    case synchronizationFailed
    case registrationFailed

    var localizationKey: String {
        switch self {
        case .accountRequired: "notifications.error.accountRequired"
        case .permissionRequestFailed: "notifications.error.permission"
        case .settingsUnavailable: "notifications.error.settings"
        case .synchronizationFailed: "notifications.error.sync"
        case .registrationFailed: "notifications.error.registration"
        }
    }
}

@MainActor
final class NotificationSettingsModel: ObservableObject {
    private struct RefreshOperation {
        let id: UUID
        let task: Task<Void, Never>
    }

    private struct PendingDeviceRegistration {
        let accountID: String
        let registration: PushDeviceRegistration
    }

    @Published private(set) var authorizationStatus: NotificationAuthorizationState = .unknown
    @Published private(set) var preferences: NotificationPreferences?
    @Published private(set) var isLoading = false
    @Published private(set) var isRequestingAuthorization = false
    @Published private(set) var updatingPreferences: Set<NotificationPreferenceType> = []
    @Published private(set) var pushRegistrationState: PushRegistrationState = .idle
    @Published private(set) var error: NotificationSettingsError?

    private let dataProvider: any SportsDataProviding
    private let permissionCoordinator: any NotificationPermissionCoordinating
    private let installationID: String
    private let environment: PushNotificationEnvironment
    private let currentAccountID: @MainActor () -> String?
    private var refreshOperation: RefreshOperation?
    private var loadedPreferencesAccountID: String?
    private var isRegisteringDevice = false
    private var queuedRegistration: PendingDeviceRegistration?

    init(
        dataProvider: any SportsDataProviding,
        permissionCoordinator: any NotificationPermissionCoordinating,
        installationID: String,
        environment: PushNotificationEnvironment,
        currentAccountID: @escaping @MainActor () -> String?
    ) {
        self.dataProvider = dataProvider
        self.permissionCoordinator = permissionCoordinator
        self.installationID = installationID
        self.environment = environment
        self.currentAccountID = currentAccountID
    }

    func refresh() async {
        if let operation = refreshOperation {
            await operation.task.value
            return
        }
        let operationID = UUID()
        isLoading = true
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await performRefresh()
        }
        refreshOperation = RefreshOperation(id: operationID, task: task)
        await task.value
        if refreshOperation?.id == operationID {
            refreshOperation = nil
            isLoading = false
        }
    }

    func requestAuthorization() async {
        guard let accountID = currentAccountID() else {
            error = .accountRequired
            return
        }
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        clearError(if: .permissionRequestFailed)
        defer { isRequestingAuthorization = false }

        do {
            _ = try await permissionCoordinator.requestAuthorization()
            authorizationStatus = await permissionCoordinator.authorizationStatus()
            guard currentAccountID() == accountID else {
                await refresh()
                return
            }
            if authorizationStatus.canReceiveNotifications {
                requestRemoteRegistration()
            }
            await loadPreferences(for: accountID)
        } catch {
            authorizationStatus = await permissionCoordinator.authorizationStatus()
            self.error = .permissionRequestFailed
        }
    }

    func openSystemSettings() async {
        do {
            try await permissionCoordinator.openSystemSettings()
            clearError(if: .settingsUnavailable)
        } catch {
            self.error = .settingsUnavailable
        }
    }

    func setPreference(_ type: NotificationPreferenceType, enabled: Bool) async {
        guard let accountID = currentAccountID() else {
            error = .accountRequired
            return
        }
        guard loadedPreferencesAccountID == accountID else { return }
        guard authorizationStatus.canReceiveNotifications,
              updatingPreferences.isEmpty,
              let current = preferences else {
            return
        }

        updatingPreferences.insert(type)
        preferences = current.setting(type, enabled: enabled)
        defer { updatingPreferences.remove(type) }
        do {
            let updated = try await dataProvider.setNotificationPreference(
                type,
                enabled: enabled
            )
            guard currentAccountID() == accountID else {
                preferences = nil
                loadedPreferencesAccountID = nil
                return
            }
            preferences = updated
            clearError(if: .synchronizationFailed)
        } catch {
            guard currentAccountID() == accountID else {
                preferences = nil
                loadedPreferencesAccountID = nil
                return
            }
            preferences = current
            self.error = .synchronizationFailed
        }
    }

    func registerDeviceToken(
        _ token: Data,
        locale: String,
        timeZone: String
    ) async {
        guard let accountID = currentAccountID(),
              authorizationStatus.canReceiveNotifications,
              !token.isEmpty else {
            return
        }
        let tokenString = token.map { String(format: "%02x", $0) }.joined()
        let registration = PushDeviceRegistration(
            installationID: installationID,
            token: tokenString,
            environment: environment,
            locale: locale,
            timeZone: timeZone
        )
        queuedRegistration = PendingDeviceRegistration(
            accountID: accountID,
            registration: registration
        )
        guard !isRegisteringDevice else { return }

        isRegisteringDevice = true
        defer { isRegisteringDevice = false }
        await drainQueuedRegistrations()
    }

    func handleRegistrationFailure() {
        guard currentAccountID() != nil, authorizationStatus.canReceiveNotifications else { return }
        pushRegistrationState = .failed
        error = .registrationFailed
    }

    func dismissError() {
        error = nil
    }

    private func performRefresh() async {
        error = nil
        authorizationStatus = await permissionCoordinator.authorizationStatus()
        guard let accountID = currentAccountID() else {
            queuedRegistration = nil
            loadedPreferencesAccountID = nil
            preferences = nil
            pushRegistrationState = .idle
            error = nil
            return
        }
        if loadedPreferencesAccountID != accountID {
            preferences = nil
            loadedPreferencesAccountID = nil
            if queuedRegistration?.accountID != accountID {
                queuedRegistration = nil
            }
            pushRegistrationState = .idle
        }
        if authorizationStatus.canReceiveNotifications {
            requestRemoteRegistration()
        } else {
            pushRegistrationState = .idle
        }
        await loadPreferences(for: accountID)
        if currentAccountID() != accountID {
            preferences = nil
            loadedPreferencesAccountID = nil
            pushRegistrationState = .idle
            error = nil
        }
    }

    private func loadPreferences(for accountID: String) async {
        do {
            let loaded = try await dataProvider.notificationPreferences()
            guard currentAccountID() == accountID else { return }
            preferences = loaded
            loadedPreferencesAccountID = accountID
            clearError(if: .synchronizationFailed)
        } catch {
            guard currentAccountID() == accountID else { return }
            if self.error == nil || self.error == .synchronizationFailed {
                self.error = .synchronizationFailed
            }
        }
    }

    private func requestRemoteRegistration() {
        if pushRegistrationState != .registered {
            pushRegistrationState = .registering
        }
        permissionCoordinator.registerForRemoteNotifications()
    }

    private func drainQueuedRegistrations() async {
        while let pending = queuedRegistration {
            queuedRegistration = nil
            guard currentAccountID() == pending.accountID else {
                if queuedRegistration == nil {
                    pushRegistrationState = .idle
                    error = nil
                }
                continue
            }
            pushRegistrationState = .registering
            do {
                try await dataProvider.registerNotificationDevice(pending.registration)
                guard currentAccountID() == pending.accountID else {
                    if queuedRegistration == nil {
                        pushRegistrationState = .idle
                        self.error = nil
                    }
                    continue
                }
                if queuedRegistration == nil {
                    pushRegistrationState = .registered
                    clearError(if: .registrationFailed)
                }
            } catch {
                guard currentAccountID() == pending.accountID else {
                    if queuedRegistration == nil {
                        pushRegistrationState = .idle
                        self.error = nil
                    }
                    continue
                }
                if queuedRegistration == nil {
                    pushRegistrationState = .failed
                    self.error = .registrationFailed
                }
            }
        }
        if currentAccountID() == nil {
            pushRegistrationState = .idle
            error = nil
        }
    }

    private func clearError(if expected: NotificationSettingsError) {
        if error == expected {
            error = nil
        }
    }
}
