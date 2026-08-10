import XCTest
@testable import SportsHub

final class HomeMatchPresentationTests: XCTestCase {
    func testAllFilterPreservesPartitionsOrderAndReasons() {
        let fixtures = MockSportsData.fixtures(now: fixedDate)
        let personalization = HomePersonalization(
            fixtures: fixtures,
            follows: [followedTeam]
        )

        let result = HomeMatchPresentation(
            personalization: personalization,
            selectedFilter: .all
        )

        XCTAssertEqual(result.relatedFixtures.map(\.fixture.id), [
            "fixture-live-1",
            "fixture-finished-1"
        ])
        XCTAssertEqual(result.relatedFixtures.map(\.reason), [.team, .team])
        XCTAssertEqual(result.generalFixtures.map(\.id), [
            "fixture-upcoming-1",
            "fixture-cup-upcoming-1"
        ])
    }

    func testLiveFilterIncludesLiveAndHalfTimeAcrossBothPartitions() {
        let fixtures = [
            fixture("live-related", state: .live, homeTeam: MockSportsData.teams[0]),
            fixture("half-general", state: .halfTime, homeTeam: MockSportsData.teams[2]),
            fixture("upcoming", state: .upcoming, homeTeam: MockSportsData.teams[2])
        ]
        let personalization = HomePersonalization(
            fixtures: fixtures,
            follows: [followedTeam]
        )

        let result = HomeMatchPresentation(
            personalization: personalization,
            selectedFilter: .live
        )

        XCTAssertEqual(result.relatedFixtures.map(\.fixture.id), ["live-related"])
        XCTAssertEqual(result.relatedFixtures.map(\.reason), [.team])
        XCTAssertEqual(result.generalFixtures.map(\.id), ["half-general"])
    }

    func testAvailableFiltersUseCanonicalOrderAndCoverExceptionalStates() {
        let fixtures = [
            fixture("cancelled", state: .cancelled),
            fixture("half-time", state: .halfTime),
            fixture("postponed", state: .postponed),
            fixture("finished", state: .finished),
            fixture("upcoming", state: .upcoming)
        ]

        XCTAssertEqual(
            HomeMatchFilter.availableFilters(in: fixtures),
            [.all, .live, .upcoming, .finished, .postponed, .cancelled]
        )
    }

    func testEveryNonLiveFilterMatchesOnlyItsExactState() {
        let states: [FixtureState] = [
            .upcoming, .finished, .postponed, .cancelled, .live, .halfTime
        ]
        let fixtures = states.enumerated().map {
            fixture("fixture-\($0.offset)", state: $0.element)
        }
        let personalization = HomePersonalization(fixtures: fixtures, follows: [])

        for filter in [
            HomeMatchFilter.upcoming,
            .finished,
            .postponed,
            .cancelled
        ] {
            let result = HomeMatchPresentation(
                personalization: personalization,
                selectedFilter: filter
            )
            XCTAssertEqual(result.generalFixtures.map(\.state), [
                expectedState(for: filter)
            ])
        }
    }

    func testUnavailableSelectionNormalizesToAllWithoutDroppingFixtures() {
        let fixtures = [fixture("upcoming", state: .upcoming)]
        let personalization = HomePersonalization(fixtures: fixtures, follows: [])

        let result = HomeMatchPresentation(
            personalization: personalization,
            selectedFilter: .live
        )

        XCTAssertEqual(result.selectedFilter, .all)
        XCTAssertEqual(result.generalFixtures.map(\.id), ["upcoming"])
    }

    func testFilteredPartitionsRemainCompleteAndDisjoint() {
        let fixtures = MockSportsData.fixtures(now: fixedDate)
        let personalization = HomePersonalization(
            fixtures: fixtures,
            follows: [followedTeam]
        )
        let result = HomeMatchPresentation(
            personalization: personalization,
            selectedFilter: .finished
        )
        let relatedIDs = result.relatedFixtures.map(\.fixture.id)
        let generalIDs = result.generalFixtures.map(\.id)
        let selectedSourceIDs = fixtures
            .filter { HomeMatchFilter.finished.includes($0.state) }
            .map(\.id)

        XCTAssertTrue(Set(relatedIDs).isDisjoint(with: Set(generalIDs)))
        XCTAssertEqual(Set(relatedIDs + generalIDs), Set(selectedSourceIDs))
        XCTAssertEqual(result.relatedFixtures.map(\.reason), [.team])
    }

    func testFilteringPreservesCombinedFollowReason() {
        let fixtures = [
            fixture("combined-live", state: .live, homeTeam: MockSportsData.teams[0])
        ]
        let competition = MockSportsData.competition
        let competitionFollow = SportsFollow(
            id: "follow:COMPETITION:\(competition.id)",
            type: .competition,
            entityID: competition.id,
            createdAt: fixedDate,
            entity: .competition(competition)
        )
        let personalization = HomePersonalization(
            fixtures: fixtures,
            follows: [followedTeam, competitionFollow]
        )

        let result = HomeMatchPresentation(
            personalization: personalization,
            selectedFilter: .live
        )

        XCTAssertEqual(result.relatedFixtures.map(\.fixture.id), ["combined-live"])
        XCTAssertEqual(result.relatedFixtures.map(\.reason), [.teamAndCompetition])
        XCTAssertTrue(result.generalFixtures.isEmpty)
    }

    func testFilterCanEmptyRelatedPartitionWithoutHidingGeneralResult() {
        let personalization = HomePersonalization(
            fixtures: MockSportsData.fixtures(now: fixedDate),
            follows: [followedTeam]
        )

        let result = HomeMatchPresentation(
            personalization: personalization,
            selectedFilter: .upcoming
        )

        XCTAssertTrue(result.relatedFixtures.isEmpty)
        XCTAssertEqual(result.generalFixtures.map(\.id), [
            "fixture-upcoming-1",
            "fixture-cup-upcoming-1"
        ])
    }

    func testEmptyInputOffersOnlyAllAndNoFixtures() {
        let personalization = HomePersonalization(fixtures: [], follows: [])

        let result = HomeMatchPresentation(
            personalization: personalization,
            selectedFilter: .cancelled
        )

        XCTAssertEqual(result.availableFilters, [.all])
        XCTAssertEqual(result.selectedFilter, .all)
        XCTAssertTrue(result.relatedFixtures.isEmpty)
        XCTAssertTrue(result.generalFixtures.isEmpty)
    }

    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_785_931_200)
    }

    private var followedTeam: SportsFollow {
        let team = MockSportsData.teams[0]
        return SportsFollow(
            id: "follow:TEAM:\(team.id)",
            type: .team,
            entityID: team.id,
            createdAt: fixedDate,
            entity: .team(team)
        )
    }

    private func fixture(
        _ id: String,
        state: FixtureState,
        homeTeam: Team = MockSportsData.teams[2]
    ) -> Fixture {
        let hasScore = state == .live || state == .halfTime || state == .finished

        Fixture(
            id: id,
            competition: MockSportsData.competition,
            homeTeam: homeTeam,
            awayTeam: MockSportsData.teams[3],
            kickoff: fixedDate,
            state: state,
            minute: state == .live || state == .halfTime ? 45 : nil,
            homeScore: hasScore ? 1 : nil,
            awayScore: hasScore ? 0 : nil,
            venueArabic: "ملعب اختباري",
            venueEnglish: "Test Stadium",
            revision: 1
        )
    }

    private func expectedState(for filter: HomeMatchFilter) -> FixtureState {
        switch filter {
        case .upcoming: .upcoming
        case .finished: .finished
        case .postponed: .postponed
        case .cancelled: .cancelled
        case .all, .live:
            XCTFail("This helper only accepts exact-state filters.")
            return .upcoming
        }
    }
}
