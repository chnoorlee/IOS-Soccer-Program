import XCTest
@testable import SportsHub

final class MatchesPresentationTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_754_524_800)

    func testAvailableCompetitionsAndGroupsFollowFirstPayloadAppearance() {
        let cup = competition("cup", english: "Cup")
        let league = competition("league", english: "League")
        let fixtures = [
            fixture("cup-1", competition: cup, state: .upcoming),
            fixture("league-1", competition: league, state: .live),
            fixture("cup-2", competition: cup, state: .finished)
        ]

        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .all,
            selectedCompetitionID: nil
        )

        XCTAssertEqual(result.availableCompetitions.map(\.id), ["cup", "league"])
        XCTAssertEqual(result.groups.map(\.id), ["cup", "league"])
        XCTAssertEqual(result.groups[0].fixtures.map(\.id), ["cup-1", "cup-2"])
        XCTAssertEqual(result.groups[1].fixtures.map(\.id), ["league-1"])
    }

    func testLiveFilterIncludesLiveAndHalfTimeAndKeepsCompetitionRailStable() {
        let cup = competition("cup", english: "Cup")
        let league = competition("league", english: "League")
        let friendly = competition("friendly", english: "Friendly")
        let fixtures = [
            fixture("cup-upcoming", competition: cup, state: .upcoming),
            fixture("league-live", competition: league, state: .live),
            fixture("cup-half", competition: cup, state: .halfTime),
            fixture("league-finished", competition: league, state: .finished),
            fixture("friendly-finished", competition: friendly, state: .finished)
        ]

        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .live,
            selectedCompetitionID: nil
        )

        XCTAssertEqual(
            result.availableCompetitions.map(\.id),
            ["cup", "league", "friendly"]
        )
        XCTAssertEqual(result.groups.map(\.id), ["cup", "league"])
        XCTAssertEqual(result.groups.flatMap(\.fixtures).map(\.id), ["cup-half", "league-live"])
        XCTAssertTrue(result.groups.flatMap(\.fixtures).allSatisfy {
            $0.state == .live || $0.state == .halfTime
        })
    }

    func testCompetitionSelectionIsComposedWithStatusFilter() {
        let cup = competition("cup", english: "Cup")
        let league = competition("league", english: "League")
        let fixtures = [
            fixture("cup-live", competition: cup, state: .live),
            fixture("league-live", competition: league, state: .halfTime),
            fixture("cup-finished", competition: cup, state: .finished)
        ]

        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .live,
            selectedCompetitionID: "cup"
        )

        XCTAssertEqual(result.selectedCompetitionID, "cup")
        XCTAssertEqual(result.groups.map(\.id), ["cup"])
        XCTAssertEqual(result.groups.flatMap(\.fixtures).map(\.id), ["cup-live"])
    }

    func testUnavailableCompetitionSelectionNormalizesToAllCompetitions() {
        let cup = competition("cup", english: "Cup")
        let fixtures = [fixture("cup-1", competition: cup, state: .upcoming)]

        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .all,
            selectedCompetitionID: "missing"
        )

        XCTAssertNil(result.selectedCompetitionID)
        XCTAssertEqual(result.groups.flatMap(\.fixtures).map(\.id), ["cup-1"])
    }

    func testFirstCompetitionSnapshotLabelsGroupWithoutChangingFixtureIdentity() {
        let first = competition("cup", english: "First name")
        let changed = competition("cup", english: "Changed name")
        let fixtures = [
            fixture("first", competition: first, state: .upcoming),
            fixture("second", competition: changed, state: .finished)
        ]

        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .all,
            selectedCompetitionID: nil
        )

        XCTAssertEqual(result.availableCompetitions.first?.nameEnglish, "First name")
        XCTAssertEqual(result.groups.first?.competition.nameEnglish, "First name")
        XCTAssertEqual(result.groups.first?.fixtures.map(\.id), ["first", "second"])
    }

    func testGroupsAreCompleteAndDisjoint() {
        let cup = competition("cup", english: "Cup")
        let league = competition("league", english: "League")
        let fixtures = [
            fixture("a", competition: cup, state: .upcoming),
            fixture("b", competition: league, state: .finished),
            fixture("c", competition: cup, state: .cancelled)
        ]

        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .all,
            selectedCompetitionID: nil
        )
        let outputIDs = result.groups.flatMap(\.fixtures).map(\.id)

        XCTAssertEqual(Set(outputIDs), Set(fixtures.map(\.id)))
        XCTAssertEqual(outputIDs.count, Set(outputIDs).count)
    }

    func testEmptyReasonsCoverDateStatusAndCompetitionContexts() {
        let cup = competition("cup", english: "Cup")
        let upcoming = [fixture("cup-upcoming", competition: cup, state: .upcoming)]

        XCTAssertEqual(presentation([], .all, nil).emptyReason, .date)
        XCTAssertEqual(presentation(upcoming, .live, nil).emptyReason, .live)
        XCTAssertEqual(
            presentation(upcoming, .live, cup.id).emptyReason,
            .liveInCompetition
        )
    }

    func testExistingCompetitionWithNoMatchingStatusRemainsSelected() {
        let cup = competition("cup", english: "Cup")
        let fixtures = [fixture("cup-upcoming", competition: cup, state: .upcoming)]

        let result = presentation(fixtures, .live, cup.id)

        XCTAssertEqual(result.selectedCompetitionID, cup.id)
        XCTAssertTrue(result.groups.isEmpty)
        XCTAssertEqual(result.emptyReason, .liveInCompetition)
    }

    func testFollowingScopeExplainsTeamCompetitionAndBothReasons() {
        let fixtures = MockSportsData.fixtures(now: fixedDate)
        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .all,
            selectedCompetitionID: nil,
            scope: .following,
            follows: [
                follow(.team(MockSportsData.teams[0])),
                follow(.competition(MockSportsData.competition))
            ]
        )

        XCTAssertEqual(
            result.groups.flatMap(\.fixtures).map(\.id),
            ["fixture-live-1", "fixture-upcoming-1", "fixture-finished-1"]
        )
        XCTAssertEqual(
            result.followReasonsByFixtureID,
            [
                "fixture-live-1": .teamAndCompetition,
                "fixture-upcoming-1": .competition,
                "fixture-finished-1": .teamAndCompetition
            ]
        )
    }

    func testFollowingScopeComposesWithLiveAndCompetitionWithoutChangingRail() {
        let fixtures = MockSportsData.fixtures(now: fixedDate)
        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .live,
            selectedCompetitionID: MockSportsData.competition.id,
            scope: .following,
            follows: [follow(.team(MockSportsData.teams[0]))]
        )

        XCTAssertEqual(
            result.availableCompetitions.map(\.id),
            [MockSportsData.competition.id, MockSportsData.cup.id]
        )
        XCTAssertEqual(result.selectedCompetitionID, MockSportsData.competition.id)
        XCTAssertEqual(result.groups.flatMap(\.fixtures).map(\.id), ["fixture-live-1"])
        XCTAssertEqual(result.followReasonsByFixtureID, ["fixture-live-1": .team])
    }

    func testPlayerOnlyFollowProducesNoMatchableFollowsEmptyState() {
        let result = MatchesPresentation(
            fixtures: MockSportsData.fixtures(now: fixedDate),
            statusFilter: .all,
            selectedCompetitionID: nil,
            scope: .following,
            follows: [follow(.player(MockSportsData.players[2]))]
        )

        XCTAssertTrue(result.groups.isEmpty)
        XCTAssertTrue(result.followReasonsByFixtureID.isEmpty)
        XCTAssertEqual(result.emptyReason, .noMatchableFollows)
    }

    func testFollowedInterestWithoutVisibleFixtureUsesContextualEmptyReasons() {
        let fixtures = MockSportsData.fixtures(now: fixedDate)
        let follows = [follow(.team(MockSportsData.teams[0]))]
        let dateResult = MatchesPresentation(
            fixtures: [fixtures[1]],
            statusFilter: .all,
            selectedCompetitionID: nil,
            scope: .following,
            follows: follows
        )
        let competitionResult = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .live,
            selectedCompetitionID: MockSportsData.cup.id,
            scope: .following,
            follows: follows
        )

        XCTAssertEqual(dateResult.emptyReason, .following)
        XCTAssertEqual(competitionResult.emptyReason, .followingInCompetition)
        XCTAssertEqual(competitionResult.selectedCompetitionID, MockSportsData.cup.id)
    }

    func testAllScopeIsBackwardCompatibleAndDoesNotClaimReasons() {
        let fixtures = MockSportsData.fixtures(now: fixedDate)
        let result = MatchesPresentation(
            fixtures: fixtures,
            statusFilter: .all,
            selectedCompetitionID: nil,
            scope: .all,
            follows: [follow(.team(MockSportsData.teams[0]))]
        )

        XCTAssertEqual(result.groups.flatMap(\.fixtures).map(\.id), fixtures.map(\.id))
        XCTAssertTrue(result.followReasonsByFixtureID.isEmpty)
        XCTAssertNil(result.emptyReason)
    }

    private func presentation(
        _ fixtures: [Fixture],
        _ status: MatchesStatusFilter,
        _ competitionID: String?
    ) -> MatchesPresentation {
        MatchesPresentation(
            fixtures: fixtures,
            statusFilter: status,
            selectedCompetitionID: competitionID
        )
    }

    private func competition(_ id: String, english: String) -> Competition {
        Competition(
            id: id,
            nameArabic: "بطولة \(id)",
            nameEnglish: english,
            currentSeasonID: nil,
            seasons: []
        )
    }

    private func fixture(
        _ id: String,
        competition: Competition,
        state: FixtureState
    ) -> Fixture {
        let hasScore = state == .live || state == .halfTime || state == .finished
        return Fixture(
            id: id,
            competition: competition,
            homeTeam: MockSportsData.teams[0],
            awayTeam: MockSportsData.teams[1],
            kickoff: fixedDate,
            state: state,
            minute: state == .live ? 35 : nil,
            homeScore: hasScore ? 1 : nil,
            awayScore: hasScore ? 0 : nil,
            venueArabic: "ملعب اختباري",
            venueEnglish: "Test Stadium"
        )
    }

    private func follow(_ entity: FollowEntitySnapshot) -> SportsFollow {
        SportsFollow(
            id: "follow:\(entity.type.rawValue):\(entity.entityID)",
            type: entity.type,
            entityID: entity.entityID,
            createdAt: fixedDate,
            entity: entity
        )
    }
}
