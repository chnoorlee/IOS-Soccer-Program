import XCTest
@testable import SportsHub

final class FixtureContentContractTests: XCTestCase {
    func testValidFixtureContentPreservesProviderOrderAndPlaybackRights() throws {
        let response = FixtureContentDataDTO(
            fixtureId: "fixture-one",
            moments: [
                moment(id: "moment-two", videoID: "video-two", minute: 52),
                moment(id: "moment-one", videoID: "video-one", minute: 27)
            ],
            articles: [article(id: "article-two"), article(id: "article-one")]
        )

        let content = try response.domain(expectedFixtureID: "fixture-one")

        XCTAssertEqual(content.fixtureID, "fixture-one")
        XCTAssertEqual(content.moments.map(\.id), ["moment-two", "moment-one"])
        XCTAssertEqual(content.moments.map(\.minute), [52, 27])
        XCTAssertTrue(content.moments.allSatisfy {
            !$0.video.isPlayable && $0.video.availabilityReason == .entitlementRequired
        })
        XCTAssertEqual(content.articles.map(\.id), ["article-two", "article-one"])
    }

    func testFixtureContentResponseMustMatchRequestedPathIdentifier() {
        let response = FixtureContentDataDTO(
            fixtureId: "another-fixture",
            moments: [],
            articles: []
        )

        XCTAssertThrowsError(try response.domain(expectedFixtureID: "fixture-one")) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.fixtureId")
            )
        }
    }

    func testFixtureContentRejectsDuplicateMomentAndVideoIdentifiers() {
        let duplicateMoment = FixtureContentDataDTO(
            fixtureId: "fixture-one",
            moments: [
                moment(id: "same-moment", videoID: "video-one", minute: 10),
                moment(id: "same-moment", videoID: "video-two", minute: 20)
            ],
            articles: []
        )
        XCTAssertThrowsError(
            try duplicateMoment.domain(expectedFixtureID: "fixture-one")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.moments.id")
            )
        }

        let duplicateVideo = FixtureContentDataDTO(
            fixtureId: "fixture-one",
            moments: [
                moment(id: "moment-one", videoID: "same-video", minute: 10),
                moment(id: "moment-two", videoID: "same-video", minute: 20)
            ],
            articles: []
        )
        XCTAssertThrowsError(
            try duplicateVideo.domain(expectedFixtureID: "fixture-one")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.moments.video.id")
            )
        }
    }

    func testFixtureContentRejectsDuplicateArticleIdentifiers() {
        let response = FixtureContentDataDTO(
            fixtureId: "fixture-one",
            moments: [],
            articles: [article(id: "same-article"), article(id: "same-article")]
        )

        XCTAssertThrowsError(try response.domain(expectedFixtureID: "fixture-one")) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.articles.id")
            )
        }
    }

    func testFixtureContentRejectsOutOfRangeMinuteAndOversizedWindows() {
        let invalidMinute = FixtureContentDataDTO(
            fixtureId: "fixture-one",
            moments: [moment(id: "moment-one", videoID: "video-one", minute: 201)],
            articles: []
        )
        XCTAssertThrowsError(
            try invalidMinute.domain(expectedFixtureID: "fixture-one")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.moments[0].minute")
            )
        }

        let tooManyMoments = FixtureContentDataDTO(
            fixtureId: "fixture-one",
            moments: (0...10).map {
                moment(id: "moment-\($0)", videoID: "video-\($0)", minute: $0)
            },
            articles: []
        )
        XCTAssertThrowsError(
            try tooManyMoments.domain(expectedFixtureID: "fixture-one")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.moments")
            )
        }

        let tooManyArticles = FixtureContentDataDTO(
            fixtureId: "fixture-one",
            moments: [],
            articles: (0...10).map { article(id: "article-\($0)") }
        )
        XCTAssertThrowsError(
            try tooManyArticles.domain(expectedFixtureID: "fixture-one")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.articles")
            )
        }
    }

    private func moment(
        id: String,
        videoID: String,
        minute: Int?
    ) -> FixtureContentMomentDTO {
        FixtureContentMomentDTO(
            id: id,
            title: LocalizedTextDTO(ar: "لحظة تجريبية", en: "Demo moment"),
            minute: minute,
            video: VideoDTO(
                id: videoID,
                type: .highlight,
                title: LocalizedTextDTO(ar: "فيديو تجريبي", en: "Demo video"),
                description: nil,
                durationSeconds: 60,
                isPlayable: false,
                availabilityReason: .entitlementRequired
            )
        )
    }

    private func article(id: String) -> ArticleDTO {
        ArticleDTO(
            id: id,
            title: LocalizedTextDTO(ar: "تقرير تجريبي", en: "Demo report"),
            summary: LocalizedTextDTO(ar: "ملخص تجريبي", en: "Demo summary"),
            source: "Demo Desk",
            publishedAt: Date(timeIntervalSince1970: 1_788_000_000),
            category: .matchReport,
            format: .story,
            correctionStatus: .original,
            engagement: nil,
            heroMedia: nil
        )
    }
}
