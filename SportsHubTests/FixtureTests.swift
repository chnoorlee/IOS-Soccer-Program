import XCTest
@testable import SportsHub

final class FixtureTests: XCTestCase {
    func testLiveFixtureFormatsScore() {
        let fixture = MockSportsData.fixtures().first { $0.id == "fixture-live-1" }

        XCTAssertEqual(fixture?.scoreText, "1 – 0")
        XCTAssertEqual(fixture?.state, .live)
        XCTAssertEqual(fixture?.minute, 62)
    }

    func testUpcomingFixtureHasNoScore() {
        let fixture = MockSportsData.fixtures().first { $0.id == "fixture-upcoming-1" }

        XCTAssertNil(fixture?.scoreText)
        XCTAssertEqual(fixture?.state, .upcoming)
    }
}

