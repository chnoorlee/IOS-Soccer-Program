import XCTest
@testable import SportsHub

final class MatchesSearchPresentationTests: XCTestCase {
    func testEmptyAndSingleCharacterQueriesDoNotSearch() {
        let fixtures = [fixture("one")]

        let prompt = MatchesSearchPresentation(fixtures: fixtures, query: "   ")
        let short = MatchesSearchPresentation(fixtures: fixtures, query: "r")

        XCTAssertEqual(prompt.state, .prompt)
        XCTAssertTrue(prompt.fixtures.isEmpty)
        XCTAssertEqual(short.state, .tooShort)
        XCTAssertTrue(short.fixtures.isEmpty)
    }

    func testEnglishTeamSearchIsCaseInsensitiveAndKeepsOriginalID() {
        let result = MatchesSearchPresentation(
            fixtures: [fixture("fixture-original")],
            query: "FALCONS"
        )

        XCTAssertEqual(result.state, .results)
        XCTAssertEqual(result.fixtures.map(\.id), ["fixture-original"])
    }

    func testArabicSearchIgnoresDiacriticsAndCommonAlefVariants() {
        let fixtures = [fixture("arabic")]
        let venue = MatchesSearchPresentation(
            fixtures: fixtures,
            query: "استاد الامير"
        )
        let team = MatchesSearchPresentation(fixtures: fixtures, query: "الهلال")
        let competition = MatchesSearchPresentation(
            fixtures: fixtures,
            query: "كاس التجربة"
        )

        XCTAssertEqual(venue.fixtures.map(\.id), ["arabic"])
        XCTAssertEqual(team.fixtures.map(\.id), ["arabic"])
        XCTAssertEqual(competition.fixtures.map(\.id), ["arabic"])
    }

    func testCompetitionAndMonogramFieldsAreSearchable() {
        let fixtures = [fixture("one")]

        XCTAssertEqual(
            MatchesSearchPresentation(fixtures: fixtures, query: "demo cup")
                .fixtures.map(\.id),
            ["one"]
        )
        XCTAssertEqual(
            MatchesSearchPresentation(fixtures: fixtures, query: "rfc")
                .fixtures.map(\.id),
            ["one"]
        )
        XCTAssertEqual(
            MatchesSearchPresentation(fixtures: fixtures, query: "jw")
                .fixtures.map(\.id),
            ["one"]
        )
    }

    func testVenueAndAwayTeamFieldsAreSearchable() {
        let fixtures = [fixture("one")]

        XCTAssertEqual(
            MatchesSearchPresentation(fixtures: fixtures, query: "National Stadium")
                .fixtures.map(\.id),
            ["one"]
        )
        XCTAssertEqual(
            MatchesSearchPresentation(fixtures: fixtures, query: "Jeddah Waves")
                .fixtures.map(\.id),
            ["one"]
        )
    }

    func testResultsPreserveCandidateOrderAndNeverDuplicateAFixture() {
        let fixtures = [fixture("second"), fixture("first")]
        let result = MatchesSearchPresentation(fixtures: fixtures, query: "demo")

        XCTAssertEqual(result.fixtures.map(\.id), ["second", "first"])
        XCTAssertEqual(Set(result.fixtures.map(\.id)).count, 2)
    }

    func testStatusAndCompetitionFiltersAreAppliedBeforeTextSearch() {
        let dateFixtures = MockSportsData.fixtures()
        let filtered = MatchesPresentation(
            fixtures: dateFixtures,
            statusFilter: .live,
            selectedCompetitionID: MockSportsData.competition.id
        ).groups.flatMap(\.fixtures)

        let result = MatchesSearchPresentation(fixtures: filtered, query: "Falcons")

        XCTAssertEqual(result.fixtures.map(\.id), ["fixture-live-1"])
        XCTAssertFalse(result.fixtures.contains { $0.state == .finished })
        XCTAssertTrue(result.fixtures.allSatisfy {
            $0.competition.id == MockSportsData.competition.id
        })
    }

    func testUnmatchedQueryProducesExplicitEmptyState() {
        let result = MatchesSearchPresentation(
            fixtures: [fixture("one")],
            query: "unrelated"
        )

        XCTAssertEqual(result.state, .empty)
        XCTAssertTrue(result.fixtures.isEmpty)
    }

    private func fixture(_ id: String) -> Fixture {
        let home = Team(
            id: "home",
            nameArabic: "الهِلَال",
            nameEnglish: "Riyadh Falcons",
            monogram: "RFC",
            colorHex: "112233"
        )
        let away = Team(
            id: "away",
            nameArabic: "النصر",
            nameEnglish: "Jeddah Waves",
            monogram: "JW",
            colorHex: "445566"
        )
        let competition = Competition(
            id: "cup",
            nameArabic: "كأس التجربة",
            nameEnglish: "Demo Cup",
            currentSeasonID: nil,
            seasons: []
        )
        return Fixture(
            id: id,
            competition: competition,
            homeTeam: home,
            awayTeam: away,
            kickoff: Date(timeIntervalSince1970: 1_754_524_800),
            state: .upcoming,
            minute: nil,
            homeScore: nil,
            awayScore: nil,
            venueArabic: "إستاد الأمير الوطني",
            venueEnglish: "Demo Cup National Stadium"
        )
    }
}
