import Foundation
import XCTest
@testable import SportsHub

final class MatchLiveTimelineTests: XCTestCase {
    func testBatchInsertsCorrectsDeletesAndUpdatesTheScoreDeterministically() throws {
        let kickoff = Date(timeIntervalSince1970: 1_788_000_000)
        let originalGoal = event(
            id: "goal",
            revision: 2,
            minute: 37,
            kind: .goal,
            title: "Goal"
        )
        let yellowCard = event(
            id: "yellow",
            revision: 3,
            minute: 18,
            kind: .yellowCard,
            title: "Yellow card"
        )
        let snapshot = details(
            revision: 3,
            kickoff: kickoff,
            events: [yellowCard, originalGoal]
        )
        var timeline = try MatchLiveTimeline(snapshot: snapshot)

        let correctedGoal = event(
            id: "goal",
            revision: 4,
            minute: 36,
            addedTime: 1,
            kind: .goal,
            title: "Corrected goal"
        )
        let review = event(
            id: "review",
            revision: 5,
            minute: 36,
            addedTime: 2,
            kind: .varReview,
            title: "VAR review"
        )
        let updatedAt = kickoff.addingTimeInterval(60)
        let batch = FixtureEventBatch(
            fixture: fixture(
                revision: 6,
                kickoff: kickoff,
                minute: 64,
                homeScore: 2,
                awayScore: 0
            ),
            fixtureRevision: 6,
            mutations: [
                .upsert(correctedGoal),
                .upsert(review),
                .deleted(id: "yellow", revision: 6)
            ],
            updatedAt: updatedAt
        )

        let changes = try timeline.apply(batch)

        XCTAssertEqual(timeline.details.fixture.revision, 6)
        XCTAssertEqual(timeline.details.fixture.homeScore, 2)
        XCTAssertEqual(timeline.details.updatedAt, updatedAt)
        XCTAssertEqual(timeline.details.events.map(\.id), ["goal", "review"])
        XCTAssertEqual(timeline.details.events.first?.titleEnglish, "Corrected goal")
        XCTAssertEqual(
            changes,
            [
                .corrected(correctedGoal),
                .inserted(review),
                .deleted(id: "yellow")
            ]
        )
    }

    func testOlderAndRepeatedBatchesAreIgnoredWithoutResurrectingDeletedEvents() throws {
        let kickoff = Date(timeIntervalSince1970: 1_788_000_000)
        let goal = event(
            id: "goal",
            revision: 2,
            minute: 37,
            kind: .goal,
            title: "Goal"
        )
        var timeline = try MatchLiveTimeline(
            snapshot: details(revision: 2, kickoff: kickoff, events: [goal])
        )
        let deletion = FixtureEventBatch(
            fixture: fixture(revision: 3, kickoff: kickoff),
            fixtureRevision: 3,
            mutations: [.deleted(id: "goal", revision: 3)],
            updatedAt: kickoff.addingTimeInterval(30)
        )

        XCTAssertEqual(try timeline.apply(deletion), [.deleted(id: "goal")])
        XCTAssertTrue(timeline.details.events.isEmpty)
        XCTAssertEqual(try timeline.apply(deletion), [])

        let older = FixtureEventBatch(
            fixture: fixture(revision: 2, kickoff: kickoff),
            fixtureRevision: 2,
            mutations: [.upsert(goal)],
            updatedAt: kickoff
        )
        XCTAssertEqual(try timeline.apply(older), [])
        XCTAssertTrue(timeline.details.events.isEmpty)
        XCTAssertEqual(timeline.details.fixture.revision, 3)
    }

    func testSnapshotReplacementRejectsOlderDataAndAcceptsAnAuthoritativeEqualRevision() throws {
        let kickoff = Date(timeIntervalSince1970: 1_788_000_000)
        let goal = event(
            id: "goal",
            revision: 4,
            minute: 37,
            kind: .goal,
            title: "Goal"
        )
        var timeline = try MatchLiveTimeline(
            snapshot: details(revision: 5, kickoff: kickoff, events: [goal])
        )

        let older = details(revision: 4, kickoff: kickoff, events: [])
        XCTAssertFalse(try timeline.replace(with: older))
        XCTAssertEqual(timeline.details.events.map(\.id), ["goal"])

        let corrected = event(
            id: "goal",
            revision: 5,
            minute: 36,
            kind: .goal,
            title: "Snapshot correction"
        )
        let equalRevision = details(
            revision: 5,
            kickoff: kickoff,
            events: [corrected]
        )
        XCTAssertTrue(try timeline.replace(with: equalRevision))
        XCTAssertEqual(timeline.details.events.first?.titleEnglish, "Snapshot correction")
    }

    func testReducerRejectsCrossFixtureAndRevisionContractViolations() throws {
        let kickoff = Date(timeIntervalSince1970: 1_788_000_000)
        var timeline = try MatchLiveTimeline(
            snapshot: details(revision: 3, kickoff: kickoff, events: [])
        )
        let wrongFixture = Fixture(
            id: "another-fixture",
            competition: MockSportsData.competition,
            homeTeam: MockSportsData.teams[0],
            awayTeam: MockSportsData.teams[1],
            kickoff: kickoff,
            state: .live,
            minute: 62,
            homeScore: 1,
            awayScore: 0,
            venueArabic: "ملعب",
            venueEnglish: "Stadium",
            revision: 4
        )

        XCTAssertThrowsError(
            try timeline.apply(
                FixtureEventBatch(
                    fixture: wrongFixture,
                    fixtureRevision: 4,
                    mutations: [],
                    updatedAt: kickoff
                )
            )
        )

        XCTAssertThrowsError(
            try timeline.apply(
                FixtureEventBatch(
                    fixture: fixture(revision: 4, kickoff: kickoff),
                    fixtureRevision: 5,
                    mutations: [],
                    updatedAt: kickoff
                )
            )
        )

        let unrelatedTeamEvent = FixtureEvent(
            id: "foreign-team-goal",
            revision: 4,
            minute: 63,
            kind: .goal,
            titleArabic: "Goal",
            titleEnglish: "Goal",
            detailArabic: "Details",
            detailEnglish: "Details",
            teamID: "unrelated-team"
        )
        XCTAssertThrowsError(
            try timeline.apply(
                FixtureEventBatch(
                    fixture: fixture(revision: 4, kickoff: kickoff),
                    fixtureRevision: 4,
                    mutations: [.upsert(unrelatedTeamEvent)],
                    updatedAt: kickoff
                )
            )
        )
    }

    func testReducerRejectsResurrectionAfterATombstoneInTheSameBatch() throws {
        let kickoff = Date(timeIntervalSince1970: 1_788_000_000)
        let goal = event(
            id: "goal",
            revision: 2,
            minute: 37,
            kind: .goal,
            title: "Goal"
        )
        var timeline = try MatchLiveTimeline(
            snapshot: details(revision: 2, kickoff: kickoff, events: [goal])
        )
        let resurrectedGoal = event(
            id: "goal",
            revision: 4,
            minute: 37,
            kind: .goal,
            title: "Resurrected goal"
        )

        XCTAssertThrowsError(
            try timeline.apply(
                FixtureEventBatch(
                    fixture: fixture(revision: 4, kickoff: kickoff),
                    fixtureRevision: 4,
                    mutations: [
                        .deleted(id: "goal", revision: 3),
                        .upsert(resurrectedGoal)
                    ],
                    updatedAt: kickoff.addingTimeInterval(60)
                )
            )
        )
        XCTAssertEqual(timeline.details.fixture.revision, 2)
        XCTAssertEqual(timeline.details.events.map(\.id), ["goal"])
    }

    func testPollingPolicyStopsTerminalMatchesAndCapsRetryBackoff() {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        XCTAssertTrue(MatchLivePollingPolicy.allowsIncrementalUpdates(after: .demo))
        XCTAssertTrue(MatchLivePollingPolicy.allowsIncrementalUpdates(after: .offlineSnapshot))
        XCTAssertFalse(MatchLivePollingPolicy.allowsIncrementalUpdates(after: .demoFallback))
        XCTAssertEqual(
            MatchLivePollingPolicy.interval(
                for: fixture(revision: 1, kickoff: now, state: .live),
                now: now
            ),
            5
        )
        XCTAssertEqual(
            MatchLivePollingPolicy.interval(
                for: fixture(revision: 1, kickoff: now, state: .halfTime),
                now: now
            ),
            10
        )
        XCTAssertEqual(
            MatchLivePollingPolicy.interval(
                for: fixture(
                    revision: 1,
                    kickoff: now.addingTimeInterval(30 * 60),
                    state: .upcoming
                ),
                now: now
            ),
            15
        )
        XCTAssertEqual(
            MatchLivePollingPolicy.interval(
                for: fixture(
                    revision: 1,
                    kickoff: now.addingTimeInterval(2 * 60 * 60),
                    state: .upcoming
                ),
                now: now
            ),
            60
        )
        XCTAssertNil(
            MatchLivePollingPolicy.interval(
                for: fixture(revision: 1, kickoff: now, state: .finished),
                now: now
            )
        )
        XCTAssertEqual(MatchLivePollingPolicy.retryDelay(forAttempt: 1), 2)
        XCTAssertEqual(MatchLivePollingPolicy.retryDelay(forAttempt: 4), 20)
        XCTAssertEqual(MatchLivePollingPolicy.retryDelay(forAttempt: 99), 30)
    }

    func testStatusOnlyRequestsAttentionForActionableOrUnexpectedChanges() {
        XCTAssertFalse(MatchLiveUpdatePhase.connecting.requiresAttention)
        XCTAssertFalse(MatchLiveUpdatePhase.ended.requiresAttention)
        XCTAssertTrue(MatchLiveUpdatePhase.retrying(attempt: 1).requiresAttention)
        XCTAssertTrue(MatchLiveUpdatePhase.stopped.requiresAttention)
        XCTAssertTrue(MatchLiveUpdatePhase.unavailable.requiresAttention)
    }

    private func details(
        revision: Int,
        kickoff: Date,
        events: [FixtureEvent]
    ) -> MatchDetails {
        MatchDetails(
            fixture: fixture(revision: revision, kickoff: kickoff),
            events: events,
            homeLineup: TeamLineup(formation: nil, players: []),
            awayLineup: TeamLineup(formation: nil, players: []),
            statistics: [],
            sourceName: "Test source",
            updatedAt: kickoff
        )
    }

    private func fixture(
        revision: Int,
        kickoff: Date,
        state: FixtureState = .live,
        minute: Int? = 62,
        homeScore: Int? = 1,
        awayScore: Int? = 0
    ) -> Fixture {
        Fixture(
            id: "fixture-live-1",
            competition: MockSportsData.competition,
            homeTeam: MockSportsData.teams[0],
            awayTeam: MockSportsData.teams[1],
            kickoff: kickoff,
            state: state,
            minute: minute,
            homeScore: homeScore,
            awayScore: awayScore,
            venueArabic: "ملعب المدينة",
            venueEnglish: "City Arena",
            revision: revision
        )
    }

    private func event(
        id: String,
        revision: Int,
        minute: Int,
        addedTime: Int? = nil,
        kind: FixtureEventKind,
        title: String
    ) -> FixtureEvent {
        FixtureEvent(
            id: id,
            revision: revision,
            minute: minute,
            addedTime: addedTime,
            kind: kind,
            titleArabic: title,
            titleEnglish: title,
            detailArabic: "Details",
            detailEnglish: "Details"
        )
    }
}
