import Foundation
import XCTest
@testable import SportsHub

@MainActor
final class MatchLiveActivityContractTests: XCTestCase {
    func testEligibilityUsesFourHourLeadWindowAndRejectsTerminalStates() {
        let now = Date()
        XCTAssertEqual(
            MatchLiveActivityPolicy.eligibility(
                for: fixture(state: .upcoming, kickoff: now.addingTimeInterval(4 * 60 * 60)),
                now: now
            ),
            .eligible
        )
        XCTAssertEqual(
            MatchLiveActivityPolicy.eligibility(
                for: fixture(
                    state: .upcoming,
                    kickoff: now.addingTimeInterval(4 * 60 * 60 + 1)
                ),
                now: now
            ),
            .kickoffTooDistant
        )
        XCTAssertEqual(
            MatchLiveActivityPolicy.eligibility(
                for: fixture(state: .finished, kickoff: now),
                now: now
            ),
            .terminal
        )
        XCTAssertEqual(
            MatchLiveActivityPolicy.eligibility(
                for: fixture(
                    state: .upcoming,
                    kickoff: now.addingTimeInterval(-15 * 60)
                ),
                now: now
            ),
            .eligible
        )
        XCTAssertEqual(
            MatchLiveActivityPolicy.eligibility(
                for: fixture(
                    state: .upcoming,
                    kickoff: now.addingTimeInterval(-15 * 60 - 1)
                ),
                now: now
            ),
            .terminal
        )
    }

    func testPayloadCarriesBoundedPublicStateAndDemoProvenance() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_788_000_000)
        let payload = try MatchLiveActivityPolicy.payload(
            for: fixture(state: .live, kickoff: updatedAt.addingTimeInterval(-300)),
            language: .arabic,
            isDemo: true,
            updatedAt: updatedAt
        )

        XCTAssertEqual(payload.attributes.fixtureID, "fixture")
        XCTAssertEqual(payload.state.preferredLanguageCode, "ar")
        XCTAssertEqual(payload.state.homeScore, 1)
        XCTAssertEqual(payload.state.awayScore, 0)
        XCTAssertEqual(payload.state.minute, 31)
        XCTAssertEqual(payload.state.fixtureState, FixtureState.live.rawValue)
        XCTAssertTrue(payload.state.isDemo)
        XCTAssertEqual(payload.staleDate, updatedAt.addingTimeInterval(30))
        XCTAssertEqual(payload.relevanceScore, 100)
    }

    func testPayloadRejectsScoreOnUpcomingFixture() {
        XCTAssertThrowsError(
            try MatchLiveActivityPolicy.payload(
                for: fixture(
                    state: .upcoming,
                    kickoff: Date().addingTimeInterval(3_600),
                    homeScore: 1,
                    awayScore: 0
                ),
                language: .english,
                isDemo: false,
                updatedAt: Date()
            )
        ) { error in
            XCTAssertEqual(error as? MatchLiveActivityOperationError, .invalidPayload)
        }
    }

    func testUpcomingPayloadBecomesStaleWithoutForegroundVerification() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_788_000_000)
        let payload = try MatchLiveActivityPolicy.payload(
            for: fixture(
                state: .upcoming,
                kickoff: updatedAt.addingTimeInterval(4 * 60 * 60)
            ),
            language: .english,
            isDemo: false,
            updatedAt: updatedAt
        )

        XCTAssertEqual(
            payload.staleDate,
            updatedAt.addingTimeInterval(
                MatchLiveActivityPolicy.maximumUpcomingFreshnessInterval
            )
        )
    }

    func testCoordinatorRequestsOnceThenSkipsUnchangedContent() async throws {
        let client = RecordingMatchActivityClient()
        let coordinator = MatchLiveActivityCoordinator(client: client)
        let updatedAt = Date()
        let liveFixture = fixture(state: .live, kickoff: updatedAt.addingTimeInterval(-300))

        let startResult = try await coordinator.start(
            fixture: liveFixture,
            language: .english,
            isDemo: false,
            updatedAt: updatedAt
        )
        XCTAssertEqual(startResult, .started)
        XCTAssertEqual(client.requestedPayloads.count, 1)
        XCTAssertTrue(coordinator.isActive(fixtureID: liveFixture.id))

        let unchangedResult = try await coordinator.start(
            fixture: liveFixture,
            language: .english,
            isDemo: false,
            updatedAt: updatedAt
        )
        XCTAssertEqual(unchangedResult, .unchanged)
        XCTAssertEqual(client.requestedPayloads.count, 1)
        XCTAssertTrue(client.updatedPayloads.isEmpty)
    }

    func testCoordinatorUpdatesThenEndsWithFinalFinishedContent() async throws {
        let client = RecordingMatchActivityClient()
        let coordinator = MatchLiveActivityCoordinator(client: client)
        let updatedAt = Date()
        _ = try await coordinator.start(
            fixture: fixture(state: .live, kickoff: updatedAt.addingTimeInterval(-300)),
            language: .english,
            isDemo: false,
            updatedAt: updatedAt
        )

        let changed = fixture(
            state: .live,
            kickoff: updatedAt.addingTimeInterval(-300),
            homeScore: 2,
            awayScore: 0,
            revision: 4
        )
        let updateResult = await coordinator.synchronize(
            fixture: changed,
            language: .english,
            isDemo: false,
            updatedAt: updatedAt.addingTimeInterval(10),
            now: updatedAt.addingTimeInterval(10)
        )
        XCTAssertEqual(updateResult, .updated)
        XCTAssertEqual(client.updatedPayloads.last?.state.homeScore, 2)

        let finished = fixture(
            state: .finished,
            kickoff: updatedAt.addingTimeInterval(-7_200),
            homeScore: 2,
            awayScore: 1,
            revision: 5
        )
        let finishResult = await coordinator.synchronize(
            fixture: finished,
            language: .english,
            isDemo: false,
            updatedAt: updatedAt.addingTimeInterval(20),
            now: updatedAt.addingTimeInterval(20)
        )
        XCTAssertEqual(finishResult, .ended)
        XCTAssertEqual(client.endedPayloads.last?.payload?.state.homeScore, 2)
        guard let dismissal = client.endedPayloads.last?.dismissal,
              case .after = dismissal else {
            return XCTFail("Finished matches should remain briefly with final content")
        }
        XCTAssertFalse(coordinator.isActive(fixtureID: finished.id))
    }

    func testDisabledClientRejectsStartWithoutRequest() async {
        let client = RecordingMatchActivityClient()
        client.enabled = false
        let coordinator = MatchLiveActivityCoordinator(client: client)

        do {
            _ = try await coordinator.start(
                fixture: fixture(state: .live, kickoff: Date()),
                language: .english,
                isDemo: false,
                updatedAt: Date()
            )
            XCTFail("Expected disabled authorization to reject the request")
        } catch {
            XCTAssertEqual(error as? MatchLiveActivityOperationError, .disabled)
        }
        XCTAssertTrue(client.requestedPayloads.isEmpty)
    }

    func testExplicitStopFallsBackToLastValidContent() async throws {
        let client = RecordingMatchActivityClient()
        let coordinator = MatchLiveActivityCoordinator(client: client)
        let updatedAt = Date()
        let validFixture = fixture(
            state: .live,
            kickoff: updatedAt.addingTimeInterval(-300)
        )
        _ = try await coordinator.start(
            fixture: validFixture,
            language: .english,
            isDemo: false,
            updatedAt: updatedAt
        )

        let invalidFixture = fixture(
            state: .live,
            kickoff: updatedAt.addingTimeInterval(-300),
            homeScore: 120,
            awayScore: 0,
            revision: 4
        )
        await coordinator.stop(
            fixture: invalidFixture,
            language: .english,
            isDemo: false,
            updatedAt: updatedAt.addingTimeInterval(10)
        )

        XCTAssertEqual(client.endedPayloads.last?.payload?.state.homeScore, 1)
        XCTAssertEqual(client.endedPayloads.last?.dismissal, .immediate)
        XCTAssertFalse(coordinator.isActive(fixtureID: validFixture.id))
    }

    func testCoordinatorEndsWhenUpcomingFixtureMovesOutsideWindow() async throws {
        let client = RecordingMatchActivityClient()
        let coordinator = MatchLiveActivityCoordinator(client: client)
        let now = Date()
        _ = try await coordinator.start(
            fixture: fixture(
                state: .upcoming,
                kickoff: now.addingTimeInterval(60 * 60)
            ),
            language: .english,
            isDemo: false,
            updatedAt: now
        )

        let rescheduled = fixture(
            state: .upcoming,
            kickoff: now.addingTimeInterval(5 * 60 * 60),
            revision: 1
        )
        let rescheduledResult = await coordinator.synchronize(
            fixture: rescheduled,
            language: .english,
            isDemo: false,
            updatedAt: now.addingTimeInterval(30),
            now: now.addingTimeInterval(30)
        )
        XCTAssertEqual(rescheduledResult, .ended)
        XCTAssertEqual(client.endedPayloads.last?.dismissal, .immediate)
        XCTAssertFalse(coordinator.isActive(fixtureID: rescheduled.id))
    }

    func testMalformedTerminalPayloadEndsImmediatelyWithoutFinalContent() async throws {
        let client = RecordingMatchActivityClient()
        let coordinator = MatchLiveActivityCoordinator(client: client)
        let now = Date()
        _ = try await coordinator.start(
            fixture: fixture(state: .live, kickoff: now.addingTimeInterval(-300)),
            language: .english,
            isDemo: false,
            updatedAt: now
        )

        let malformedFinished = fixture(
            state: .finished,
            kickoff: now.addingTimeInterval(-7_200),
            homeScore: 120,
            awayScore: 0,
            revision: 5
        )
        let malformedResult = await coordinator.synchronize(
            fixture: malformedFinished,
            language: .english,
            isDemo: false,
            updatedAt: now.addingTimeInterval(30),
            now: now.addingTimeInterval(30)
        )
        XCTAssertEqual(malformedResult, .ended)
        XCTAssertNil(client.endedPayloads.last?.payload)
        XCTAssertEqual(client.endedPayloads.last?.dismissal, .immediate)
        XCTAssertFalse(coordinator.isActive(fixtureID: malformedFinished.id))
    }

    private func fixture(
        state: FixtureState,
        kickoff: Date,
        homeScore: Int? = nil,
        awayScore: Int? = nil,
        revision: Int? = nil
    ) -> Fixture {
        let hasLiveScore = state == .live || state == .halfTime || state == .finished
        return Fixture(
            id: "fixture",
            competition: MockSportsData.competition,
            homeTeam: MockSportsData.teams[0],
            awayTeam: MockSportsData.teams[1],
            kickoff: kickoff,
            state: state,
            minute: state == .live ? 31 : nil,
            homeScore: homeScore ?? (hasLiveScore ? 1 : nil),
            awayScore: awayScore ?? (hasLiveScore ? 0 : nil),
            venueArabic: "الملعب",
            venueEnglish: "Stadium",
            revision: revision ?? (hasLiveScore ? 3 : 0)
        )
    }
}

@MainActor
private final class RecordingMatchActivityClient: MatchActivityClient {
    struct EndedPayload {
        let payload: MatchLiveActivityPayload?
        let fixtureID: String
        let dismissal: MatchLiveActivityDismissal
    }

    var enabled = true
    private var activeIDs: Set<String> = []
    private(set) var requestedPayloads: [MatchLiveActivityPayload] = []
    private(set) var updatedPayloads: [MatchLiveActivityPayload] = []
    private(set) var endedPayloads: [EndedPayload] = []

    var areActivitiesEnabled: Bool { enabled }

    func activeFixtureIDs() -> Set<String> { activeIDs }

    func request(_ payload: MatchLiveActivityPayload) throws {
        requestedPayloads.append(payload)
        activeIDs.insert(payload.attributes.fixtureID)
    }

    func update(_ payload: MatchLiveActivityPayload) async {
        updatedPayloads.append(payload)
    }

    func end(
        _ payload: MatchLiveActivityPayload?,
        fixtureID: String,
        dismissal: MatchLiveActivityDismissal
    ) async {
        endedPayloads.append(EndedPayload(
            payload: payload,
            fixtureID: fixtureID,
            dismissal: dismissal
        ))
        activeIDs.remove(fixtureID)
    }
}
