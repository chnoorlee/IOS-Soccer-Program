import XCTest
@testable import SportsHub

final class TeamContextPresentationTests: XCTestCase {
    func testPresentationUsesValidatedProviderOrderAndKeepsRemainingWindows() throws {
        let fixtures = MockSportsData.fixtureCatalog()
        let previous = try XCTUnwrap(fixtures.first { $0.id == "fixture-finished-1" })
        let next = try XCTUnwrap(fixtures.first { $0.id == "fixture-team-next-1" })
        let additionalNext = try XCTUnwrap(
            fixtures.first { $0.id == "fixture-upcoming-1" }
        )
        let details = TeamDetails(
            team: MockSportsData.teams[0],
            competitions: MockSportsData.competitions,
            nextFixtures: [next, additionalNext],
            recentFixtures: [previous]
        )

        let presentation = TeamContextPresentation(details: details)

        XCTAssertEqual(presentation.previousFixture, previous)
        XCTAssertEqual(presentation.nextFixture, next)
        XCTAssertEqual(presentation.additionalRecentFixtures, [])
        XCTAssertEqual(presentation.additionalUpcomingFixtures, [additionalNext])
    }

    func testEmptyPreviousAndNextSlotsRemainIndependent() {
        let empty = TeamDetails(
            team: MockSportsData.teams[0],
            competitions: [],
            nextFixtures: [],
            recentFixtures: []
        )

        let presentation = TeamContextPresentation(details: empty)

        XCTAssertNil(presentation.previousFixture)
        XCTAssertNil(presentation.nextFixture)
        XCTAssertTrue(presentation.additionalRecentFixtures.isEmpty)
        XCTAssertTrue(presentation.additionalUpcomingFixtures.isEmpty)
    }
}
