import XCTest
@testable import SportsHub

final class FixtureFollowMatcherTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_785_931_200)

    func testTeamFollowMatchesEitherSideAndPreservesUnrelatedFixtures() {
        let fixtures = MockSportsData.fixtures(now: now)
        let matcher = FixtureFollowMatcher(
            follows: [follow(.team(MockSportsData.teams[0]))]
        )

        XCTAssertTrue(matcher.hasMatchableFollows)
        XCTAssertEqual(matcher.reason(for: fixtures[0]), .team)
        XCTAssertNil(matcher.reason(for: fixtures[1]))
        XCTAssertEqual(matcher.reason(for: fixtures[2]), .team)
        XCTAssertNil(matcher.reason(for: fixtures[3]))
    }

    func testCompetitionAndCombinedReasonsAreExact() {
        let fixtures = MockSportsData.fixtures(now: now)
        let matcher = FixtureFollowMatcher(
            follows: [
                follow(.team(MockSportsData.teams[0])),
                follow(.competition(MockSportsData.competition))
            ]
        )

        XCTAssertEqual(matcher.reason(for: fixtures[0]), .teamAndCompetition)
        XCTAssertEqual(matcher.reason(for: fixtures[1]), .competition)
        XCTAssertEqual(matcher.reason(for: fixtures[2]), .teamAndCompetition)
        XCTAssertNil(matcher.reason(for: fixtures[3]))
    }

    func testPlayerOnlyFollowIsNotMatchable() {
        let matcher = FixtureFollowMatcher(
            follows: [follow(.player(MockSportsData.players[2]))]
        )

        XCTAssertFalse(matcher.hasMatchableFollows)
        XCTAssertTrue(
            MockSportsData.fixtures(now: now).allSatisfy {
                matcher.reason(for: $0) == nil
            }
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
}
