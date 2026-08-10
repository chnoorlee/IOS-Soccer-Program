import XCTest
@testable import SportsHub

final class HomePersonalizationTests: XCTestCase {
    func testTeamAndCompetitionRelationshipsAreExplainableAndStable() {
        let fixtures = MockSportsData.fixtures(now: Date(timeIntervalSince1970: 1_785_931_200))
        let follows = [
            follow(.team(MockSportsData.teams[0]), createdAt: 2),
            follow(.competition(MockSportsData.competition), createdAt: 1)
        ]

        let result = HomePersonalization(fixtures: fixtures, follows: follows)

        XCTAssertEqual(
            result.relatedFixtures.map(\.fixture.id),
            ["fixture-live-1", "fixture-upcoming-1", "fixture-finished-1"]
        )
        XCTAssertEqual(
            result.relatedFixtures.map(\.reason),
            [.teamAndCompetition, .competition, .teamAndCompetition]
        )
        XCTAssertEqual(result.generalFixtures.map(\.id), ["fixture-cup-upcoming-1"])
    }

    func testPlayerFollowNeverInfersFixtureRelationship() {
        let fixtures = MockSportsData.fixtures(now: Date(timeIntervalSince1970: 1_785_931_200))
        let follows = [follow(.player(MockSportsData.players[2]))]

        let result = HomePersonalization(fixtures: fixtures, follows: follows)

        XCTAssertTrue(result.relatedFixtures.isEmpty)
        XCTAssertEqual(result.generalFixtures.map(\.id), fixtures.map(\.id))
    }

    func testNoFollowsKeepsEveryFixtureInThePublicSection() {
        let fixtures = MockSportsData.fixtures(now: Date(timeIntervalSince1970: 1_785_931_200))

        let result = HomePersonalization(fixtures: fixtures, follows: [])

        XCTAssertTrue(result.relatedFixtures.isEmpty)
        XCTAssertEqual(result.generalFixtures.map(\.id), fixtures.map(\.id))
    }

    func testRelatedAndPublicFixturesAreACompleteDisjointPartition() {
        let fixtures = MockSportsData.fixtures(now: Date(timeIntervalSince1970: 1_785_931_200))
        let follows = [follow(.team(MockSportsData.teams[0]))]

        let result = HomePersonalization(fixtures: fixtures, follows: follows)
        let relatedIDs = result.relatedFixtures.map(\.fixture.id)
        let publicIDs = result.generalFixtures.map(\.id)

        XCTAssertEqual(relatedIDs, ["fixture-live-1", "fixture-finished-1"])
        XCTAssertEqual(
            result.relatedFixtures.map(\.reason),
            [.team, .team]
        )
        XCTAssertEqual(
            publicIDs,
            ["fixture-upcoming-1", "fixture-cup-upcoming-1"]
        )
        XCTAssertTrue(Set(relatedIDs).isDisjoint(with: Set(publicIDs)))
        XCTAssertEqual(Set(relatedIDs + publicIDs), Set(fixtures.map(\.id)))
    }

    private func follow(
        _ entity: FollowEntitySnapshot,
        createdAt: TimeInterval = 0
    ) -> SportsFollow {
        SportsFollow(
            id: "follow:\(entity.type.rawValue):\(entity.entityID)",
            type: entity.type,
            entityID: entity.entityID,
            createdAt: Date(timeIntervalSince1970: createdAt),
            entity: entity
        )
    }
}
