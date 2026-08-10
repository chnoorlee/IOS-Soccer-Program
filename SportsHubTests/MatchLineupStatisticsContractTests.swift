import Foundation
import XCTest
@testable import SportsHub

final class MatchLineupStatisticsContractTests: XCTestCase {
    func testCompleteFormationIsEligibleForSupplementalPitch() throws {
        let lineup = try teamLineup(
            formation: "4-3-3",
            players: completePlayers(formation: [4, 3, 3])
        )

        XCTAssertEqual(lineup.starters.count, 11)
        XCTAssertEqual(lineup.substitutes.count, 1)
        XCTAssertEqual(lineup.pitchLines?.map(\.count), [1, 4, 3, 3])
    }

    func testMockLineupsExerciseBothSupportedFormationDepths() {
        XCTAssertEqual(MockSportsData.homeLineup.pitchLines?.map(\.count), [1, 4, 3, 3])
        XCTAssertEqual(MockSportsData.awayLineup.pitchLines?.map(\.count), [1, 4, 2, 3, 1])
        XCTAssertFalse(MockSportsData.homeLineup.substitutes.isEmpty)
        XCTAssertFalse(MockSportsData.awayLineup.substitutes.isEmpty)
    }

    func testPartialAndEmptyLineupsAreAcceptedWithoutInventingPitchData() throws {
        let partial = try teamLineup(
            formation: "4-3-3",
            players: Array(completePlayers(formation: [4, 3, 3]).prefix(4))
        )
        let empty = try teamLineup(formation: nil, players: [])
        let formationMismatch = try teamLineup(
            formation: "4-4-2",
            players: completePlayers(formation: [4, 3, 3])
        )

        XCTAssertFalse(partial.hasCompleteStartingEleven)
        XCTAssertNil(partial.pitchLines)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertNil(empty.pitchLines)
        XCTAssertNil(formationMismatch.pitchLines)
    }

    func testMissingStarterFlagDefaultsToStarterForLegacyPayloads() throws {
        let data = Data(
            #"{"id":"player-1","number":1,"name":"Keeper","position":"GOALKEEPER"}"#.utf8
        )

        let player = try APIJSON.makeDecoder().decode(LineupPlayerDTO.self, from: data)

        XCTAssertTrue(try player.domain(field: "player").isStarter)
    }

    func testLineupsRejectDuplicateIdentityNumberSlotAndIllegalBenchSlot() throws {
        let base = completePlayers(formation: [4, 3, 3])
        let duplicateID = base + [player(id: base[0].id, number: 30, isStarter: false)]
        let duplicateNumber = base + [player(id: "bench-30", number: base[0].number, isStarter: false)]
        let duplicateSlot = replacing(
            base,
            at: 2,
            with: player(
                id: "starter-3",
                number: 3,
                position: .defender,
                line: 1,
                order: 0
            )
        )
        let benchOnPitch = base + [
            player(id: "bench-12", number: 12, isStarter: false, line: 4, order: 0)
        ]
        let invalidSlot = replacing(
            base,
            at: 2,
            with: player(
                id: "starter-3",
                number: 3,
                position: .defender,
                line: 5,
                order: 0
            )
        )
        let invalidNumber = replacing(
            base,
            at: 2,
            with: player(id: "starter-3", number: 0, position: .defender)
        )

        for players in [
            duplicateID,
            duplicateNumber,
            duplicateSlot,
            benchOnPitch,
            invalidSlot,
            invalidNumber
        ] {
            XCTAssertThrowsError(try teamLineup(formation: "4-3-3", players: players))
        }
    }

    func testLineupsRejectTooManyStartersAndInvalidFormation() throws {
        let twelveStarters = Array(completePlayers(formation: [4, 3, 3]).prefix(11)) + [
            player(id: "starter-12", number: 12, line: 4, order: 0)
        ]

        XCTAssertThrowsError(try teamLineup(formation: "4-3-3", players: twelveStarters))
        XCTAssertThrowsError(
            try teamLineup(
                formation: "4-4-3",
                players: completePlayers(formation: [4, 3, 3])
            )
        )
    }

    func testStatisticsAreValidatedAndCanonicalized() throws {
        let statistics = try validatedMatchStatistics(
            [
                statistic(id: "corners", type: .corners, home: 5, away: 3),
                statistic(id: "target", type: .shotsOnTarget, home: 4, away: 2),
                statistic(id: "shots", type: .shots, home: 9, away: 6),
                statistic(id: "provider-possession", type: .possession, home: 56, away: 44, unit: "%")
            ],
            field: "data.statistics"
        )

        XCTAssertEqual(
            statistics.map(\.titleKey),
            ["stat.possession", "stat.shots", "stat.shotsOnTarget", "stat.corners"]
        )
        XCTAssertTrue(try validatedMatchStatistics([], field: "data.statistics").isEmpty)
    }

    func testStatisticsRejectDuplicatesInvalidUnitsTotalsFractionsAndRelations() throws {
        let cases: [[MatchStatisticDTO]] = [
            [
                statistic(id: "one", type: .shots, home: 5, away: 4),
                statistic(id: "two", type: .shots, home: 6, away: 3)
            ],
            [
                statistic(id: "duplicate", type: .shots, home: 5, away: 4),
                statistic(id: "duplicate", type: .corners, home: 2, away: 1)
            ],
            [statistic(id: "possession", type: .possession, home: 60, away: 35, unit: "%")],
            [statistic(id: "possession", type: .possession, home: 55, away: 45)],
            [statistic(id: "shots", type: .shots, home: 4.5, away: 3)],
            [statistic(id: "shots", type: .shots, home: .infinity, away: 3)],
            [
                statistic(id: "shots", type: .shots, home: 4, away: 6),
                statistic(id: "target", type: .shotsOnTarget, home: 5, away: 2)
            ]
        ]

        for statistics in cases {
            XCTAssertThrowsError(
                try validatedMatchStatistics(statistics, field: "data.statistics")
            )
        }
    }

    private func teamLineup(
        formation: String?,
        players: [LineupPlayerDTO]
    ) throws -> TeamLineup {
        try validatedTeamLineup(
            players,
            formation: formation,
            field: "data.lineups.home"
        )
    }

    private func completePlayers(formation: [Int]) -> [LineupPlayerDTO] {
        var players = [
            player(
                id: "starter-1",
                number: 1,
                position: .goalkeeper,
                line: 0,
                order: 0
            )
        ]
        var number = 2
        for (lineOffset, count) in formation.enumerated() {
            for order in 0..<count {
                let position: PlayerPositionDTO = switch lineOffset {
                case 0: .defender
                case formation.count - 1: .forward
                default: .midfielder
                }
                players.append(
                    player(
                        id: "starter-\(number)",
                        number: number,
                        position: position,
                        line: lineOffset + 1,
                        order: order
                    )
                )
                number += 1
            }
        }
        players.append(player(id: "bench-12", number: 12, isStarter: false))
        return players
    }

    private func player(
        id: String,
        number: Int,
        position: PlayerPositionDTO = .unknown,
        isStarter: Bool = true,
        line: Int? = nil,
        order: Int? = nil
    ) -> LineupPlayerDTO {
        LineupPlayerDTO(
            id: id,
            number: number,
            name: "Player \(number)",
            position: position,
            isStarter: isStarter,
            formationPosition: line.flatMap { line in
                order.map { FormationPositionDTO(line: line, order: $0) }
            }
        )
    }

    private func replacing<T>(_ values: [T], at index: Int, with value: T) -> [T] {
        var values = values
        values[index] = value
        return values
    }

    private func statistic(
        id: String,
        type: MatchStatisticTypeDTO,
        home: Double,
        away: Double,
        unit: String = ""
    ) -> MatchStatisticDTO {
        MatchStatisticDTO(
            id: id,
            type: type,
            homeValue: home,
            awayValue: away,
            unit: unit
        )
    }
}
