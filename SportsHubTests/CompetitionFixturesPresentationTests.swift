import Foundation
import XCTest
@testable import SportsHub

final class CompetitionFixturesPresentationTests: XCTestCase {
    func testEveryFixtureAppearsExactlyOnceInItsSemanticSection() {
        let fixtures = [
            makeFixture(id: "live", offset: 0, state: .live),
            makeFixture(id: "half", offset: 1, state: .halfTime),
            makeFixture(id: "upcoming", offset: 2, state: .upcoming),
            makeFixture(id: "finished", offset: -1, state: .finished),
            makeFixture(id: "postponed", offset: 3, state: .postponed),
            makeFixture(id: "cancelled", offset: 4, state: .cancelled)
        ]

        let presentation = CompetitionFixturesPresentation(fixtures: fixtures)
        let allPresented = presentation.sections.flatMap(\.fixtures)

        XCTAssertEqual(Set(allPresented.map(\.id)), Set(fixtures.map(\.id)))
        XCTAssertEqual(allPresented.count, fixtures.count)
        XCTAssertEqual(
            presentation.sections.map(\.kind),
            [.live, .upcoming, .results, .other]
        )
        XCTAssertEqual(
            presentation.sections.first(where: { $0.kind == .live })?.fixtures.map(\.id),
            ["live", "half"]
        )
        XCTAssertEqual(
            presentation.sections.first(where: { $0.kind == .other })?.fixtures.map(\.id),
            ["cancelled", "postponed"]
        )
    }

    func testUpcomingAscendsAndResultsDescendWithStableIDTieBreaks() {
        let fixtures = [
            makeFixture(id: "up-b", offset: 2, state: .upcoming),
            makeFixture(id: "up-a", offset: 2, state: .upcoming),
            makeFixture(id: "up-early", offset: 1, state: .upcoming),
            makeFixture(id: "result-old", offset: -2, state: .finished),
            makeFixture(id: "result-b", offset: -1, state: .finished),
            makeFixture(id: "result-a", offset: -1, state: .finished)
        ]

        let presentation = CompetitionFixturesPresentation(fixtures: fixtures)

        XCTAssertEqual(
            presentation.sections.first(where: { $0.kind == .upcoming })?.fixtures.map(\.id),
            ["up-early", "up-a", "up-b"]
        )
        XCTAssertEqual(
            presentation.sections.first(where: { $0.kind == .results })?.fixtures.map(\.id),
            ["result-a", "result-b", "result-old"]
        )
    }

    func testEmptyInputHasNoSyntheticSections() {
        XCTAssertTrue(CompetitionFixturesPresentation(fixtures: []).sections.isEmpty)
    }

    private func makeFixture(id: String, offset: TimeInterval, state: FixtureState) -> Fixture {
        Fixture(
            id: id,
            competition: MockSportsData.competition,
            homeTeam: MockSportsData.teams[0],
            awayTeam: MockSportsData.teams[1],
            kickoff: Date(timeIntervalSince1970: 1_788_000_000 + offset),
            state: state,
            minute: nil,
            homeScore: state == .finished ? 1 : nil,
            awayScore: state == .finished ? 0 : nil,
            venueArabic: "ملعب",
            venueEnglish: "Stadium"
        )
    }
}
