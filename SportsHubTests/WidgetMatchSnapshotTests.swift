import Foundation
import XCTest
@testable import SportsHub

@MainActor
final class WidgetMatchSnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    func testSelectorUsesOnlyFollowsAndRanksLiveBeforeUpcoming() throws {
        let unrelatedLive = fixture(
            id: "unrelated-live",
            state: .live,
            kickoff: now.addingTimeInterval(-600),
            home: team(id: "other-home"),
            away: team(id: "other-away"),
            score: (2, 1)
        )
        let followedUpcoming = fixture(
            id: "followed-upcoming",
            state: .upcoming,
            kickoff: now.addingTimeInterval(3_600)
        )
        let followedLive = fixture(
            id: "followed-live",
            state: .live,
            kickoff: now.addingTimeInterval(-300),
            score: (1, 0)
        )

        let snapshot = try XCTUnwrap(WidgetMatchSnapshotSelector.select(
            from: [unrelatedLive, followedUpcoming, followedLive],
            follows: [followedTeam()],
            language: .arabic,
            isDemo: true,
            savedAt: now
        ))

        XCTAssertEqual(snapshot.fixtureID, "followed-live")
        XCTAssertEqual(snapshot.state, .live)
        XCTAssertEqual(snapshot.preferredLanguage, .arabic)
        XCTAssertTrue(snapshot.isDemo)
        XCTAssertEqual(snapshot.deepLinkURL?.absoluteString, "sportshub://fixtures/followed-live")
    }

    func testSelectorDoesNotSubstituteWhenThereIsNoMatchableFollow() throws {
        let snapshot = try WidgetMatchSnapshotSelector.select(
            from: [fixture(id: "upcoming", state: .upcoming, kickoff: now)],
            follows: [],
            language: .english,
            isDemo: false,
            savedAt: now
        )

        XCTAssertNil(snapshot)
    }

    func testSelectorExcludesTerminalFixtures() throws {
        let snapshot = try WidgetMatchSnapshotSelector.select(
            from: [
                fixture(
                    id: "finished",
                    state: .finished,
                    kickoff: now.addingTimeInterval(-7_200),
                    score: (2, 1)
                ),
                fixture(
                    id: "cancelled",
                    state: .cancelled,
                    kickoff: now.addingTimeInterval(3_600)
                )
            ],
            follows: [followedTeam()],
            language: .english,
            isDemo: false,
            savedAt: now
        )

        XCTAssertNil(snapshot)
    }

    func testStoreRoundTripsAndRejectsUnknownSchema() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SportsHubWidgetTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = WidgetMatchSnapshotStore(
            fileURL: root.appendingPathComponent(WidgetMatchContract.fileName)
        )
        let snapshot = try XCTUnwrap(WidgetMatchSnapshotSelector.select(
            from: [fixture(id: "fixture-1", state: .upcoming, kickoff: now)],
            follows: [followedTeam()],
            language: .english,
            isDemo: false,
            savedAt: now
        ))

        try store.write(snapshot)
        XCTAssertEqual(try store.read(), snapshot)

        let raw = try String(contentsOf: store.fileURL, encoding: .utf8)
        let incompatible = raw.replacingOccurrences(
            of: "\"schemaVersion\":1",
            with: "\"schemaVersion\":2"
        )
        try Data(incompatible.utf8).write(to: store.fileURL, options: .atomic)
        XCTAssertThrowsError(try store.read()) { error in
            XCTAssertEqual(error as? WidgetMatchSnapshotError, .invalidSchemaVersion)
        }

        try Data(
            repeating: 0,
            count: WidgetMatchContract.maximumEncodedSize + 1
        ).write(to: store.fileURL, options: .atomic)
        XCTAssertThrowsError(try store.read()) { error in
            XCTAssertEqual(error as? WidgetMatchSnapshotError, .invalidFile)
        }
    }

    func testStalenessIsStateAware() throws {
        let live = try XCTUnwrap(WidgetMatchSnapshotSelector.select(
            from: [
                fixture(
                    id: "live",
                    state: .live,
                    kickoff: now.addingTimeInterval(-600),
                    score: (0, 0)
                )
            ],
            follows: [followedTeam()],
            language: .english,
            isDemo: false,
            savedAt: now
        ))
        XCTAssertFalse(live.isStale(at: now.addingTimeInterval(899)))
        XCTAssertTrue(live.isStale(at: now.addingTimeInterval(901)))

        let upcoming = try XCTUnwrap(WidgetMatchSnapshotSelector.select(
            from: [
                fixture(
                    id: "upcoming",
                    state: .upcoming,
                    kickoff: now.addingTimeInterval(3_600)
                )
            ],
            follows: [followedTeam()],
            language: .english,
            isDemo: false,
            savedAt: now
        ))
        XCTAssertTrue(upcoming.isStale(at: now.addingTimeInterval(4_501)))
    }

    func testCoordinatorReloadsAfterWriteAndClear() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SportsHubWidgetCoordinatorTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = WidgetMatchSnapshotStore(
            fileURL: root.appendingPathComponent(WidgetMatchContract.fileName)
        )
        let reloader = RecordingWidgetTimelineReloader()
        let coordinator = WidgetMatchSnapshotCoordinator(
            store: store,
            timelineReloader: reloader
        )

        let update = coordinator.publish(
            fixtures: [fixture(id: "fixture-1", state: .upcoming, kickoff: now)],
            follows: [followedTeam()],
            language: .english,
            isDemo: false,
            now: now
        )
        guard case .updated = update else {
            return XCTFail("Expected a persisted widget snapshot")
        }
        XCTAssertEqual(reloader.reloadCount, 1)
        XCTAssertNotNil(try store.read())

        XCTAssertEqual(coordinator.updateFollows([]), .cleared)
        XCTAssertEqual(reloader.reloadCount, 2)
        XCTAssertNil(try store.read())
    }

    func testLanguageUpdatePreservesOriginalSnapshotAge() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SportsHubWidgetLanguageTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = WidgetMatchSnapshotStore(
            fileURL: root.appendingPathComponent(WidgetMatchContract.fileName)
        )
        let coordinator = WidgetMatchSnapshotCoordinator(
            store: store,
            timelineReloader: RecordingWidgetTimelineReloader()
        )
        _ = coordinator.publish(
            fixtures: [
                fixture(
                    id: "fixture-1",
                    state: .upcoming,
                    kickoff: now.addingTimeInterval(3_600)
                )
            ],
            follows: [followedTeam()],
            language: .english,
            isDemo: false,
            now: now
        )

        guard case let .updated(snapshot) = coordinator.updateLanguage(.arabic) else {
            return XCTFail("Expected language change to republish the cached snapshot")
        }
        XCTAssertEqual(snapshot.preferredLanguage, .arabic)
        XCTAssertEqual(snapshot.savedAt, now)
        XCTAssertEqual(try store.read()?.savedAt, now)
    }

    private func followedTeam() -> SportsFollow {
        SportsFollow(
            id: "follow-team-home",
            type: .team,
            entityID: "home",
            createdAt: now,
            entity: .team(team(id: "home"))
        )
    }

    private func team(id: String) -> Team {
        Team(
            id: id,
            nameArabic: "فريق \(id)",
            nameEnglish: "Team \(id)",
            monogram: "T",
            colorHex: "057385"
        )
    }

    private func fixture(
        id: String,
        state: FixtureState,
        kickoff: Date,
        home: Team? = nil,
        away: Team? = nil,
        score: (Int, Int)? = nil
    ) -> Fixture {
        Fixture(
            id: id,
            competition: MockSportsData.competition,
            homeTeam: home ?? team(id: "home"),
            awayTeam: away ?? team(id: "away"),
            kickoff: kickoff,
            state: state,
            minute: state == .live ? 31 : nil,
            homeScore: score?.0,
            awayScore: score?.1,
            venueArabic: "الملعب",
            venueEnglish: "Stadium",
            revision: state == .live ? 3 : 0
        )
    }
}

@MainActor
private final class RecordingWidgetTimelineReloader: WidgetTimelineReloading {
    private(set) var reloadCount = 0

    func reloadNextMatchTimeline() {
        reloadCount += 1
    }
}
