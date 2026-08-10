import XCTest
@testable import SportsHub

final class ContextualAlertPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_785_931_200)

    func testEntityEligibilityRequiresExactCompoundIdentity() {
        let follows = [follow(type: .player, entityID: "shared-id")]

        XCTAssertEqual(
            presentation(.team, "shared-id", follows).eligibility,
            .ineligible
        )
        XCTAssertEqual(
            presentation(.player, "shared-id", follows).eligibility,
            .followedEntity
        )
    }

    func testEveryFollowEntityTypeCanBecomeEligible() {
        let follows = [
            follow(.team(MockSportsData.teams[0])),
            follow(.player(MockSportsData.players[2])),
            follow(.competition(MockSportsData.competition))
        ]

        XCTAssertTrue(
            presentation(.team, MockSportsData.teams[0].id, follows)
                .eligibility.isEligible
        )
        XCTAssertTrue(
            presentation(.player, MockSportsData.players[2].id, follows)
                .eligibility.isEligible
        )
        XCTAssertTrue(
            presentation(.competition, MockSportsData.competition.id, follows)
                .eligibility.isEligible
        )
    }

    func testFixtureEligibilityExplainsTeamCompetitionAndCombinedReasons() {
        let fixture = MockSportsData.fixtures(now: now)[0]

        XCTAssertEqual(
            ContextualAlertPresentation(
                fixture: fixture,
                follows: [follow(.team(MockSportsData.teams[0]))]
            ).eligibility,
            .fixture(.team)
        )
        XCTAssertEqual(
            ContextualAlertPresentation(
                fixture: fixture,
                follows: [follow(.competition(MockSportsData.competition))]
            ).eligibility,
            .fixture(.competition)
        )
        XCTAssertEqual(
            ContextualAlertPresentation(
                fixture: fixture,
                follows: [
                    follow(.team(MockSportsData.teams[0])),
                    follow(.competition(MockSportsData.competition))
                ]
            ).eligibility,
            .fixture(.teamAndCompetition)
        )
    }

    func testPlayerOnlyFollowNeverMakesFixtureEligible() {
        let result = ContextualAlertPresentation(
            fixture: MockSportsData.fixtures(now: now)[0],
            follows: [follow(.player(MockSportsData.players[2]))]
        )

        XCTAssertEqual(result.eligibility, .ineligible)
        XCTAssertFalse(result.eligibility.isEligible)
        XCTAssertNil(result.eligibility.localizationKey)
    }

    func testNoFollowsLeavesEntityAndFixtureIneligible() {
        let fixture = MockSportsData.fixtures(now: now)[0]

        XCTAssertEqual(
            presentation(.team, fixture.homeTeam.id, []).eligibility,
            .ineligible
        )
        XCTAssertEqual(
            ContextualAlertPresentation(fixture: fixture, follows: []).eligibility,
            .ineligible
        )
    }

    private func presentation(
        _ type: FollowEntityType,
        _ entityID: String,
        _ follows: [SportsFollow]
    ) -> ContextualAlertPresentation {
        ContextualAlertPresentation(
            entityType: type,
            entityID: entityID,
            follows: follows
        )
    }

    private func follow(_ entity: FollowEntitySnapshot) -> SportsFollow {
        SportsFollow(
            id: "follow:\(entity.type.rawValue):\(entity.entityID)",
            type: entity.type,
            entityID: entity.entityID,
            createdAt: now,
            entity: entity
        )
    }

    private func follow(
        type: FollowEntityType,
        entityID: String
    ) -> SportsFollow {
        SportsFollow(
            id: "follow:\(type.rawValue):\(entityID)",
            type: type,
            entityID: entityID,
            createdAt: now,
            entity: nil
        )
    }
}
