import Foundation
import XCTest
@testable import SportsHub

@MainActor
final class AppModelTests: XCTestCase {
    func testPublicCacheClearKeepsGuestPersonalizationSessionAndPreferences() async throws {
        let suiteName = "SportsHubTests.PublicCache.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.english.rawValue, forKey: "app.language")
        defaults.set(true, forKey: "app.onboarding.completed")

        let guestRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubCachePrivacyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: guestRoot) }
        let guestStore = FilePersonalVideoStateStore(rootDirectory: guestRoot)
        let guestProvider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: guestStore
        )
        _ = try await guestProvider.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )

        let session = AppModelTestSession.current
        let client = UnavailableAuthenticationClient()
        let sessionCoordinator = AuthSessionCoordinator(
            store: AppModelTestSessionStore(session: session),
            client: client,
            now: { AppModelTestSession.now }
        )
        let authentication = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: sessionCoordinator,
            guestStore: guestStore,
            defaults: defaults
        )
        await authentication.bootstrap()
        let cache = MemorySportsDataCache(initialPayloads: [
            "public": CachedPayload(
                data: Data("public".utf8),
                storedAt: AppModelTestSession.now,
                etag: "v1"
            )
        ])
        let model = AppModel(
            services: AppServices(
                dataProvider: guestProvider,
                authentication: authentication,
                notificationPermissions: UnavailableNotificationPermissionCoordinator(),
                publicCache: cache
            ),
            defaults: defaults
        )
        let playbackDeviceID = model.playbackDeviceID
        let notificationInstallationID = model.notificationInstallationID
        let loaded = await model.refreshPublicCacheSummary()
        XCTAssertTrue(loaded)

        let cleared = await model.clearPublicCache()
        let guestState = try await guestStore.exportGuestPersonalization()

        XCTAssertTrue(cleared)
        XCTAssertTrue(model.publicCacheSummary.isEmpty)
        XCTAssertEqual(guestState.videoFavorites.map(\.videoID), ["video-highlight-1"])
        XCTAssertEqual(authentication.status, .authenticated(session.user))
        XCTAssertEqual(model.language, .english)
        XCTAssertTrue(model.hasCompletedOnboarding)
        XCTAssertEqual(model.playbackDeviceID, playbackDeviceID)
        XCTAssertEqual(model.notificationInstallationID, notificationInstallationID)
    }

    func testPublicCacheClearFailureKeepsSummaryAndExposesRetryError() async {
        let manager = AppModelTestCacheManager(
            summary: SportsDataCacheSummary(
                entryCount: 3,
                byteCount: 4_096,
                newestStoredAt: Date(timeIntervalSince1970: 1_788_000_000),
                maximumByteCount: 50 * 1_024 * 1_024
            ),
            clearError: .localStorageUnavailable
        )
        let model = AppModel(
            services: AppServices(
                dataProvider: MockSportsDataProvider(),
                authentication: AppEnvironment.makeUnavailableAuthenticationManager(),
                notificationPermissions: UnavailableNotificationPermissionCoordinator(),
                publicCache: manager
            )
        )
        let loaded = await model.refreshPublicCacheSummary()
        XCTAssertTrue(loaded)
        let before = model.publicCacheSummary

        let cleared = await model.clearPublicCache()

        XCTAssertFalse(cleared)
        XCTAssertEqual(model.publicCacheSummary, before)
        XCTAssertEqual(model.publicCacheError, .localStorageUnavailable)
        let attemptsBeforeRetry = await manager.clearAttemptCount()
        XCTAssertEqual(attemptsBeforeRetry, 1)

        let retried = await model.clearPublicCache()
        let attemptsAfterRetry = await manager.clearAttemptCount()

        XCTAssertTrue(retried)
        XCTAssertTrue(model.publicCacheSummary.isEmpty)
        XCTAssertNil(model.publicCacheError)
        XCTAssertEqual(attemptsAfterRetry, 2)
    }

    func testDeviceGuestClearRemovesOnlyPersonalizationAndKeepsPreferences() async throws {
        let suiteName = "SportsHubTests.Privacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.english.rawValue, forKey: "app.language")
        defaults.set(true, forKey: "app.onboarding.completed")
        defaults.set(["riyadh-falcons"], forKey: GuestPersonalizationDefaults.followedTeamIDs)

        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubPrivacyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let guestStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let guestProvider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: guestStore
        )
        _ = try await guestProvider.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )
        _ = try await guestProvider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 80,
            completed: false
        )
        _ = try await guestProvider.setFollow(
            type: .team,
            entityID: "riyadh-falcons",
            isFollowing: true
        )
        let client = UnavailableAuthenticationClient()
        let sessionCoordinator = AuthSessionCoordinator(
            store: AppModelTestSessionStore(),
            client: client
        )
        let authentication = AuthenticationManager(
            isAvailable: false,
            client: client,
            sessionCoordinator: sessionCoordinator,
            guestStore: guestStore,
            defaults: defaults
        )
        let model = AppModel(
            services: AppServices(
                dataProvider: guestProvider,
                authentication: authentication,
                notificationPermissions: UnavailableNotificationPermissionCoordinator()
            ),
            defaults: defaults
        )
        await authentication.bootstrap()
        await model.synchronizeFollows()
        let playbackDeviceID = model.playbackDeviceID
        let notificationInstallationID = model.notificationInstallationID

        let cleared = await model.clearDeviceGuestPersonalization()

        let guestState = try await guestStore.exportGuestPersonalization()
        XCTAssertTrue(cleared)
        XCTAssertEqual(guestState, .empty)
        XCTAssertTrue(authentication.guestSummary.isEmpty)
        XCTAssertTrue(model.followedTeamIDs.isEmpty)
        XCTAssertEqual(model.language, .english)
        XCTAssertTrue(model.hasCompletedOnboarding)
        XCTAssertEqual(model.playbackDeviceID, playbackDeviceID)
        XCTAssertEqual(model.notificationInstallationID, notificationInstallationID)
        XCTAssertNil(defaults.stringArray(forKey: GuestPersonalizationDefaults.followedTeamIDs))
    }

    func testAuthenticatedDeviceGuestClearDoesNotLeakAccountFollowsAfterSignOut() async throws {
        let suiteName = "SportsHubTests.PrivacyIdentity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["legacy-guest-team"], forKey: GuestPersonalizationDefaults.followedTeamIDs)

        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubPrivacyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let guestStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let base = MockSportsDataProvider()
        let guestProvider = LocalPersonalizationSportsDataProvider(base: base, store: guestStore)
        _ = try await guestProvider.setFollow(
            type: .team,
            entityID: "legacy-guest-team",
            isFollowing: true
        )
        let accountProvider = MockSportsDataProvider()
        _ = try await accountProvider.setFollow(
            type: .team,
            entityID: "riyadh-falcons",
            isFollowing: true
        )
        let session = AppModelTestSession.current
        let sessionStore = AppModelTestSessionStore(session: session)
        let client = UnavailableAuthenticationClient()
        let sessionCoordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AppModelTestSession.now }
        )
        let authentication = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: sessionCoordinator,
            guestStore: guestStore,
            defaults: defaults
        )
        await authentication.bootstrap()
        let routedProvider = SessionPersonalizationSportsDataProvider(
            base: base,
            authenticated: accountProvider,
            guest: guestProvider,
            sessionStore: sessionCoordinator
        )
        let model = AppModel(
            services: AppServices(
                dataProvider: routedProvider,
                authentication: authentication,
                notificationPermissions: UnavailableNotificationPermissionCoordinator()
            ),
            defaults: defaults
        )
        await model.synchronizeFollows()
        XCTAssertEqual(model.followedTeamIDs, ["riyadh-falcons"])

        let cleared = await model.clearDeviceGuestPersonalization()

        XCTAssertTrue(cleared)
        XCTAssertEqual(authentication.status, .authenticated(session.user))
        XCTAssertEqual(model.followedTeamIDs, ["riyadh-falcons"])
        XCTAssertNil(defaults.stringArray(forKey: GuestPersonalizationDefaults.followedTeamIDs))

        await authentication.signOut()
        await model.synchronizeFollows()

        let guestFollowsAfterSignOut = try await guestProvider.follows()
        XCTAssertTrue(guestFollowsAfterSignOut.isEmpty)
        XCTAssertTrue(model.followedTeamIDs.isEmpty)
    }

    func testPlaybackDeviceIdentifierIsStableAndPseudonymous() throws {
        let suiteName = "SportsHubTests.Playback.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = AppModel(
            dataProvider: MockSportsDataProvider(),
            defaults: defaults
        )
        let second = AppModel(
            dataProvider: MockSportsDataProvider(),
            defaults: defaults
        )

        XCTAssertEqual(first.playbackDeviceID, second.playbackDeviceID)
        XCTAssertEqual(first.notificationInstallationID, second.notificationInstallationID)
        XCTAssertGreaterThanOrEqual(first.playbackDeviceID.count, 16)
        XCTAssertGreaterThanOrEqual(first.notificationInstallationID.count, 16)
        XCTAssertFalse(first.playbackCapabilities.supportsFairPlay)
    }

    func testLegacyGuestTeamFollowSeedsProviderAndCanBeRemoved() async throws {
        let suiteName = "SportsHubTests.Follows.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["riyadh-falcons"], forKey: "app.followed.teamIDs")
        let provider = MockSportsDataProvider()
        let model = AppModel(dataProvider: provider, defaults: defaults)

        await model.synchronizeFollows()
        let seeded = try await provider.follows()
        XCTAssertEqual(seeded.map(\.entityID), ["riyadh-falcons"])
        XCTAssertTrue(model.followedTeamIDs.contains("riyadh-falcons"))

        let team = try XCTUnwrap(MockSportsData.teams.first {
            $0.id == "riyadh-falcons"
        })
        model.toggleFollow(
            type: .team,
            entityID: team.id,
            entity: .team(team)
        )
        while model.isFollowMutationInProgress(teamID: "riyadh-falcons") {
            await Task.yield()
        }
        let removed = try await provider.follows()
        XCTAssertTrue(removed.isEmpty)
        XCTAssertFalse(model.followedTeamIDs.contains("riyadh-falcons"))
    }

    func testOnboardingCompletionAcceptsEveryFollowType() async throws {
        let interests: [(FollowEntityType, String, FollowEntitySnapshot)] = [
            (
                .team,
                MockSportsData.teams[0].id,
                .team(MockSportsData.teams[0])
            ),
            (
                .player,
                MockSportsData.players[0].id,
                .player(MockSportsData.players[0])
            ),
            (
                .competition,
                MockSportsData.competition.id,
                .competition(MockSportsData.competition)
            )
        ]

        for (type, entityID, snapshot) in interests {
            let suiteName = "SportsHubTests.Onboarding.\(type.rawValue).\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let provider = MockSportsDataProvider()
            _ = try await provider.setFollow(
                type: type,
                entityID: entityID,
                entity: snapshot,
                isFollowing: true
            )
            let model = AppModel(dataProvider: provider, defaults: defaults)

            await model.synchronizeFollows()
            model.completeOnboarding()

            XCTAssertTrue(model.hasCompletedOnboarding, "Expected \(type.rawValue) to qualify")
        }
    }

    func testOnboardingRequiresInterestUnlessUserExplicitlySkips() async throws {
        let suiteName = "SportsHubTests.Onboarding.Skip.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let provider = MockSportsDataProvider()
        let model = AppModel(dataProvider: provider, defaults: defaults)

        model.completeOnboarding()
        XCTAssertFalse(model.hasCompletedOnboarding)

        model.skipOnboarding()
        XCTAssertTrue(model.hasCompletedOnboarding)
        XCTAssertTrue(model.orderedFollows.isEmpty)
        let storedFollows = try await provider.follows()
        XCTAssertTrue(storedFollows.isEmpty)
    }

    func testEditingInterestsPreservesExistingFollows() async throws {
        let suiteName = "SportsHubTests.Onboarding.Edit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let provider = MockSportsDataProvider()
        let team = MockSportsData.teams[0]
        let player = MockSportsData.players[0]
        let competition = MockSportsData.competition
        _ = try await provider.setFollow(
            type: .team,
            entityID: team.id,
            entity: .team(team),
            isFollowing: true
        )
        _ = try await provider.setFollow(
            type: .player,
            entityID: player.id,
            entity: .player(player),
            isFollowing: true
        )
        _ = try await provider.setFollow(
            type: .competition,
            entityID: competition.id,
            entity: .competition(competition),
            isFollowing: true
        )
        let model = AppModel(dataProvider: provider, defaults: defaults)

        await model.synchronizeFollows()
        model.completeOnboarding()
        model.resetOnboarding()

        XCTAssertFalse(model.hasCompletedOnboarding)
        XCTAssertEqual(model.followedTeamIDs, [team.id])
        XCTAssertEqual(model.followedPlayerIDs, [player.id])
        XCTAssertEqual(model.followedCompetitionIDs, [competition.id])

        model.skipOnboarding()
        XCTAssertTrue(model.hasCompletedOnboarding)
        XCTAssertEqual(model.orderedFollows.count, 3)
    }
}

private actor AppModelTestCacheManager: SportsDataCacheManaging {
    private let summary: SportsDataCacheSummary
    private var nextClearError: SportsDataError?
    private var attempts = 0

    init(summary: SportsDataCacheSummary, clearError: SportsDataError? = nil) {
        self.summary = summary
        nextClearError = clearError
    }

    func cacheSummary() throws -> SportsDataCacheSummary {
        summary
    }

    func clearCache() throws {
        attempts += 1
        if let nextClearError {
            self.nextClearError = nil
            throw nextClearError
        }
    }

    func clearAttemptCount() -> Int {
        attempts
    }
}

private actor AppModelTestSessionStore: AuthSessionStoring {
    private var storedSession: AuthSession?

    init(session: AuthSession? = nil) {
        storedSession = session
    }

    func session() -> AuthSession? {
        storedSession
    }

    func saveSession(_ session: AuthSession) {
        storedSession = session
    }

    func clearSession() {
        storedSession = nil
    }
}

private enum AppModelTestSession {
    static let now = Date(timeIntervalSince1970: 1_788_000_000)
    static let current = AuthSession(
        user: AuthUser(
            id: "account-user",
            displayName: "Account User",
            email: "account@example.test",
            createdAt: now.addingTimeInterval(-86_400)
        ),
        accessToken: "account-access-token-1234567890",
        refreshToken: "account-refresh-token-1234567890",
        accessTokenExpiresAt: now.addingTimeInterval(900),
        refreshTokenExpiresAt: now.addingTimeInterval(604_800)
    )
}
