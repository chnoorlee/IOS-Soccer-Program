import Foundation
import XCTest
@testable import SportsHub

final class ArticleCommunityTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    func testCommentPageAcceptsOnlyPublishedUniqueComments() throws {
        let decoded = try APIJSON.makeDecoder().decode(
            ArticleCommentListResponseDTO.self,
            from: Self.commentPage(state: "PUBLISHED")
        )
        let page = try decoded.domain(
            expectedArticleID: "article-one",
            limit: 20,
            now: now
        )

        XCTAssertEqual(page.comments.map(\.id), ["comment-one"])
        XCTAssertEqual(page.comments.first?.articleID, "article-one")
        XCTAssertEqual(page.comments.first?.authorID, "author-one")
        XCTAssertFalse(page.hasMore)

        let pending = try APIJSON.makeDecoder().decode(
            ArticleCommentListResponseDTO.self,
            from: Self.commentPage(state: "PENDING")
        )
        XCTAssertThrowsError(
            try pending.domain(expectedArticleID: "article-one", limit: 20, now: now)
        )

        let duplicate = try APIJSON.makeDecoder().decode(
            ArticleCommentListResponseDTO.self,
            from: Self.duplicateCommentPage
        )
        XCTAssertThrowsError(
            try duplicate.domain(expectedArticleID: "article-one", limit: 20, now: now)
        )

        let unordered = try APIJSON.makeDecoder().decode(
            ArticleCommentListResponseDTO.self,
            from: Self.unorderedCommentPage
        )
        XCTAssertThrowsError(
            try unordered.domain(expectedArticleID: "article-one", limit: 20, now: now)
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.createdAt")
            )
        }
    }

    func testCommentMutationDTOMapsModerationStatesAndOwnership() throws {
        for state in ["PENDING", "PUBLISHED", "REJECTED"] {
            let response = try APIJSON.makeDecoder().decode(
                ArticleCommentResponseDTO.self,
                from: Self.commentResponse(state: state, isMine: true)
            )
            let comment = try response.data.domain(
                field: "data",
                expectedArticleID: "article-one",
                publishedOnly: false,
                now: now
            )
            XCTAssertTrue(comment.isMine)
            XCTAssertEqual(comment.moderationState.rawValue, state)
        }

        let removed = try APIJSON.makeDecoder().decode(
            ArticleCommentResponseDTO.self,
            from: Self.commentResponse(state: "REMOVED", isMine: true)
        )
        let removedComment = try removed.data.domain(
            field: "data",
            expectedArticleID: "article-one",
            publishedOnly: false,
            now: now
        )
        XCTAssertEqual(removedComment.moderationState, .removed)

        let notMine = try APIJSON.makeDecoder().decode(
            ArticleCommentResponseDTO.self,
            from: Self.commentResponse(state: "PENDING", isMine: false)
        )
        let notMineComment = try notMine.data.domain(
            field: "data",
            expectedArticleID: "article-one",
            publishedOnly: false,
            now: now
        )
        XCTAssertFalse(notMineComment.isMine)
    }

    func testReactionSummaryRequiresAllAndOnlyKnownNonnegativeTotals() throws {
        let valid = try APIJSON.makeDecoder().decode(
            ArticleReactionResponseDTO.self,
            from: Data(
                """
                {"data":{"myReaction":null,"totals":{"LIKE":2,"INSIGHTFUL":1,"CELEBRATE":0}}}
                """.utf8
            )
        )
        let summary = try valid.data.domain()
        XCTAssertNil(summary.myReaction)
        XCTAssertEqual(summary.total(for: .like), 2)

        for totals in [
            "{\"LIKE\":2,\"INSIGHTFUL\":1}",
            "{\"LIKE\":2,\"INSIGHTFUL\":1,\"CELEBRATE\":0,\"ANGRY\":4}",
            "{\"LIKE\":-1,\"INSIGHTFUL\":1,\"CELEBRATE\":0}"
        ] {
            let payload = Data(
                "{\"data\":{\"myReaction\":null,\"totals\":\(totals)}}".utf8
            )
            let decoded = try APIJSON.makeDecoder().decode(
                ArticleReactionResponseDTO.self,
                from: payload
            )
            XCTAssertThrowsError(try decoded.data.domain())
        }
    }

    func testMockCommunityRoundTripUsesPendingModerationAndConfirmedBlock() async throws {
        let fixedNow = now
        let provider = MockSportsDataProvider(now: { fixedNow })
        let before = try await provider.articleComments(
            articleID: "article-1",
            cursor: nil,
            limit: 20
        )
        XCTAssertEqual(before.comments.count, 3)

        let selected = try await provider.setArticleReaction(
            articleID: "article-1",
            reaction: .insightful
        )
        XCTAssertEqual(selected.myReaction, .insightful)
        let removed = try await provider.setArticleReaction(
            articleID: "article-1",
            reaction: nil
        )
        XCTAssertNil(removed.myReaction)

        let submitted = try await provider.createArticleComment(
            articleID: "article-1",
            body: "A new comment"
        )
        XCTAssertEqual(submitted.moderationState, .pending)
        XCTAssertTrue(submitted.isMine)
        let stillPublic = try await provider.articleComments(
            articleID: "article-1",
            cursor: nil,
            limit: 20
        )
        XCTAssertFalse(stillPublic.comments.contains(where: { $0.id == submitted.id }))

        let reported = try await provider.reportArticleComment(
            commentID: "comment-demo-1",
            reason: .harassment,
            details: nil
        )
        XCTAssertEqual(reported.reportID, "report-comment-demo-1")
        try await provider.blockCommunityAuthor(authorID: "author-noura")
        let afterBlock = try await provider.articleComments(
            articleID: "article-1",
            cursor: nil,
            limit: 20
        )
        XCTAssertFalse(afterBlock.comments.contains(where: { $0.authorID == "author-noura" }))
    }

    func testCommunityNeverCrossesRemoteToMockFallbackBoundary() async throws {
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider()
        )

        do {
            _ = try await provider.articleComments(
                articleID: "article-1",
                cursor: nil,
                limit: 20
            )
            XCTFail("Community speech must not use fictional fallback")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .networkUnavailable)
        }
        do {
            _ = try await provider.setArticleReaction(articleID: "article-1", reaction: .like)
            XCTFail("Community mutations must not use fictional fallback state")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .networkUnavailable)
        }
    }

    func testSessionCommunityMutationFailsClosedWhenTokenIdentityDoesNotMatch() async throws {
        let client = CommunityCountingHTTPClient()
        let remote = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1")),
            client: client,
            cache: MemorySportsDataCache(),
            accessTokenProvider: CommunityBoundTokenProvider(
                accountID: "account-a",
                token: "token-a"
            )
        )
        let sessionStore = CommunitySessionStore(
            session: Self.session(accountID: "account-b")
        )
        let provider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: remote,
            guest: MockSportsDataProvider(),
            sessionStore: sessionStore,
            communityMutationsEnabled: true
        )

        do {
            _ = try await provider.setArticleReaction(articleID: "article-1", reaction: .like)
            XCTFail("A different account token must never serve community state")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testCommunityReleaseGateNeedsEnablementAndBothSecureURLs() throws {
        let standards = try XCTUnwrap(URL(string: "https://publisher.example/community"))
        let support = try XCTUnwrap(URL(string: "https://publisher.example/support"))
        XCTAssertTrue(
            CommunityConfiguration(
                isEnabled: true,
                standardsURL: standards,
                supportURL: support
            ).isReleaseGateSatisfied
        )
        XCTAssertFalse(
            CommunityConfiguration(
                isEnabled: false,
                standardsURL: standards,
                supportURL: support
            ).isReleaseGateSatisfied
        )
        XCTAssertFalse(
            CommunityConfiguration(
                isEnabled: true,
                standardsURL: standards,
                supportURL: nil
            ).isReleaseGateSatisfied
        )
        XCTAssertFalse(
            CommunityConfiguration(
                isEnabled: true,
                standardsURL: try XCTUnwrap(URL(string: "http://publisher.example/community")),
                supportURL: support
            ).isReleaseGateSatisfied
        )
        XCTAssertFalse(
            CommunityConfiguration(
                isEnabled: true,
                standardsURL: try XCTUnwrap(URL(string: "https://api.example.invalid/community")),
                supportURL: support
            ).isReleaseGateSatisfied
        )
    }

    func testCommunityMutationGateFailsClosedAtTheDataRouter() async throws {
        let sessionStore = CommunitySessionStore(session: Self.session(accountID: "account-a"))
        let provider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: MockSportsDataProvider(),
            guest: MockSportsDataProvider(),
            sessionStore: sessionStore
        )

        do {
            _ = try await provider.setArticleReaction(articleID: "article-1", reaction: .like)
            XCTFail("Disabled community mutations must fail below the UI layer")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .forbidden)
        }

        let signedOutProvider = SessionPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            authenticated: MockSportsDataProvider(),
            guest: MockSportsDataProvider(),
            sessionStore: CommunitySessionStore(session: nil),
            communityMutationsEnabled: true
        )
        do {
            _ = try await signedOutProvider.createArticleComment(
                articleID: "article-1",
                body: "A comment"
            )
            XCTFail("Signed-out community mutations must fail closed")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
    }

    private static func commentPage(state: String) -> Data {
        Data(
            """
            {
              "data": [{
                "id": "comment-one",
                "articleId": "article-one",
                "body": "A useful observation.",
                "authorId": "author-one",
                "authorDisplayName": "Noura",
                "moderationState": "\(state)",
                "isMine": false,
                "createdAt": "2026-08-05T12:00:00Z"
              }],
              "page": {"nextCursor": null, "hasMore": false}
            }
            """.utf8
        )
    }

    private static let duplicateCommentPage = Data(
        """
        {
          "data": [
            {
              "id": "comment-one",
              "articleId": "article-one",
              "body": "First",
              "authorId": "author-one",
              "authorDisplayName": "Noura",
              "moderationState": "PUBLISHED",
              "isMine": false,
              "createdAt": "2026-08-05T12:00:00Z"
            },
            {
              "id": "comment-one",
              "articleId": "article-one",
              "body": "Second",
              "authorId": "author-two",
              "authorDisplayName": "Sami",
              "moderationState": "PUBLISHED",
              "isMine": false,
              "createdAt": "2026-08-05T11:00:00Z"
            }
          ],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    private static let unorderedCommentPage = Data(
        """
        {
          "data": [
            {
              "id": "comment-old",
              "articleId": "article-one",
              "body": "Older",
              "authorId": "author-one",
              "authorDisplayName": "Noura",
              "moderationState": "PUBLISHED",
              "isMine": false,
              "createdAt": "2026-08-05T11:00:00Z"
            },
            {
              "id": "comment-new",
              "articleId": "article-one",
              "body": "Newer",
              "authorId": "author-two",
              "authorDisplayName": "Sami",
              "moderationState": "PUBLISHED",
              "isMine": false,
              "createdAt": "2026-08-05T12:00:00Z"
            }
          ],
          "page": {"nextCursor": null, "hasMore": false}
        }
        """.utf8
    )

    private static func commentResponse(state: String, isMine: Bool) -> Data {
        Data(
            """
            {
              "data": {
                "id": "comment-response",
                "articleId": "article-one",
                "body": "A useful observation.",
                "authorId": "author-one",
                "authorDisplayName": "Noura",
                "moderationState": "\(state)",
                "isMine": \(isMine),
                "createdAt": "2026-08-05T12:00:00Z"
              }
            }
            """.utf8
        )
    }

    private static func session(accountID: String) -> AuthSession {
        AuthSession(
            user: AuthUser(
                id: accountID,
                displayName: "Test User",
                email: nil,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            accessToken: "access-token",
            refreshToken: "refresh-token",
            accessTokenExpiresAt: Date(timeIntervalSince1970: 1_900_000_000),
            refreshTokenExpiresAt: Date(timeIntervalSince1970: 1_910_000_000)
        )
    }
}

private actor CommunityCountingHTTPClient: HTTPClient {
    private(set) var requestCount = 0

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requestCount += 1
        throw SportsDataError.serverUnavailable
    }
}

private struct CommunityBoundTokenProvider: AccessTokenProviding {
    let accountID: String
    let token: String

    func accessToken() async -> String? { token }

    func accessToken(forAccountID accountID: String) async -> String? {
        accountID == self.accountID ? token : nil
    }
}

private actor CommunitySessionStore: AuthSessionStoring {
    private var storedSession: AuthSession?

    init(session: AuthSession?) {
        storedSession = session
    }

    func session() async throws -> AuthSession? { storedSession }
    func saveSession(_ session: AuthSession) async throws { storedSession = session }
    func clearSession() async throws { storedSession = nil }
}
