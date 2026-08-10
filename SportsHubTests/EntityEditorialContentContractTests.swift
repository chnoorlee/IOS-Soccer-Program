import Foundation
import XCTest
@testable import SportsHub

final class EntityEditorialContentContractTests: XCTestCase {
    func testPlayerAndCompetitionContentMapExactScopeAndPreserveVideoOrder() throws {
        let newer = article(id: "article-newer", publishedAt: Date(timeIntervalSince1970: 300))
        let older = article(id: "article-older", publishedAt: Date(timeIntervalSince1970: 200))
        let secondVideo = video(id: "video-second")
        let firstVideo = video(id: "video-first")

        let player = try PlayerContentDataDTO(
            playerId: "player-one",
            articles: [newer, older],
            videos: [secondVideo, firstVideo]
        ).domain(expectedPlayerID: "player-one")
        let competition = try CompetitionContentDataDTO(
            competitionId: "competition-one",
            articles: [newer, older],
            videos: [secondVideo, firstVideo]
        ).domain(expectedCompetitionID: "competition-one")

        XCTAssertEqual(player.playerID, "player-one")
        XCTAssertEqual(competition.competitionID, "competition-one")
        XCTAssertEqual(player.articles.map(\.id), ["article-newer", "article-older"])
        XCTAssertEqual(competition.videos.map(\.id), ["video-second", "video-first"])
    }

    func testPlayerAndCompetitionContentRejectMismatchedScopeEchoes() {
        let player = PlayerContentDataDTO(
            playerId: "player-other",
            articles: [],
            videos: []
        )
        XCTAssertThrowsError(try player.domain(expectedPlayerID: "player-one")) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.playerId")
            )
        }

        let competition = CompetitionContentDataDTO(
            competitionId: "competition-other",
            articles: [],
            videos: []
        )
        XCTAssertThrowsError(
            try competition.domain(expectedCompetitionID: "competition-one")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.competitionId")
            )
        }
    }

    func testEntityContentRejectsOversizedDuplicateAndMisorderedWindows() {
        let oversized = PlayerContentDataDTO(
            playerId: "player-one",
            articles: (0...10).map {
                article(
                    id: "article-\($0)",
                    publishedAt: Date(timeIntervalSince1970: TimeInterval(100 - $0))
                )
            },
            videos: []
        )
        XCTAssertThrowsError(try oversized.domain(expectedPlayerID: "player-one")) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data"))
        }

        let oversizedVideos = CompetitionContentDataDTO(
            competitionId: "competition-one",
            articles: [],
            videos: (0...10).map { video(id: "video-\($0)") }
        )
        XCTAssertThrowsError(
            try oversizedVideos.domain(expectedCompetitionID: "competition-one")
        ) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data"))
        }

        let duplicateVideo = video(id: "video-one")
        let duplicated = CompetitionContentDataDTO(
            competitionId: "competition-one",
            articles: [],
            videos: [duplicateVideo, duplicateVideo]
        )
        XCTAssertThrowsError(
            try duplicated.domain(expectedCompetitionID: "competition-one")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.videos.id")
            )
        }

        let misordered = PlayerContentDataDTO(
            playerId: "player-one",
            articles: [
                article(id: "older", publishedAt: Date(timeIntervalSince1970: 100)),
                article(id: "newer", publishedAt: Date(timeIntervalSince1970: 200))
            ],
            videos: []
        )
        XCTAssertThrowsError(try misordered.domain(expectedPlayerID: "player-one")) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.articles.order")
            )
        }
    }

    func testEntityContentUsesArticleIDAsStableTimestampTieBreaker() throws {
        let timestamp = Date(timeIntervalSince1970: 300)
        let valid = CompetitionContentDataDTO(
            competitionId: "competition-one",
            articles: [
                article(id: "article-a", publishedAt: timestamp),
                article(id: "article-b", publishedAt: timestamp)
            ],
            videos: []
        )
        XCTAssertNoThrow(try valid.domain(expectedCompetitionID: "competition-one"))

        let invalid = PlayerContentDataDTO(
            playerId: "player-one",
            articles: [
                article(id: "article-b", publishedAt: timestamp),
                article(id: "article-a", publishedAt: timestamp)
            ],
            videos: []
        )
        XCTAssertThrowsError(try invalid.domain(expectedPlayerID: "player-one"))
    }

    private func article(id: String, publishedAt: Date) -> ArticleDTO {
        ArticleDTO(
            id: id,
            title: LocalizedTextDTO(ar: "عنوان", en: "Title"),
            summary: LocalizedTextDTO(ar: "ملخص", en: "Summary"),
            source: "Licensed Desk",
            publishedAt: publishedAt,
            category: .analysis,
            format: .story,
            correctionStatus: .original,
            engagement: nil,
            heroMedia: nil
        )
    }

    private func video(id: String) -> VideoDTO {
        VideoDTO(
            id: id,
            type: .highlight,
            title: LocalizedTextDTO(ar: "فيديو", en: "Video"),
            description: LocalizedTextDTO(ar: "وصف", en: "Description"),
            durationSeconds: 60,
            isPlayable: false,
            availabilityReason: .entitlementRequired
        )
    }
}
