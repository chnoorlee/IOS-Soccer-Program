import Foundation
import XCTest
@testable import SportsHub

@MainActor
final class NotificationSettingsModelTests: XCTestCase {
    func testRefreshDoesNotPromptWhenPermissionIsUndetermined() async {
        let permissions = StubNotificationPermissionCoordinator(status: .notDetermined)
        let model = NotificationSettingsModel(
            dataProvider: MockSportsDataProvider(),
            permissionCoordinator: permissions,
            installationID: "notification-installation-1234",
            environment: .sandbox,
            currentAccountID: { "account-1" }
        )

        await model.refresh()

        XCTAssertEqual(model.authorizationStatus, .notDetermined)
        XCTAssertEqual(permissions.authorizationRequestCount, 0)
        XCTAssertEqual(permissions.registrationRequestCount, 0)
    }

    func testAuthorizedRefreshLoadsPreferencesAndRegistersWithAPNs() async {
        let permissions = StubNotificationPermissionCoordinator(status: .authorized)
        let model = NotificationSettingsModel(
            dataProvider: MockSportsDataProvider(),
            permissionCoordinator: permissions,
            installationID: "notification-installation-1234",
            environment: .sandbox,
            currentAccountID: { "account-1" }
        )

        await model.refresh()

        XCTAssertEqual(model.authorizationStatus, .authorized)
        XCTAssertTrue(model.preferences?.goal == true)
        XCTAssertTrue(model.preferences?.yellowCard == true)
        XCTAssertTrue(model.preferences?.redCard == true)
        XCTAssertTrue(model.preferences?.substitution == true)
        XCTAssertEqual(permissions.registrationRequestCount, 1)
    }

    func testDeniedPermissionDoesNotRegisterAndExposesDeniedState() async {
        let permissions = StubNotificationPermissionCoordinator(
            status: .notDetermined,
            requestedStatus: .denied
        )
        let model = NotificationSettingsModel(
            dataProvider: MockSportsDataProvider(),
            permissionCoordinator: permissions,
            installationID: "notification-installation-1234",
            environment: .sandbox,
            currentAccountID: { "account-1" }
        )

        await model.requestAuthorization()

        XCTAssertEqual(model.authorizationStatus, .denied)
        XCTAssertEqual(permissions.registrationRequestCount, 0)
    }

    func testDeviceTokenIsHexEncodedAndRegisteredWithoutLoggingMetadata() async throws {
        let permissions = StubNotificationPermissionCoordinator(status: .authorized)
        let provider = MockSportsDataProvider()
        let model = NotificationSettingsModel(
            dataProvider: provider,
            permissionCoordinator: permissions,
            installationID: "notification-installation-1234",
            environment: .sandbox,
            currentAccountID: { "account-1" }
        )
        await model.refresh()
        let token = Data(repeating: 0xab, count: 32)

        await model.registerDeviceToken(
            token,
            locale: "ar_SA",
            timeZone: "Asia/Riyadh"
        )

        let registration = await provider.registeredNotificationDevice(
            installationID: "notification-installation-1234"
        )
        XCTAssertEqual(registration?.token, String(repeating: "ab", count: 32))
        XCTAssertEqual(registration?.locale, "ar_SA")
        XCTAssertEqual(model.pushRegistrationState, .registered)
    }

    func testPreferenceSuccessDoesNotHideIndependentRegistrationFailure() async {
        let permissions = StubNotificationPermissionCoordinator(status: .authorized)
        let model = NotificationSettingsModel(
            dataProvider: MockSportsDataProvider(),
            permissionCoordinator: permissions,
            installationID: "notification-installation-1234",
            environment: .sandbox,
            currentAccountID: { "account-1" }
        )
        await model.refresh()
        model.handleRegistrationFailure()

        await model.setPreference(.goal, enabled: false)

        XCTAssertEqual(model.pushRegistrationState, .failed)
        XCTAssertEqual(model.error, .registrationFailed)
    }

    func testRefreshClearsAccountNotificationStateAfterSignOut() async {
        var accountID: String? = "account-1"
        let model = NotificationSettingsModel(
            dataProvider: MockSportsDataProvider(),
            permissionCoordinator: StubNotificationPermissionCoordinator(status: .authorized),
            installationID: "notification-installation-1234",
            environment: .sandbox,
            currentAccountID: { accountID }
        )
        await model.refresh()
        XCTAssertNotNil(model.preferences)

        accountID = nil
        await model.refresh()

        XCTAssertNil(model.preferences)
        XCTAssertEqual(model.pushRegistrationState, .idle)
        XCTAssertNil(model.error)
    }
}

@MainActor
private final class StubNotificationPermissionCoordinator: NotificationPermissionCoordinating {
    private(set) var status: NotificationAuthorizationState
    private let requestedStatus: NotificationAuthorizationState
    private(set) var authorizationRequestCount = 0
    private(set) var registrationRequestCount = 0
    private(set) var settingsOpenCount = 0

    init(
        status: NotificationAuthorizationState,
        requestedStatus: NotificationAuthorizationState = .authorized
    ) {
        self.status = status
        self.requestedStatus = requestedStatus
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        status
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        status = requestedStatus
        return requestedStatus.canReceiveNotifications
    }

    func registerForRemoteNotifications() {
        registrationRequestCount += 1
    }

    func openSystemSettings() async throws {
        settingsOpenCount += 1
    }
}
