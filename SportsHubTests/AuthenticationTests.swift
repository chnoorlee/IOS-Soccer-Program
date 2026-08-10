import Foundation
import XCTest
@testable import SportsHub

final class RemoteAuthenticationClientTests: XCTestCase {
    func testAppleSignInUsesNonceAndNeverCachesCredentials() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z"))
        let http = AuthenticationHTTPClient(responses: [
            HTTPResponse(data: AuthenticationPayloads.session, statusCode: 200, headers: [:])
        ])
        let client = try RemoteAuthenticationClient(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: http,
            now: { now }
        )
        let credential = AppleSignInCredential(
            identityToken: "header.payload.signature",
            authorizationCode: "authorization-code",
            rawNonce: "0123456789abcdefghijklmnopqrstuv",
            givenName: "Amina",
            familyName: "Saleh",
            email: "amina@example.test"
        )

        let session = try await client.signInWithApple(credential)
        let capturedRequest = await http.request(at: 0)
        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )

        XCTAssertEqual(request.url?.path, "/v1/auth/apple")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(json["rawNonce"] as? String, credential.rawNonce)
        XCTAssertEqual(json["identityToken"] as? String, credential.identityToken)
        XCTAssertEqual(session.user.displayName, "Amina Saleh")
        XCTAssertEqual(session.accessToken, "access-token-1234567890")
    }

    func testRefreshLogoutAndGuestMergeRotateAndAuthorizeRequests() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z"))
        let http = AuthenticationHTTPClient(responses: [
            HTTPResponse(data: AuthenticationPayloads.session, statusCode: 200, headers: [:]),
            HTTPResponse(data: Data(), statusCode: 204, headers: [:]),
            HTTPResponse(data: AuthenticationPayloads.merge, statusCode: 200, headers: [:])
        ])
        let client = try RemoteAuthenticationClient(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: http,
            now: { now }
        )

        _ = try await client.refreshSession(refreshToken: "refresh-token-1234567890")
        try await client.revokeSession(
            accessToken: "access-token-1234567890",
            refreshToken: "refresh-token-1234567890"
        )
        let mergeResult = try await client.mergeGuestPersonalization(
            GuestPersonalizationState(
                watchProgress: [
                    WatchProgress(
                        videoID: "video-1",
                        positionSeconds: 75,
                        completed: false,
                        updatedAt: now
                    )
                ],
                videoFavorites: [
                    GuestVideoFavoriteRecord(videoID: "video-1", updatedAt: now)
                ],
                articleFavorites: [
                    GuestArticleFavoriteRecord(articleID: "article-1", updatedAt: now)
                ],
                follows: [
                    GuestFollowRecord(
                        type: .team,
                        entityID: "team-home",
                        updatedAt: now
                    )
                ]
            ),
            accessToken: "access-token-1234567890"
        )

        let capturedRefresh = await http.request(at: 0)
        let capturedLogout = await http.request(at: 1)
        let capturedMerge = await http.request(at: 2)
        let refresh = try XCTUnwrap(capturedRefresh)
        let logout = try XCTUnwrap(capturedLogout)
        let merge = try XCTUnwrap(capturedMerge)
        let mergeBody = try XCTUnwrap(merge.httpBody)
        let mergeText = try XCTUnwrap(String(data: mergeBody, encoding: .utf8))

        XCTAssertEqual(refresh.url?.path, "/v1/auth/refresh")
        XCTAssertNil(refresh.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(logout.url?.path, "/v1/auth/logout")
        XCTAssertEqual(
            logout.value(forHTTPHeaderField: "Authorization"),
            "Bearer access-token-1234567890"
        )
        XCTAssertNotNil(logout.value(forHTTPHeaderField: "Idempotency-Key"))
        XCTAssertEqual(merge.url?.path, "/v1/me/guest-merge")
        XCTAssertNotNil(merge.value(forHTTPHeaderField: "Idempotency-Key"))
        XCTAssertTrue(mergeText.contains("\"videoId\":\"video-1\""))
        XCTAssertTrue(mergeText.contains("\"articleId\":\"article-1\""))
        XCTAssertTrue(mergeText.contains("\"entityId\":\"team-home\""))
        XCTAssertFalse(mergeText.contains("titleArabic"))
        XCTAssertFalse(mergeText.contains("hlsURL"))
        XCTAssertEqual(mergeResult.progressUpserted, 1)
        XCTAssertEqual(mergeResult.favoritesUpserted, 1)
        XCTAssertEqual(mergeResult.articleFavoritesUpserted, 1)
        XCTAssertEqual(mergeResult.followsUpserted, 1)
        XCTAssertEqual(mergeResult.serverNewerRetained, 0)
    }

    func testIncompleteMergeAcknowledgementIsRejectedBeforeLocalClear() async throws {
        let http = AuthenticationHTTPClient(responses: [
            HTTPResponse(
                data: AuthenticationPayloads.incompleteMerge,
                statusCode: 200,
                headers: [:]
            )
        ])
        let client = try RemoteAuthenticationClient(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: http,
            now: { AuthenticationFixtures.now }
        )
        let state = GuestPersonalizationState(
            watchProgress: [
                WatchProgress(
                    videoID: "video-1",
                    positionSeconds: 75,
                    completed: false,
                    updatedAt: AuthenticationFixtures.now
                )
            ],
            videoFavorites: []
        )

        do {
            _ = try await client.mergeGuestPersonalization(
                state,
                accessToken: "access-token-1234567890"
            )
            XCTFail("A partial merge acknowledgement must not be accepted")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .contractViolation(field: "mergeAcknowledgement"))
        }
    }

    func testGuestArticleMergeRejectsUnsafeDuplicateAndFutureRecordsBeforeNetwork() async throws {
        let http = AuthenticationHTTPClient(responses: [])
        let client = try RemoteAuthenticationClient(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: http,
            now: { AuthenticationFixtures.now }
        )
        let accessToken = "access-token-1234567890"

        do {
            _ = try await client.mergeGuestPersonalization(
                GuestPersonalizationState(
                    watchProgress: [],
                    videoFavorites: [],
                    articleFavorites: [
                        GuestArticleFavoriteRecord(
                            articleID: "../article-1",
                            updatedAt: AuthenticationFixtures.now
                        )
                    ]
                ),
                accessToken: accessToken
            )
            XCTFail("Unsafe article IDs must be rejected")
        } catch let error as AuthenticationError {
            XCTAssertEqual(
                error,
                .contractViolation(field: "articleFavorites.articleId")
            )
        }

        do {
            _ = try await client.mergeGuestPersonalization(
                GuestPersonalizationState(
                    watchProgress: [],
                    videoFavorites: [],
                    articleFavorites: [
                        GuestArticleFavoriteRecord(
                            articleID: " article-1 ",
                            updatedAt: AuthenticationFixtures.now
                        )
                    ]
                ),
                accessToken: accessToken
            )
            XCTFail("Whitespace-padded article IDs must be rejected")
        } catch let error as AuthenticationError {
            XCTAssertEqual(
                error,
                .contractViolation(field: "articleFavorites.articleId")
            )
        }

        do {
            _ = try await client.mergeGuestPersonalization(
                GuestPersonalizationState(
                    watchProgress: [],
                    videoFavorites: [],
                    articleFavorites: [
                        GuestArticleFavoriteRecord(
                            articleID: "article-1",
                            updatedAt: AuthenticationFixtures.now
                        ),
                        GuestArticleFavoriteRecord(
                            articleID: "article-1",
                            updatedAt: AuthenticationFixtures.now
                        )
                    ]
                ),
                accessToken: accessToken
            )
            XCTFail("Duplicate article favorites must be rejected")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .contractViolation(field: "guestDuplicates"))
        }

        do {
            _ = try await client.mergeGuestPersonalization(
                GuestPersonalizationState(
                    watchProgress: [],
                    videoFavorites: [],
                    articleFavorites: [
                        GuestArticleFavoriteRecord(
                            articleID: "article-1",
                            updatedAt: AuthenticationFixtures.now.addingTimeInterval(301)
                        )
                    ]
                ),
                accessToken: accessToken
            )
            XCTFail("Future-dated article favorites must be rejected")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .contractViolation(field: "articleFavorites"))
        }

        let firstRequest = await http.request(at: 0)
        XCTAssertNil(firstRequest)
    }

    func testAccountDeletionIsAuthorizedUncachedIdempotentAndBodyless() async throws {
        let http = AuthenticationHTTPClient(responses: [
            HTTPResponse(data: Data(), statusCode: 204, headers: [:])
        ])
        let client = try RemoteAuthenticationClient(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: http,
            now: { AuthenticationFixtures.now }
        )

        try await client.deleteAccount(
            accessToken: "access-token-1234567890",
            idempotencyKey: "account-delete-idempotency-key"
        )

        let capturedRequest = await http.request(at: 0)
        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.path, "/v1/me")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer access-token-1234567890"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Idempotency-Key"),
            "account-delete-idempotency-key"
        )
        XCTAssertNil(request.httpBody)

        do {
            try await client.deleteAccount(
                accessToken: "access-token-1234567890",
                idempotencyKey: "short"
            )
            XCTFail("Invalid idempotency keys must be rejected before network access")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .contractViolation(field: "idempotencyKey"))
        }
        let unexpectedSecondRequest = await http.request(at: 1)
        XCTAssertNil(unexpectedSecondRequest)
    }
}

final class SessionPersonalizationSportsDataProviderTests: XCTestCase {
    func testNotificationSettingsUseAccountProviderAndFailClosedForGuest() async throws {
        let sessionStore = InMemoryAuthSessionStore()
        let provider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: MockSportsDataProvider(),
            guest: FailingSportsDataProvider(error: .unauthorized),
            sessionStore: sessionStore
        )

        do {
            _ = try await provider.notificationPreferences()
            XCTFail("Guest notification preferences must not use account or mock state")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .unauthorized)
        }

        try await sessionStore.saveSession(AuthenticationFixtures.session)
        let preferences = try await provider.notificationPreferences()
        XCTAssertTrue(preferences.goal)
    }

    func testIdentityScopedFollowsCannotCrossGuestOrAccountBoundaries() async throws {
        let sessionStore = InMemoryAuthSessionStore()
        let authenticated = MockSportsDataProvider()
        let guest = MockSportsDataProvider()
        let provider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: authenticated,
            guest: guest,
            sessionStore: sessionStore
        )
        let team = MockSportsData.teams[0]

        _ = try await provider.setFollow(
            type: .team,
            entityID: team.id,
            entity: .team(team),
            isFollowing: true,
            forAccountID: nil
        )
        try await sessionStore.saveSession(AuthenticationFixtures.session)

        let mismatchedAccountIDs: [String?] = [nil, "another-account"]
        for mismatchedAccountID in mismatchedAccountIDs {
            do {
                _ = try await provider.setFollow(
                    type: .player,
                    entityID: MockSportsData.players[0].id,
                    entity: .player(MockSportsData.players[0]),
                    isFollowing: true,
                    forAccountID: mismatchedAccountID
                )
                XCTFail("A stale identity must fail before selecting a personal provider")
            } catch let error as SportsDataError {
                XCTAssertEqual(error, .unauthorized)
            }
        }

        _ = try await provider.setFollow(
            type: .competition,
            entityID: MockSportsData.competition.id,
            entity: .competition(MockSportsData.competition),
            isFollowing: true,
            forAccountID: AuthenticationFixtures.user.id
        )

        let guestFollows = try await guest.follows()
        let authenticatedFollows = try await authenticated.follows()
        XCTAssertEqual(guestFollows.map(\.type), [.team])
        XCTAssertEqual(authenticatedFollows.map(\.type), [.competition])
    }

    func testExistingSessionNeverFallsBackToGuestPersonalState() async throws {
        let base = MockSportsDataProvider()
        let authenticated = MockSportsDataProvider()
        let guest = MockSportsDataProvider()
        _ = try await authenticated.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )
        _ = try await authenticated.setArticleFavorite(
            articleID: "article-1",
            isFavorite: true
        )
        _ = try await authenticated.setFollow(
            type: .team,
            entityID: "riyadh-falcons",
            isFollowing: true
        )
        _ = try await authenticated.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 312,
            completed: true
        )
        let sessionStore = InMemoryAuthSessionStore()
        let provider = SessionPersonalizationSportsDataProvider(
            base: base,
            authenticated: authenticated,
            guest: guest,
            sessionStore: sessionStore
        )

        let signedOutFavorite = try await provider.videoFavorite(videoID: "video-highlight-1")
        let signedOutArticleFavorite = try await provider.articleFavorite(articleID: "article-1")
        let signedOutFollows = try await provider.follows()
        let signedOutHistory = try await provider.watchHistory()
        XCTAssertFalse(signedOutFavorite.isFavorite)
        XCTAssertFalse(signedOutArticleFavorite.isFavorite)
        XCTAssertTrue(signedOutFollows.isEmpty)
        XCTAssertTrue(signedOutHistory.isEmpty)
        _ = try await provider.setArticleFavorite(articleID: "article-2", isFavorite: true)
        let guestArticleAfterGuestWrite = try await guest.articleFavorite(articleID: "article-2")
        let accountArticleAfterGuestWrite = try await authenticated.articleFavorite(
            articleID: "article-2"
        )
        XCTAssertTrue(guestArticleAfterGuestWrite.isFavorite)
        XCTAssertFalse(accountArticleAfterGuestWrite.isFavorite)

        let expiredSession = AuthSession(
            user: AuthenticationFixtures.user,
            accessToken: "expired-access-token",
            refreshToken: "refresh-token-1234567890",
            accessTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(-60),
            refreshTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(86_400)
        )
        try await sessionStore.saveSession(expiredSession)

        let accountFavorite = try await provider.videoFavorite(videoID: "video-highlight-1")
        let accountArticleFavorite = try await provider.articleFavorite(articleID: "article-1")
        let accountFollows = try await provider.follows()
        let accountHistory = try await provider.watchHistory()
        XCTAssertTrue(accountFavorite.isFavorite)
        XCTAssertTrue(accountArticleFavorite.isFavorite)
        XCTAssertEqual(accountFollows.first?.entityID, "riyadh-falcons")
        XCTAssertTrue(accountHistory.first?.progress.completed == true)
        _ = try await provider.setArticleFavorite(articleID: "article-2", isFavorite: false)
        let guestArticleAfterAccountWrite = try await guest.articleFavorite(articleID: "article-2")
        let accountArticleAfterAccountWrite = try await authenticated.articleFavorite(
            articleID: "article-2"
        )
        XCTAssertTrue(guestArticleAfterAccountWrite.isFavorite)
        XCTAssertFalse(accountArticleAfterAccountWrite.isFavorite)
    }

    func testSingleHistoryRemovalRoutesToCurrentIdentity() async throws {
        let authenticated = MockSportsDataProvider()
        let guest = MockSportsDataProvider()
        _ = try await authenticated.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 312,
            completed: true
        )
        _ = try await guest.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 90,
            completed: false
        )
        let sessionStore = InMemoryAuthSessionStore()
        let provider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: authenticated,
            guest: guest,
            sessionStore: sessionStore
        )

        try await provider.removeWatchHistoryItem(videoID: "video-highlight-1")
        let accountBeforeSignIn = try await authenticated.watchProgress(
            videoID: "video-highlight-1"
        )
        let guestAfterRemoval = try await guest.watchProgress(
            videoID: "video-highlight-1"
        )
        XCTAssertNotNil(accountBeforeSignIn)
        XCTAssertNil(guestAfterRemoval)
        try await sessionStore.saveSession(AuthenticationFixtures.session)

        try await provider.removeWatchHistoryItem(videoID: "video-highlight-1")

        let accountAfterRemoval = try await authenticated.watchProgress(
            videoID: "video-highlight-1"
        )
        XCTAssertNil(accountAfterRemoval)
    }

    func testAuthenticatedHomeDoesNotFallBackToGuestCatalog() async throws {
        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
        let provider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: FailingSportsDataProvider(error: .networkUnavailable),
            guest: MockSportsDataProvider(),
            sessionStore: sessionStore
        )

        do {
            _ = try await provider.homeFeed()
            XCTFail("Authenticated home must not be replaced with guest mock data")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .networkUnavailable)
        }
    }
}

final class AuthSessionCoordinatorTests: XCTestCase {
    func testConcurrentAccessTokenRequestsShareOneRefreshRotation() async throws {
        let expired = AuthSession(
            user: AuthenticationFixtures.user,
            accessToken: "expired-access-token",
            refreshToken: "refresh-token-1234567890",
            accessTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(-1),
            refreshTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(86_400)
        )
        let store = InMemoryAuthSessionStore(session: expired)
        let client = StubAuthenticationClient(
            session: AuthenticationFixtures.session,
            refreshDelayNanoseconds: 20_000_000
        )
        let coordinator = AuthSessionCoordinator(
            store: store,
            client: client,
            now: { AuthenticationFixtures.now }
        )

        async let first = coordinator.validSession()
        async let second = coordinator.validSession()
        let firstSession = try await first
        let secondSession = try await second
        let refreshCallCount = await client.refreshCallCount

        XCTAssertEqual(firstSession, AuthenticationFixtures.session)
        XCTAssertEqual(secondSession, AuthenticationFixtures.session)
        XCTAssertEqual(refreshCallCount, 1)
    }

    func testExplicitSignInWinsOverAnInFlightRefresh() async throws {
        let expired = AuthSession(
            user: AuthenticationFixtures.user,
            accessToken: "expired-access-token",
            refreshToken: "refresh-token-1234567890",
            accessTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(-1),
            refreshTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(86_400)
        )
        let replacement = AuthSession(
            user: AuthUser(
                id: "user-2",
                displayName: "Omar Khalid",
                email: "omar@example.test",
                createdAt: AuthenticationFixtures.now
            ),
            accessToken: "replacement-access-token",
            refreshToken: "replacement-refresh-token",
            accessTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(900),
            refreshTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(604_800)
        )
        let store = InMemoryAuthSessionStore(session: expired)
        let client = StubAuthenticationClient(
            session: AuthenticationFixtures.session,
            refreshDelayNanoseconds: 100_000_000
        )
        let coordinator = AuthSessionCoordinator(
            store: store,
            client: client,
            now: { AuthenticationFixtures.now }
        )

        let refresh = Task { try await coordinator.validSession() }
        while true {
            let refreshCallCount = await client.refreshCallCount
            if refreshCallCount > 0 { break }
            await Task.yield()
        }
        try await coordinator.saveSession(replacement)
        do {
            _ = try await refresh.value
        } catch {
            // Cancellation is expected when explicit sign-in wins the race.
        }
        let stored = try await coordinator.session()

        XCTAssertEqual(stored, replacement)
    }
}

final class GuestPersonalizationBatchTests: XCTestCase {
    func testLargeGuestStateIsSplitWithoutDroppingOrDuplicatingRecords() {
        let progress = (0..<501).map { index in
            WatchProgress(
                videoID: "progress-\(index)",
                positionSeconds: index,
                completed: false,
                updatedAt: AuthenticationFixtures.now
            )
        }
        let favorites = (0..<1_001).map { index in
            GuestVideoFavoriteRecord(
                videoID: "favorite-\(index)",
                updatedAt: AuthenticationFixtures.now
            )
        }
        let articleFavorites = (0..<601).map { index in
            GuestArticleFavoriteRecord(
                articleID: "article-favorite-\(index)",
                updatedAt: AuthenticationFixtures.now
            )
        }
        let follows = (0..<751).map { index in
            GuestFollowRecord(
                type: .team,
                entityID: "team-\(index)",
                updatedAt: AuthenticationFixtures.now
            )
        }

        let batches = GuestPersonalizationState(
            watchProgress: progress,
            videoFavorites: favorites,
            articleFavorites: articleFavorites,
            follows: follows
        ).mergeBatches()

        XCTAssertEqual(batches.count, 3)
        XCTAssertTrue(batches.allSatisfy { $0.watchProgress.count <= 500 })
        XCTAssertTrue(batches.allSatisfy { $0.videoFavorites.count <= 500 })
        XCTAssertTrue(batches.allSatisfy { $0.articleFavorites.count <= 500 })
        XCTAssertTrue(batches.allSatisfy { $0.follows.count <= 500 })
        XCTAssertEqual(batches.flatMap(\.watchProgress), progress)
        XCTAssertEqual(batches.flatMap(\.videoFavorites), favorites)
        XCTAssertEqual(batches.flatMap(\.articleFavorites), articleFavorites)
        XCTAssertEqual(batches.flatMap(\.follows), follows)
    }
}

@MainActor
final class AuthenticationManagerTests: XCTestCase {
    func testSnapshotOnlyDeviceDataRemainsVisibleAndCanBeClearedWithoutMerge() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let guestStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let details = try await MockSportsDataProvider().videoDetails(id: "video-highlight-1")
        try await guestStore.recordVideo(details.video)
        let client = UnavailableAuthenticationClient()
        let coordinator = AuthSessionCoordinator(
            store: InMemoryAuthSessionStore(),
            client: client
        )
        let manager = AuthenticationManager(
            isAvailable: false,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore
        )

        await manager.bootstrap()

        XCTAssertEqual(manager.guestSummary.videoSnapshotCount, 1)
        XCTAssertFalse(manager.guestSummary.hasMergeableData)
        XCTAssertFalse(manager.guestSummary.isEmpty)

        let cleared = await manager.clearDeviceGuestPersonalization()
        let clearedSummary = try await guestStore.guestPersonalizationSummary()

        XCTAssertTrue(cleared)
        XCTAssertTrue(clearedSummary.isEmpty)
        XCTAssertTrue(manager.guestSummary.isEmpty)
    }

    func testDeviceGuestClearKeepsAuthenticatedSessionAndAvoidsServerMutation() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let defaultsSuite = "SportsHubAuthTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        defaults.set(["legacy-guest-team"], forKey: GuestPersonalizationDefaults.followedTeamIDs)

        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
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
        let client = StubAuthenticationClient(session: AuthenticationFixtures.session)
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore,
            defaults: defaults
        )

        await manager.bootstrap()
        let cleared = await manager.clearDeviceGuestPersonalization()

        let retainedSession = try await sessionStore.session()
        let guestState = try await guestStore.exportGuestPersonalization()
        let mergeCallCount = await client.mergeCallCount
        let deletionCallCount = await client.deletionCallCount
        let revokeCallCount = await client.revokeCallCount
        XCTAssertTrue(cleared)
        XCTAssertEqual(manager.status, .authenticated(AuthenticationFixtures.user))
        XCTAssertEqual(retainedSession, AuthenticationFixtures.session)
        XCTAssertEqual(guestState, .empty)
        XCTAssertTrue(manager.guestSummary.isEmpty)
        XCTAssertNil(defaults.stringArray(forKey: GuestPersonalizationDefaults.followedTeamIDs))
        XCTAssertEqual(mergeCallCount, 0)
        XCTAssertEqual(deletionCallCount, 0)
        XCTAssertEqual(revokeCallCount, 0)
        XCTAssertNil(manager.lastError)
    }

    func testDeviceGuestClearFailureKeepsDataSessionAndLegacySnapshotForRetry() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let defaultsSuite = "SportsHubAuthTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        defaults.set(["legacy-guest-team"], forKey: GuestPersonalizationDefaults.followedTeamIDs)

        let baseStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let guestProvider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: baseStore
        )
        _ = try await guestProvider.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )
        let failingStore = FailingClearPersonalVideoStateStore(base: baseStore)
        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
        let client = StubAuthenticationClient(session: AuthenticationFixtures.session)
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: failingStore,
            defaults: defaults
        )

        await manager.bootstrap()
        let summaryBeforeClear = manager.guestSummary
        let cleared = await manager.clearDeviceGuestPersonalization()

        let retainedSession = try await sessionStore.session()
        let retainedState = try await baseStore.exportGuestPersonalization()
        XCTAssertFalse(cleared)
        XCTAssertEqual(manager.status, .authenticated(AuthenticationFixtures.user))
        XCTAssertEqual(retainedSession, AuthenticationFixtures.session)
        XCTAssertEqual(retainedState.videoFavorites.count, 1)
        XCTAssertEqual(manager.guestSummary, summaryBeforeClear)
        XCTAssertEqual(
            defaults.stringArray(forKey: GuestPersonalizationDefaults.followedTeamIDs),
            ["legacy-guest-team"]
        )
        XCTAssertEqual(manager.lastError, .deviceStorageUnavailable)
    }

    func testSignInOffersGuestMergeAndClearsOnlyAfterServerSuccess() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let defaultsSuite = "SportsHubAuthTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        defaults.set(["riyadh-falcons"], forKey: GuestPersonalizationDefaults.followedTeamIDs)
        let guestStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let guestProvider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: guestStore
        )
        _ = try await guestProvider.setVideoFavorite(videoID: "video-highlight-1", isFavorite: true)
        _ = try await guestProvider.setArticleFavorite(articleID: "article-1", isFavorite: true)
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

        let sessionStore = InMemoryAuthSessionStore()
        let session = AuthenticationFixtures.session
        let client = StubAuthenticationClient(session: session)
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore,
            defaults: defaults
        )

        await manager.bootstrap()
        XCTAssertEqual(manager.status, .signedOut)

        await manager.signIn(with: AuthenticationFixtures.credential)
        XCTAssertEqual(manager.status, .authenticated(session.user))
        XCTAssertEqual(manager.guestSummary.progressCount, 1)
        XCTAssertEqual(manager.guestSummary.favoriteCount, 1)
        XCTAssertEqual(manager.guestSummary.articleFavoriteCount, 1)
        XCTAssertEqual(manager.guestSummary.followCount, 1)

        await manager.mergeGuestPersonalization()
        XCTAssertTrue(manager.guestSummary.isEmpty)
        XCTAssertEqual(manager.lastMergeResult?.progressUpserted, 1)
        XCTAssertEqual(manager.lastMergeResult?.favoritesUpserted, 1)
        XCTAssertEqual(manager.lastMergeResult?.articleFavoritesUpserted, 1)
        XCTAssertEqual(manager.lastMergeResult?.followsUpserted, 1)
        let exported = try await guestStore.exportGuestPersonalization()
        let mergeCallCount = await client.mergeCallCount
        XCTAssertEqual(exported, .empty)
        XCTAssertNil(defaults.stringArray(forKey: GuestPersonalizationDefaults.followedTeamIDs))
        XCTAssertEqual(mergeCallCount, 1)
    }

    func testBootstrapRefreshesExpiredAccessTokenAndPersistsRotation() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let expired = AuthSession(
            user: AuthenticationFixtures.session.user,
            accessToken: "expired-access-token",
            refreshToken: "refresh-token-1234567890",
            accessTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(-1),
            refreshTokenExpiresAt: AuthenticationFixtures.now.addingTimeInterval(86_400)
        )
        let sessionStore = InMemoryAuthSessionStore(session: expired)
        let guestStore = FilePersonalVideoStateStore(
            rootDirectory: rootDirectory
        )
        let client = StubAuthenticationClient(session: AuthenticationFixtures.session)
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore
        )

        await manager.bootstrap()
        let stored = try await sessionStore.session()
        let refreshCallCount = await client.refreshCallCount
        XCTAssertEqual(manager.status, .authenticated(AuthenticationFixtures.session.user))
        XCTAssertEqual(stored, AuthenticationFixtures.session)
        XCTAssertEqual(refreshCallCount, 1)
    }

    func testFailedGuestMergeRetainsLocalState() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let guestStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let guestProvider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: guestStore
        )
        _ = try await guestProvider.setVideoFavorite(videoID: "video-highlight-1", isFavorite: true)
        _ = try await guestProvider.setArticleFavorite(articleID: "article-1", isFavorite: true)
        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
        let client = StubAuthenticationClient(
            session: AuthenticationFixtures.session,
            mergeError: .networkUnavailable
        )
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore
        )

        await manager.bootstrap()
        await manager.mergeGuestPersonalization()
        let retained = try await guestStore.exportGuestPersonalization()

        XCTAssertEqual(retained.videoFavorites.count, 1)
        XCTAssertEqual(retained.articleFavorites.count, 1)
        XCTAssertEqual(manager.lastError, .networkUnavailable)
        XCTAssertNil(manager.lastMergeResult)
    }

    func testFollowSynchronizationRejectsLateResponseAndPreservesGuestMigrationState() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let defaultsSuite = "SportsHubAuthTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        defaults.set(
            ["riyadh-falcons"],
            forKey: GuestPersonalizationDefaults.followedTeamIDs
        )

        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
        let client = StubAuthenticationClient(session: AuthenticationFixtures.session)
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let authentication = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: FilePersonalVideoStateStore(rootDirectory: rootDirectory),
            defaults: defaults
        )
        await authentication.bootstrap()

        let suspendedHTTP = SuspendedFollowHTTPClient()
        let accountProvider = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: suspendedHTTP,
            cache: MemorySportsDataCache(),
            accessTokenProvider: AuthenticationAccountTokenProvider(
                accountID: AuthenticationFixtures.session.user.id,
                token: "test-token"
            )
        )
        let routedProvider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: accountProvider,
            guest: MockSportsDataProvider(),
            sessionStore: sessionStore
        )
        let model = AppModel(
            services: AppServices(
                dataProvider: routedProvider,
                authentication: authentication,
                notificationPermissions: UnavailableNotificationPermissionCoordinator()
            ),
            defaults: defaults
        )

        let oldIdentitySync = Task { await model.synchronizeFollows() }
        await suspendedHTTP.waitUntilRequested()
        await authentication.signOut()
        await model.synchronizeFollows()

        await suspendedHTTP.resumeWithOldAccountFollow()
        await oldIdentitySync.value

        XCTAssertEqual(authentication.status, .signedOut)
        XCTAssertEqual(model.followedTeamIDs, ["riyadh-falcons"])
        XCTAssertEqual(
            defaults.stringArray(forKey: GuestPersonalizationDefaults.followedTeamIDs),
            ["riyadh-falcons"]
        )
    }

    func testFailedNewIdentitySyncDoesNotExposePreviousAccountFollows() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let defaultsSuite = "SportsHubAuthTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
        let client = StubAuthenticationClient(session: AuthenticationFixtures.session)
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let authentication = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: FilePersonalVideoStateStore(rootDirectory: rootDirectory),
            defaults: defaults
        )
        await authentication.bootstrap()
        let accountProvider = MockSportsDataProvider()
        let accountTeam = MockSportsData.teams[0]
        _ = try await accountProvider.setFollow(
            type: .team,
            entityID: accountTeam.id,
            entity: .team(accountTeam),
            isFollowing: true
        )
        let routedProvider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: accountProvider,
            guest: FailingSportsDataProvider(error: .networkUnavailable),
            sessionStore: sessionStore
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
        XCTAssertEqual(model.followedTeamIDs, [accountTeam.id])

        await authentication.signOut()
        await model.synchronizeFollows()

        XCTAssertEqual(authentication.status, .signedOut)
        XCTAssertTrue(model.orderedFollows.isEmpty)
        XCTAssertEqual(model.followError, .networkUnavailable)
    }

    func testLocalSignOutCompletesWhenRemoteRevocationIsOffline() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
        let guestStore = FilePersonalVideoStateStore(
            rootDirectory: rootDirectory
        )
        let client = StubAuthenticationClient(
            session: AuthenticationFixtures.session,
            revokeError: .networkUnavailable
        )
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore
        )

        await manager.bootstrap()
        await manager.signOut()
        let clearedSession = try await sessionStore.session()

        XCTAssertEqual(manager.status, .signedOut)
        XCTAssertNil(clearedSession)
        XCTAssertEqual(manager.lastError, .networkUnavailable)
    }

    func testAccountDeletionClearsSessionAndAllDeviceGuestPersonalization() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
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
        let client = StubAuthenticationClient(session: AuthenticationFixtures.session)
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore
        )

        await manager.bootstrap()
        let deleted = await manager.deleteAccount()

        let storedSession = try await sessionStore.session()
        let guestState = try await guestStore.exportGuestPersonalization()
        let deletionCallCount = await client.deletionCallCount
        XCTAssertTrue(deleted)
        XCTAssertEqual(manager.status, .signedOut)
        XCTAssertNil(storedSession)
        XCTAssertEqual(guestState, .empty)
        XCTAssertEqual(deletionCallCount, 1)
        XCTAssertNil(manager.lastError)
    }

    func testAccountDeletionFailureKeepsSessionAndDeviceDataForRetry() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let sessionStore = InMemoryAuthSessionStore(session: AuthenticationFixtures.session)
        let guestStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let guestProvider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: guestStore
        )
        _ = try await guestProvider.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )
        let client = StubAuthenticationClient(
            session: AuthenticationFixtures.session,
            deletionError: .networkUnavailable
        )
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore
        )

        await manager.bootstrap()
        let deleted = await manager.deleteAccount()
        let retried = await manager.deleteAccount()

        let storedSession = try await sessionStore.session()
        let guestState = try await guestStore.exportGuestPersonalization()
        let deletionIdempotencyKeys = await client.deletionIdempotencyKeys
        XCTAssertFalse(deleted)
        XCTAssertFalse(retried)
        XCTAssertEqual(manager.status, .authenticated(AuthenticationFixtures.user))
        XCTAssertEqual(storedSession, AuthenticationFixtures.session)
        XCTAssertEqual(guestState.videoFavorites.count, 1)
        XCTAssertEqual(manager.lastError, .networkUnavailable)
        XCTAssertEqual(deletionIdempotencyKeys.count, 2)
        XCTAssertEqual(Set(deletionIdempotencyKeys).count, 1)
    }

    func testCompletedServerDeletionNeverLeavesAuthenticatedUIWhenKeychainClearFails() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubAuthTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let defaultsSuite = "SportsHubAuthTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let sessionStore = FailingClearAuthSessionStore(
            session: AuthenticationFixtures.session
        )
        let guestStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let client = StubAuthenticationClient(session: AuthenticationFixtures.session)
        let coordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let manager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: coordinator,
            guestStore: guestStore,
            defaults: defaults
        )

        await manager.bootstrap()
        let deleted = await manager.deleteAccount()

        let retainedSession = try await sessionStore.session()
        let routedSession = try await coordinator.session()
        XCTAssertTrue(deleted)
        XCTAssertEqual(manager.status, .signedOut)
        XCTAssertEqual(retainedSession, AuthenticationFixtures.session)
        XCTAssertNil(routedSession)
        XCTAssertEqual(manager.lastError, .secureStorageUnavailable)
        XCTAssertTrue(
            defaults.bool(
                forKey: "authentication.account-deletion-local-cleanup-pending"
            )
        )

        let relaunchedCoordinator = AuthSessionCoordinator(
            store: sessionStore,
            client: client,
            now: { AuthenticationFixtures.now }
        )
        let relaunchedManager = AuthenticationManager(
            isAvailable: true,
            client: client,
            sessionCoordinator: relaunchedCoordinator,
            guestStore: guestStore,
            defaults: defaults
        )
        await relaunchedManager.bootstrap()

        let sessionAfterRecovery = try await sessionStore.session()
        XCTAssertEqual(relaunchedManager.status, .signedOut)
        XCTAssertNil(sessionAfterRecovery)
        XCTAssertNil(relaunchedManager.lastError)
        XCTAssertFalse(
            defaults.bool(
                forKey: "authentication.account-deletion-local-cleanup-pending"
            )
        )
    }
}

private actor AuthenticationHTTPClient: HTTPClient {
    private var responses: [HTTPResponse]
    private var requests: [URLRequest] = []

    init(responses: [HTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw SportsDataError.serverUnavailable }
        return responses.removeFirst()
    }

    func request(at index: Int) -> URLRequest? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index]
    }
}

private struct AuthenticationAccountTokenProvider: AccessTokenProviding {
    let accountID: String
    let token: String

    func accessToken() async -> String? { token }

    func accessToken(forAccountID accountID: String) async -> String? {
        accountID == self.accountID ? token : nil
    }
}

private actor SuspendedFollowHTTPClient: HTTPClient {
    private var didReceiveRequest = false
    private var requestWaiter: CheckedContinuation<Void, Never>?
    private var responseWaiter: CheckedContinuation<HTTPResponse, Never>?

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        didReceiveRequest = true
        requestWaiter?.resume()
        requestWaiter = nil
        return await withCheckedContinuation { continuation in
            responseWaiter = continuation
        }
    }

    func waitUntilRequested() async {
        guard !didReceiveRequest else { return }
        await withCheckedContinuation { continuation in
            requestWaiter = continuation
        }
    }

    func resumeWithOldAccountFollow() {
        let response = HTTPResponse(
            data: Data(
                """
                {
                  "data": [{
                    "id": "old-account-follow",
                    "type": "TEAM",
                    "entityId": "old-account-team",
                    "createdAt": "2026-08-05T12:00:00Z",
                    "entity": {
                      "type": "TEAM",
                      "team": {
                        "id": "old-account-team",
                        "name": {"ar": "فريق قديم", "en": "Old account team"},
                        "monogram": "OLD",
                        "accentColorHex": "455A64"
                      }
                    }
                  }]
                }
                """.utf8
            ),
            statusCode: 200,
            headers: [:]
        )
        responseWaiter?.resume(returning: response)
        responseWaiter = nil
    }
}

private actor InMemoryAuthSessionStore: AuthSessionStoring {
    private var storedSession: AuthSession?

    init(session: AuthSession? = nil) {
        storedSession = session
    }

    func session() -> AuthSession? { storedSession }
    func saveSession(_ session: AuthSession) { storedSession = session }
    func clearSession() { storedSession = nil }
}

private actor FailingClearAuthSessionStore: AuthSessionStoring {
    private var storedSession: AuthSession?
    private var clearFailuresRemaining = 1

    init(session: AuthSession?) {
        storedSession = session
    }

    func session() -> AuthSession? { storedSession }
    func saveSession(_ session: AuthSession) { storedSession = session }
    func clearSession() throws {
        if clearFailuresRemaining > 0 {
            clearFailuresRemaining -= 1
            throw AuthenticationError.secureStorageUnavailable
        }
        storedSession = nil
    }
}

private actor StubAuthenticationClient: AuthenticationClient {
    private let session: AuthSession
    private let revokeError: AuthenticationError?
    private let mergeError: AuthenticationError?
    private let deletionError: AuthenticationError?
    private let refreshDelayNanoseconds: UInt64
    private(set) var refreshCallCount = 0
    private(set) var mergeCallCount = 0
    private(set) var revokeCallCount = 0
    private(set) var deletionIdempotencyKeys: [String] = []

    var deletionCallCount: Int {
        deletionIdempotencyKeys.count
    }

    init(
        session: AuthSession,
        revokeError: AuthenticationError? = nil,
        mergeError: AuthenticationError? = nil,
        deletionError: AuthenticationError? = nil,
        refreshDelayNanoseconds: UInt64 = 0
    ) {
        self.session = session
        self.revokeError = revokeError
        self.mergeError = mergeError
        self.deletionError = deletionError
        self.refreshDelayNanoseconds = refreshDelayNanoseconds
    }

    func signInWithApple(_ credential: AppleSignInCredential) -> AuthSession {
        session
    }

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        refreshCallCount += 1
        if refreshDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: refreshDelayNanoseconds)
        }
        return session
    }

    func revokeSession(accessToken: String, refreshToken: String) throws {
        revokeCallCount += 1
        if let revokeError { throw revokeError }
    }

    func deleteAccount(accessToken: String, idempotencyKey: String) throws {
        deletionIdempotencyKeys.append(idempotencyKey)
        if let deletionError { throw deletionError }
    }

    func mergeGuestPersonalization(
        _ state: GuestPersonalizationState,
        accessToken: String
    ) throws -> GuestMergeResult {
        mergeCallCount += 1
        if let mergeError { throw mergeError }
        return GuestMergeResult(
            progressUpserted: state.watchProgress.count,
            favoritesUpserted: state.videoFavorites.count,
            articleFavoritesUpserted: state.articleFavorites.count,
            followsUpserted: state.follows.count,
            serverNewerRetained: 0
        )
    }
}

private actor FailingClearPersonalVideoStateStore: PersonalVideoStateStoring {
    private let base: any PersonalVideoStateStoring

    init(base: any PersonalVideoStateStoring) {
        self.base = base
    }

    func article(id: String) async throws -> Article? {
        try await base.article(id: id)
    }

    func recordArticleIfSaved(_ article: Article) async throws {
        try await base.recordArticleIfSaved(article)
    }

    func favoriteArticles() async throws -> [Article] {
        try await base.favoriteArticles()
    }

    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState {
        try await base.articleFavorite(articleID: articleID)
    }

    func saveArticleFavorite(
        article: Article,
        updatedAt: Date
    ) async throws -> ArticleFavoriteState {
        try await base.saveArticleFavorite(article: article, updatedAt: updatedAt)
    }

    func removeArticleFavorite(articleID: String) async throws -> ArticleFavoriteState {
        try await base.removeArticleFavorite(articleID: articleID)
    }

    func video(id: String) async throws -> SportsVideo? {
        try await base.video(id: id)
    }

    func recordVideo(_ video: SportsVideo) async throws {
        try await base.recordVideo(video)
    }

    func continueWatching() async throws -> [ContinueWatchingItem] {
        try await base.continueWatching()
    }

    func watchHistory() async throws -> [WatchHistoryItem] {
        try await base.watchHistory()
    }

    func removeWatchHistoryItem(videoID: String) async throws {
        try await base.removeWatchHistoryItem(videoID: videoID)
    }

    func clearWatchHistory() async throws {
        try await base.clearWatchHistory()
    }

    func watchProgress(videoID: String) async throws -> WatchProgress? {
        try await base.watchProgress(videoID: videoID)
    }

    func saveWatchProgress(
        video: SportsVideo,
        positionSeconds: Int,
        completed: Bool,
        updatedAt: Date
    ) async throws -> WatchProgress {
        try await base.saveWatchProgress(
            video: video,
            positionSeconds: positionSeconds,
            completed: completed,
            updatedAt: updatedAt
        )
    }

    func favoriteVideos() async throws -> [SportsVideo] {
        try await base.favoriteVideos()
    }

    func videoFavorite(videoID: String) async throws -> VideoFavoriteState {
        try await base.videoFavorite(videoID: videoID)
    }

    func saveFavorite(video: SportsVideo, updatedAt: Date) async throws -> VideoFavoriteState {
        try await base.saveFavorite(video: video, updatedAt: updatedAt)
    }

    func removeFavorite(videoID: String) async throws -> VideoFavoriteState {
        try await base.removeFavorite(videoID: videoID)
    }

    func follows() async throws -> [SportsFollow] {
        try await base.follows()
    }

    func saveFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        updatedAt: Date
    ) async throws -> SportsFollow {
        try await base.saveFollow(
            type: type,
            entityID: entityID,
            entity: entity,
            updatedAt: updatedAt
        )
    }

    func removeFollow(type: FollowEntityType, entityID: String) async throws {
        try await base.removeFollow(type: type, entityID: entityID)
    }

    func exportGuestPersonalization() async throws -> GuestPersonalizationState {
        try await base.exportGuestPersonalization()
    }

    func guestPersonalizationSummary() async throws -> GuestPersonalizationSummary {
        try await base.guestPersonalizationSummary()
    }

    func clearGuestPersonalization() async throws {
        throw SportsDataError.localStorageUnavailable
    }
}

private enum AuthenticationFixtures {
    static let now = Date(timeIntervalSince1970: 1_785_931_200)
    static let user = AuthUser(
        id: "user-1",
        displayName: "Amina Saleh",
        email: "amina@example.test",
        createdAt: now.addingTimeInterval(-86_400)
    )
    static let session = AuthSession(
        user: user,
        accessToken: "access-token-1234567890",
        refreshToken: "refresh-token-1234567890",
        accessTokenExpiresAt: now.addingTimeInterval(900),
        refreshTokenExpiresAt: now.addingTimeInterval(604_800)
    )
    static let credential = AppleSignInCredential(
        identityToken: "header.payload.signature",
        authorizationCode: "authorization-code",
        rawNonce: "0123456789abcdefghijklmnopqrstuv",
        givenName: "Amina",
        familyName: "Saleh",
        email: "amina@example.test"
    )
}

private enum AuthenticationPayloads {
    static let session = Data(
        """
        {
          "data": {
            "user": {
              "id": "user-1",
              "displayName": "Amina Saleh",
              "email": "amina@example.test",
              "createdAt": "2026-08-04T12:00:00Z"
            },
            "accessToken": "access-token-1234567890",
            "refreshToken": "refresh-token-1234567890",
            "accessTokenExpiresAt": "2026-08-05T12:15:00Z",
            "refreshTokenExpiresAt": "2026-08-12T12:00:00Z"
          }
        }
        """.utf8
    )

    static let merge = Data(
        """
        {
          "data": {
            "progressUpserted": 1,
            "favoritesUpserted": 1,
            "articleFavoritesUpserted": 1,
            "followsUpserted": 1,
            "serverNewerRetained": 0
          }
        }
        """.utf8
    )

    static let incompleteMerge = Data(
        """
        {
          "data": {
            "progressUpserted": 0,
            "favoritesUpserted": 0,
            "articleFavoritesUpserted": 0,
            "followsUpserted": 0,
            "serverNewerRetained": 0
          }
        }
        """.utf8
    )
}
