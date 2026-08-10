import Foundation
import XCTest
@testable import SportsHub

@MainActor
final class PublicContentFreshnessTests: XCTestCase {
    func testStoreRejectsAnOlderOutOfOrderUpdate() async {
        let store = PublicContentFreshnessStore()
        let older = Date(timeIntervalSince1970: 1_788_000_000)
        let newer = older.addingTimeInterval(60)

        await store.record(.network(at: newer), for: .home)
        await store.record(.refreshFailed(at: older), for: .home)

        let status = await store.status(for: .home)
        XCTAssertEqual(status, .network(at: newer))
    }

    func testFixtureResourceNormalizesToLocalCalendarDayAndZone() throws {
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-05T23:30:00Z")
        )
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Riyadh"))

        let resource = PublicContentResource.fixtures(on: date, timeZone: timeZone)

        XCTAssertEqual(
            resource,
            .fixtures(day: "2026-08-06", timeZone: "Asia/Riyadh")
        )
    }

    func testCompetitionFixtureFreshnessIsIsolatedByCompetitionAndSeason() async {
        let store = PublicContentFreshnessStore()
        let first = PublicContentResource.competitionFixtures(
            id: "competition-1",
            seasonID: "season-2025"
        )
        let second = PublicContentResource.competitionFixtures(
            id: "competition-1",
            seasonID: "season-2026"
        )

        await store.record(.network(at: Date(timeIntervalSince1970: 1)), for: first)
        let firstStatus = await store.status(for: first)
        let secondStatus = await store.status(for: second)

        XCTAssertEqual(firstStatus?.source, .network)
        XCTAssertNil(secondStatus)
    }

    func testTeamContentFreshnessIsIsolatedByTeam() async {
        let store = PublicContentFreshnessStore()

        await store.record(
            .network(at: Date(timeIntervalSince1970: 1)),
            for: .teamContent(id: "team-one")
        )

        let first = await store.status(for: .teamContent(id: "team-one"))
        let second = await store.status(for: .teamContent(id: "team-two"))
        XCTAssertEqual(first?.source, .network)
        XCTAssertNil(second)
    }

    func testPlayerAndCompetitionContentFreshnessUseIndependentEntityKeys() async {
        let store = PublicContentFreshnessStore()
        let timestamp = Date(timeIntervalSince1970: 1)

        await store.record(.network(at: timestamp), for: .playerContent(id: "entity-one"))
        await store.record(
            .revalidated(storedAt: timestamp, checkedAt: timestamp),
            for: .competitionContent(id: "entity-one")
        )

        let player = await store.status(for: .playerContent(id: "entity-one"))
        let competition = await store.status(for: .competitionContent(id: "entity-one"))
        let otherPlayer = await store.status(for: .playerContent(id: "entity-two"))
        XCTAssertEqual(player?.source, .network)
        XCTAssertEqual(competition?.source, .revalidated)
        XCTAssertNil(otherPlayer)
    }

    func testFixtureContentFreshnessIsIsolatedByFixture() async {
        let store = PublicContentFreshnessStore()

        await store.record(
            .network(at: Date(timeIntervalSince1970: 1)),
            for: .fixtureContent(id: "fixture-one")
        )

        let first = await store.status(for: .fixtureContent(id: "fixture-one"))
        let second = await store.status(for: .fixtureContent(id: "fixture-two"))
        XCTAssertEqual(first?.source, .network)
        XCTAssertNil(second)
    }

    func testRecoverableTeamDetailFallbackIsMarkedForExactTeam() async throws {
        let store = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider(),
            freshnessReporter: store
        )
        let teamID = MockSportsData.teams[0].id

        let details = try await provider.teamDetails(id: teamID)
        let status = await store.status(for: .team(id: teamID))
        let otherStatus = await store.status(
            for: .team(id: MockSportsData.teams[1].id)
        )

        XCTAssertEqual(details.team.id, teamID)
        XCTAssertEqual(status?.source, .demoFallback)
        XCTAssertNil(otherStatus)
    }

    func testAppModelReportsDemoOnlyForTheMockPresentationBoundary() async {
        let store = PublicContentFreshnessStore(initialStatuses: [
            .home: .offlineSnapshot(
                storedAt: Date(timeIntervalSince1970: 1_788_000_000),
                checkedAt: Date(timeIntervalSince1970: 1_788_000_120)
            )
        ])
        let demoModel = AppModel(dataProvider: MockSportsDataProvider())
        let remotePresentationModel = AppModel(
            services: AppServices(
                dataProvider: MockSportsDataProvider(),
                authentication: AppEnvironment.makeUnavailableAuthenticationManager(),
                notificationPermissions: UnavailableNotificationPermissionCoordinator(),
                publicContentFreshness: store,
                usesDemoPublicData: false
            )
        )

        let demo = await demoModel.publicContentFreshness(for: .home)
        let offline = await remotePresentationModel.publicContentFreshness(for: .home)

        XCTAssertEqual(demo?.source, .demo)
        XCTAssertEqual(offline?.source, .offlineSnapshot)
    }

    func testRecoverableFixtureContextFallbackIsMarkedAsFictionalPerResource() async throws {
        let fixture = try await MockSportsDataProvider()
            .fixtureDetails(id: "fixture-live-1")
            .fixture
        let store = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider(),
            freshnessReporter: store
        )

        _ = try await provider.fixtureStandings(for: fixture)
        _ = try await provider.fixtureHeadToHead(for: fixture, limit: 10)
        let standings = await store.status(for: .fixtureStandings(id: fixture.id))
        let headToHead = await store.status(for: .fixtureHeadToHead(id: fixture.id))

        XCTAssertEqual(standings?.source, .demoFallback)
        XCTAssertEqual(headToHead?.source, .demoFallback)
    }

    func testRecoverableFixtureContentFallbackIsMarkedForExactFixture() async throws {
        let store = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider(),
            freshnessReporter: store
        )

        let content = try await provider.fixtureContent(id: "fixture-live-1")
        let status = await store.status(for: .fixtureContent(id: "fixture-live-1"))
        let other = await store.status(for: .fixtureContent(id: "fixture-upcoming-1"))

        XCTAssertEqual(content.fixtureID, "fixture-live-1")
        XCTAssertFalse(content.moments.isEmpty)
        XCTAssertEqual(status?.source, .demoFallback)
        XCTAssertNil(other)
    }

    func testRecoverableCompetitionFixtureFallbackIsMarkedForExactSeason() async throws {
        let store = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider(),
            freshnessReporter: store
        )
        let resource = PublicContentResource.competitionFixtures(
            id: MockSportsData.competition.id,
            seasonID: MockSportsData.season.id
        )

        let fixtures = try await provider.competitionFixtures(
            id: MockSportsData.competition.id,
            seasonID: MockSportsData.season.id
        )
        let status = await store.status(for: resource)

        XCTAssertFalse(fixtures.isEmpty)
        XCTAssertEqual(status?.source, .demoFallback)
    }

    func testRecoverableTeamContentFallbackIsMarkedForExactTeam() async throws {
        let store = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider(),
            freshnessReporter: store
        )
        let teamID = MockSportsData.teams[0].id

        let content = try await provider.teamContent(id: teamID)
        let status = await store.status(for: .teamContent(id: teamID))

        XCTAssertEqual(content.teamID, teamID)
        XCTAssertFalse(content.articles.isEmpty)
        XCTAssertEqual(status?.source, .demoFallback)
    }

    func testRecoverablePlayerAndCompetitionContentFallbacksAreMarkedExactly() async throws {
        let store = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider(),
            freshnessReporter: store
        )
        let playerID = MockSportsData.players[0].id
        let competitionID = MockSportsData.competitions[0].id

        let player = try await provider.playerContent(id: playerID)
        let competition = try await provider.competitionContent(id: competitionID)
        let playerStatus = await store.status(for: .playerContent(id: playerID))
        let competitionStatus = await store.status(
            for: .competitionContent(id: competitionID)
        )

        XCTAssertEqual(player.playerID, playerID)
        XCTAssertEqual(competition.competitionID, competitionID)
        XCTAssertEqual(playerStatus?.source, .demoFallback)
        XCTAssertEqual(competitionStatus?.source, .demoFallback)
    }

    func testRecoverablePredictionGameFallbackIsMarkedAsDemo() async throws {
        let store = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider(),
            freshnessReporter: store
        )

        let games = try await provider.predictionGames()
        let status = await store.status(for: .predictionGames)

        XCTAssertFalse(games.isEmpty)
        XCTAssertEqual(status?.source, .demoFallback)
    }
}
