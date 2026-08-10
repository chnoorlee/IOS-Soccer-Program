import Foundation
import XCTest
@testable import SportsHub

final class TeamContextContractTests: XCTestCase {
    func testTeamDetailRejectsAConflictingSnapshotForTheRequestedTeam() {
        let canonicalTeam = team(id: "team-one", englishName: "Team One")
        let conflictingTeam = team(id: "team-one", englishName: "Spoofed Team")
        let competition = competitionDTO()
        let response = TeamDetailDataDTO(
            team: canonicalTeam,
            competitions: [competition],
            nextFixtures: [fixture(
                id: "next-1",
                competition: competition,
                homeTeam: conflictingTeam,
                awayTeam: team(id: "team-two", englishName: "Team Two"),
                kickoff: Date(timeIntervalSince1970: 200),
                state: .scheduled
            )],
            recentFixtures: []
        )

        XCTAssertThrowsError(try response.domain(expectedTeamID: "team-one")) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.nextFixtures.team")
            )
        }
    }

    func testTeamDetailRejectsAnUnorderedNextWindow() {
        let canonicalTeam = team(id: "team-one", englishName: "Team One")
        let awayTeam = team(id: "team-two", englishName: "Team Two")
        let competition = competitionDTO()
        let response = TeamDetailDataDTO(
            team: canonicalTeam,
            competitions: [competition],
            nextFixtures: [
                fixture(
                    id: "later",
                    competition: competition,
                    homeTeam: canonicalTeam,
                    awayTeam: awayTeam,
                    kickoff: Date(timeIntervalSince1970: 300),
                    state: .scheduled
                ),
                fixture(
                    id: "earlier",
                    competition: competition,
                    homeTeam: canonicalTeam,
                    awayTeam: awayTeam,
                    kickoff: Date(timeIntervalSince1970: 200),
                    state: .scheduled
                )
            ],
            recentFixtures: []
        )

        XCTAssertThrowsError(try response.domain(expectedTeamID: "team-one")) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.nextFixtures.order")
            )
        }
    }

    func testTeamContentRejectsMisorderedArticlesAndDuplicateVideos() {
        let newer = article(id: "newer", publishedAt: Date(timeIntervalSince1970: 300))
        let older = article(id: "older", publishedAt: Date(timeIntervalSince1970: 200))
        let video = videoDTO(id: "video-one")

        let misordered = TeamContentDataDTO(
            teamId: "team-one",
            articles: [older, newer],
            videos: []
        )
        XCTAssertThrowsError(try misordered.domain(expectedTeamID: "team-one")) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.articles.order")
            )
        }

        let duplicated = TeamContentDataDTO(
            teamId: "team-one",
            articles: [newer, older],
            videos: [video, video]
        )
        XCTAssertThrowsError(try duplicated.domain(expectedTeamID: "team-one")) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.videos.id")
            )
        }
    }

    func testTeamMatchSnapshotBatchPreservesRequestedOrderAndNullableSlots() throws {
        let first = team(id: "team-one", englishName: "Team One")
        let second = team(id: "team-two", englishName: "Team Two")
        let competition = competitionDTO()
        let response = TeamMatchSnapshotListResponseDTO(data: [
            TeamMatchSnapshotDTO(
                team: first,
                previousFixture: nil,
                nextFixture: fixture(
                    id: "next-one",
                    competition: competition,
                    homeTeam: first,
                    awayTeam: second,
                    kickoff: Date(timeIntervalSince1970: 300),
                    state: .scheduled
                )
            ),
            TeamMatchSnapshotDTO(
                team: second,
                previousFixture: fixture(
                    id: "previous-two",
                    competition: competition,
                    homeTeam: first,
                    awayTeam: second,
                    kickoff: Date(timeIntervalSince1970: 100),
                    state: .finished
                ),
                nextFixture: nil
            )
        ])

        let result = try response.domain(expectedTeamIDs: ["team-one", "team-two"])

        XCTAssertEqual(result.map(\.team.id), ["team-one", "team-two"])
        XCTAssertEqual(result[0].nextFixture?.id, "next-one")
        XCTAssertNil(result[0].previousFixture)
        XCTAssertEqual(result[1].previousFixture?.id, "previous-two")
        XCTAssertNil(result[1].nextFixture)
    }

    func testTeamMatchSnapshotBatchRejectsMissingOrReorderedRows() {
        let first = team(id: "team-one", englishName: "Team One")
        let second = team(id: "team-two", englishName: "Team Two")
        let missing = TeamMatchSnapshotListResponseDTO(data: [
            TeamMatchSnapshotDTO(team: first, previousFixture: nil, nextFixture: nil)
        ])
        XCTAssertThrowsError(
            try missing.domain(expectedTeamIDs: ["team-one", "team-two"])
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.count")
            )
        }

        let reordered = TeamMatchSnapshotListResponseDTO(data: [
            TeamMatchSnapshotDTO(team: second, previousFixture: nil, nextFixture: nil),
            TeamMatchSnapshotDTO(team: first, previousFixture: nil, nextFixture: nil)
        ])
        XCTAssertThrowsError(
            try reordered.domain(expectedTeamIDs: ["team-one", "team-two"])
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].team.id")
            )
        }
    }

    func testTeamMatchSnapshotRejectsWrongStateAndConflictingTeamSnapshot() {
        let canonical = team(id: "team-one", englishName: "Team One")
        let conflicting = team(id: "team-one", englishName: "Spoofed Team")
        let opponent = team(id: "team-two", englishName: "Team Two")
        let competition = competitionDTO()

        let wrongState = TeamMatchSnapshotDTO(
            team: canonical,
            previousFixture: fixture(
                id: "previous-one",
                competition: competition,
                homeTeam: canonical,
                awayTeam: opponent,
                kickoff: Date(timeIntervalSince1970: 100),
                state: .scheduled
            ),
            nextFixture: nil
        )
        XCTAssertThrowsError(
            try wrongState.domain(expectedTeamID: "team-one", field: "data[0]")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].previousFixture.state")
            )
        }

        let badSnapshot = TeamMatchSnapshotDTO(
            team: canonical,
            previousFixture: nil,
            nextFixture: fixture(
                id: "next-one",
                competition: competition,
                homeTeam: conflicting,
                awayTeam: opponent,
                kickoff: Date(timeIntervalSince1970: 300),
                state: .scheduled
            )
        )
        XCTAssertThrowsError(
            try badSnapshot.domain(expectedTeamID: "team-one", field: "data[0]")
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].nextFixture.team")
            )
        }
    }

    private func team(id: String, englishName: String) -> TeamDTO {
        TeamDTO(
            id: id,
            name: LocalizedTextDTO(ar: englishName, en: englishName),
            monogram: "TM",
            accentColorHex: "006C75"
        )
    }

    private func competitionDTO() -> CompetitionDTO {
        CompetitionDTO(
            id: "competition-one",
            name: LocalizedTextDTO(ar: "League", en: "League"),
            sport: .football,
            currentSeasonId: nil,
            seasons: nil
        )
    }

    private func fixture(
        id: String,
        competition: CompetitionDTO,
        homeTeam: TeamDTO,
        awayTeam: TeamDTO,
        kickoff: Date,
        state: FixtureStateDTO
    ) -> FixtureDTO {
        FixtureDTO(
            id: id,
            competition: competition,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            kickoffAt: kickoff,
            state: state,
            minute: nil,
            score: nil,
            venue: LocalizedTextDTO(ar: "Stadium", en: "Stadium"),
            revision: 0
        )
    }

    private func article(id: String, publishedAt: Date) -> ArticleDTO {
        ArticleDTO(
            id: id,
            title: LocalizedTextDTO(ar: "Title", en: "Title"),
            summary: LocalizedTextDTO(ar: "Summary", en: "Summary"),
            source: "Desk",
            publishedAt: publishedAt,
            category: .analysis,
            format: .story,
            correctionStatus: .original,
            engagement: nil,
            heroMedia: nil
        )
    }

    private func videoDTO(id: String) -> VideoDTO {
        VideoDTO(
            id: id,
            type: .highlight,
            title: LocalizedTextDTO(ar: "Video", en: "Video"),
            description: LocalizedTextDTO(ar: "Description", en: "Description"),
            durationSeconds: 60,
            isPlayable: false,
            availabilityReason: .entitlementRequired
        )
    }
}
