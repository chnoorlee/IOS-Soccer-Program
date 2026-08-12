import UIKit
import UserNotifications

enum NotificationAuthorizationState: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var canReceiveNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .unknown, .notDetermined, .denied:
            false
        }
    }
}

enum NotificationPermissionError: Error, Equatable, Sendable {
    case unavailable
    case settingsUnavailable
}

@MainActor
protocol NotificationPermissionCoordinating: AnyObject {
    func authorizationStatus() async -> NotificationAuthorizationState
    func requestAuthorization() async throws -> Bool
    func registerForRemoteNotifications()
    func openSystemSettings() async throws
}

@MainActor
final class SystemNotificationPermissionCoordinator: NotificationPermissionCoordinating {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func openSystemSettings() async throws {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            throw NotificationPermissionError.settingsUnavailable
        }
        let opened = await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { didOpen in
                continuation.resume(returning: didOpen)
            }
        }
        guard opened else {
            throw NotificationPermissionError.settingsUnavailable
        }
    }
}

@MainActor
final class UnavailableNotificationPermissionCoordinator: NotificationPermissionCoordinating {
    func authorizationStatus() async -> NotificationAuthorizationState { .unknown }
    func requestAuthorization() async throws -> Bool {
        throw NotificationPermissionError.unavailable
    }
    func registerForRemoteNotifications() {}
    func openSystemSettings() async throws {
        throw NotificationPermissionError.unavailable
    }
}
