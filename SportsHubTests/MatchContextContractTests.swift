import Foundation
import XCTest
@testable import SportsHub

final class MatchContextContractTests: XCTestCase {
    private var fixture: Fixture {
        MockSportsData.fixtures(
            now: Date(timeIntervalSince1970: 1_775_000_000)
        ).first { $0.id == "fixture-live-1" }!
    }

    func testStandingsReturnExplicitSeasonAndAcceptOrderedCompleteTable() throws {
        let context = try decodeStandings(rows: [
            standingRow(rank: 1, team: homeTeamJSON, won: 7, drawn: 2, lost: 1),
            standingRow(rank: 2, team: awayTeamJSON, won: 6, drawn: 2, lost: 2)
        ])

        XCTAssertEqual(context.fixtureID, fixture.id)
        XCTAssertEqual(context.competition.id, fixture.competition.id)
        XCTAssertEqual(context.season.id, "season-confirmed-by-server")
        XCTAssertEqual(context.groups.first?.rows.map(\.rank), [1, 2])
        XCTAssertEqual(context.sourceName, "Licensed Context Partner")
    }

    func testEmptyStandingsAndHeadToHeadAreValidExplicitStates() throws {
        let standings = try decodeStandings(rows: [], includesGroup: false)
        let headToHead = try decodeHeadToHead(meetings: [], limit: 10)

        XCTAssertTrue(standings.groups.isEmpty)
        XCTAssertTrue(headToHead.meetings.isEmpty)
    }

    func testStandingsRejectCompetitionMismatch() throws {
        XCTAssertThrowsError(
            try decodeStandings(
                competitionID: "wrong-competition",
                rows: [
                    standingRow(rank: 1, team: homeTeamJSON),
                    standingRow(rank: 2, team: awayTeamJSON)
                ]
            )
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.competition.id")
            )
        }
    }

    func testStandingsRejectOutOfOrderDuplicateOrIncompleteRows() throws {
        let invalidTables: [[String]] = [
            [
                standingRow(rank: 2, team: homeTeamJSON),
                standingRow(rank: 1, team: awayTeamJSON)
            ],
            [
                standingRow(rank: 1, team: homeTeamJSON),
                standingRow(rank: 2, team: homeTeamJSON)
            ],
            [
                standingRow(rank: 1, team: homeTeamJSON, played: 10, won: 3, drawn: 3, lost: 3),
                standingRow(rank: 2, team: awayTeamJSON)
            ],
            [standingRow(rank: 1, team: homeTeamJSON)]
        ]

        for rows in invalidTables {
            XCTAssertThrowsError(try decodeStandings(rows: rows)) { error in
                guard let dataError = error as? SportsDataError,
                      case .contractViolation = dataError else {
                    return XCTFail("Expected a standings contract violation, received \(error)")
                }
            }
        }
    }

    func testHeadToHeadAllowsCrossCompetitionAndReversedHomeAway() throws {
        let recent = meetingJSON(
            id: "meeting-recent",
            competitionID: "cup",
            competitionEnglish: "Demo Cup",
            home: awayTeamJSON,
            away: homeTeamJSON,
            kickoff: "2026-03-01T18:00:00Z",
            state: "FINISHED"
        )
        let older = meetingJSON(
            id: "meeting-older",
            competitionID: fixture.competition.id,
            competitionEnglish: fixture.competition.nameEnglish,
            home: homeTeamJSON,
            away: awayTeamJSON,
            kickoff: "2025-11-01T18:00:00Z",
            state: "FINISHED"
        )

        let context = try decodeHeadToHead(meetings: [recent, older], limit: 10)

        XCTAssertEqual(context.meetings.map(\.id), ["meeting-recent", "meeting-older"])
        XCTAssertEqual(context.meetings.first?.competition.id, "cup")
        XCTAssertEqual(context.homeTeam.id, fixture.homeTeam.id)
        XCTAssertEqual(context.awayTeam.id, fixture.awayTeam.id)
    }

    func testHeadToHeadRejectsWrongTeamsCurrentFixtureUnfinishedDuplicatesAndOrdering() throws {
        let valid = meetingJSON(
            id: "meeting-valid",
            home: homeTeamJSON,
            away: awayTeamJSON,
            kickoff: "2026-03-01T18:00:00Z",
            state: "FINISHED"
        )
        let invalidMeetingSets: [[String]] = [
            [meetingJSON(
                id: "wrong-team",
                home: homeTeamJSON,
                away: thirdTeamJSON,
                kickoff: "2026-03-01T18:00:00Z",
                state: "FINISHED"
            )],
            [meetingJSON(
                id: "unfinished",
                home: homeTeamJSON,
                away: awayTeamJSON,
                kickoff: "2026-03-01T18:00:00Z",
                state: "LIVE"
            )],
            [meetingJSON(
                id: fixture.id,
                home: homeTeamJSON,
                away: awayTeamJSON,
                kickoff: "2026-03-01T18:00:00Z",
                state: "FINISHED"
            )],
            [valid, valid],
            [
                meetingJSON(
                    id: "older-first",
                    home: homeTeamJSON,
                    away: awayTeamJSON,
                    kickoff: "2025-11-01T18:00:00Z",
                    state: "FINISHED"
                ),
                valid
            ]
        ]

        for meetings in invalidMeetingSets {
            XCTAssertThrowsError(try decodeHeadToHead(meetings: meetings, limit: 10)) { error in
                guard let dataError = error as? SportsDataError,
                      case .contractViolation = dataError else {
                    return XCTFail("Expected an H2H contract violation, received \(error)")
                }
            }
        }
    }

    func testHeadToHeadRejectsInvalidLimitAndTooManyRows() throws {
        XCTAssertThrowsError(try decodeHeadToHead(meetings: [], limit: 0))
        XCTAssertThrowsError(try decodeHeadToHead(meetings: [], limit: 21))

        let meetings = (0..<3).map { index in
            meetingJSON(
                id: "meeting-\(index)",
                home: homeTeamJSON,
                away: awayTeamJSON,
                kickoff: "2026-01-0\(3 - index)T18:00:00Z",
                state: "FINISHED"
            )
        }
        XCTAssertThrowsError(try decodeHeadToHead(meetings: meetings, limit: 2))
    }

    private func decodeStandings(
        competitionID: String = MockSportsData.competition.id,
        rows: [String],
        includesGroup: Bool = true
    ) throws -> FixtureStandingsContext {
        let standingsJSON = includesGroup
            ? """
              [{
                "groupName": {"ar": "الترتيب", "en": "Overall"},
                "rows": [\(rows.joined(separator: ","))]
              }]
              """
            : "[]"
        let data = Data(
            """
            {
              "data": {
                "fixtureId": "fixture-live-1",
                "competition": \(competitionJSON(id: competitionID, english: "Demo Premier League")),
                "season": {
                  "id": "season-confirmed-by-server",
                  "name": {"ar": "موسم مؤكد", "en": "Confirmed season"},
                  "startDate": "2025-08-01",
                  "endDate": "2026-05-31",
                  "isCurrent": false
                },
                "standings": \(standingsJSON),
                "source": {"name": "Licensed Context Partner"},
                "updatedAt": "2026-03-02T10:00:00Z"
              }
            }
            """.utf8
        )
        let response = try APIJSON.makeDecoder().decode(
            FixtureStandingsResponseDTO.self,
            from: data
        )
        return try response.domain(expectedFixture: fixture)
    }

    private func decodeHeadToHead(
        meetings: [String],
        limit: Int
    ) throws -> FixtureHeadToHeadContext {
        let data = Data(
            """
            {
              "data": {
                "fixtureId": "fixture-live-1",
                "homeTeam": \(homeTeamJSON),
                "awayTeam": \(awayTeamJSON),
                "meetings": [\(meetings.joined(separator: ","))],
                "source": {"name": "Licensed Context Partner"},
                "updatedAt": "2026-03-02T10:00:00Z"
              }
            }
            """.utf8
        )
        let response = try APIJSON.makeDecoder().decode(
            FixtureHeadToHeadResponseDTO.self,
            from: data
        )
        return try response.domain(expectedFixture: fixture, limit: limit)
    }

    private func standingRow(
        rank: Int,
        team: String,
        played: Int = 10,
        won: Int = 5,
        drawn: Int = 3,
        lost: Int = 2
    ) -> String {
        """
        {
          "rank": \(rank),
          "team": \(team),
          "played": \(played),
          "won": \(won),
          "drawn": \(drawn),
          "lost": \(lost),
          "goalsFor": 20,
          "goalsAgainst": 10,
          "points": 18,
          "form": ["WIN", "DRAW"]
        }
        """
    }

    private func meetingJSON(
        id: String,
        competitionID: String = MockSportsData.competition.id,
        competitionEnglish: String = MockSportsData.competition.nameEnglish,
        home: String,
        away: String,
        kickoff: String,
        state: String
    ) -> String {
        """
        {
          "id": "\(id)",
          "competition": \(competitionJSON(id: competitionID, english: competitionEnglish)),
          "homeTeam": \(home),
          "awayTeam": \(away),
          "kickoffAt": "\(kickoff)",
          "state": "\(state)",
          "minute": 90,
          "score": {"home": 2, "away": 1},
          "venue": {"ar": "ملعب", "en": "Stadium"},
          "revision": 1
        }
        """
    }

    private func competitionJSON(id: String, english: String) -> String {
        """
        {
          "id": "\(id)",
          "name": {"ar": "مسابقة تجريبية", "en": "\(english)"},
          "sport": "FOOTBALL"
        }
        """
    }

    private var homeTeamJSON: String {
        """
        {
          "id": "riyadh-falcons",
          "name": {"ar": "صقور الرياض", "en": "Riyadh Falcons"},
          "monogram": "RF",
          "accentColorHex": "0AA9C0"
        }
        """
    }

    private var awayTeamJSON: String {
        """
        {
          "id": "jeddah-waves",
          "name": {"ar": "أمواج جدة", "en": "Jeddah Waves"},
          "monogram": "JW",
          "accentColorHex": "F2AB33"
        }
        """
    }

    private var thirdTeamJSON: String {
        """
        {
          "id": "third-team",
          "name": {"ar": "فريق ثالث", "en": "Third Team"},
          "monogram": "TT",
          "accentColorHex": "556677"
        }
        """
    }
}
