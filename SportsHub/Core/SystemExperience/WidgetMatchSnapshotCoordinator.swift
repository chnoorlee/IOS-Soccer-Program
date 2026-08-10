import Foundation
import WidgetKit

enum WidgetMatchSnapshotPublishResult: Equatable, Sendable {
    case updated(WidgetMatchSnapshot)
    case cleared
    case unavailable
    case failed
}

@MainActor
protocol WidgetTimelineReloading: AnyObject {
    func reloadNextMatchTimeline()
}

@MainActor
final class SystemWidgetTimelineReloader: WidgetTimelineReloading {
    func reloadNextMatchTimeline() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetMatchContract.widgetKind)
    }
}

enum WidgetMatchSnapshotSelector {
    static func select(
        from fixtures: [Fixture],
        follows: [SportsFollow],
        language: AppLanguage,
        isDemo: Bool,
        savedAt: Date
    ) throws -> WidgetMatchSnapshot? {
        let matcher = FixtureFollowMatcher(follows: follows)
        guard matcher.hasMatchableFollows else { return nil }

        let candidates = fixtures
            .filter { matcher.reason(for: $0) != nil && priority(for: $0.state) != nil }
            .sorted { lhs, rhs in
                let leftPriority = priority(for: lhs.state) ?? .max
                let rightPriority = priority(for: rhs.state) ?? .max
                if leftPriority != rightPriority { return leftPriority < rightPriority }
                if lhs.kickoff != rhs.kickoff { return lhs.kickoff < rhs.kickoff }
                return lhs.id < rhs.id
            }

        guard let fixture = candidates.first else { return nil }
        return try WidgetMatchSnapshot(
            fixtureID: fixture.id,
            competitionArabic: fixture.competition.nameArabic,
            competitionEnglish: fixture.competition.nameEnglish,
            homeTeamArabic: fixture.homeTeam.nameArabic,
            homeTeamEnglish: fixture.homeTeam.nameEnglish,
            awayTeamArabic: fixture.awayTeam.nameArabic,
            awayTeamEnglish: fixture.awayTeam.nameEnglish,
            kickoff: fixture.kickoff,
            state: widgetState(for: fixture.state),
            minute: fixture.minute,
            homeScore: fixture.homeScore,
            awayScore: fixture.awayScore,
            revision: fixture.revision,
            preferredLanguage: language == .arabic ? .arabic : .english,
            isDemo: isDemo,
            savedAt: savedAt
        )
    }

    private static func priority(for state: FixtureState) -> Int? {
        switch state {
        case .live: 0
        case .halfTime: 1
        case .upcoming: 2
        case .finished, .postponed, .cancelled: nil
        }
    }

    private static func widgetState(for state: FixtureState) -> WidgetMatchState {
        switch state {
        case .upcoming: .upcoming
        case .live: .live
        case .halfTime: .halfTime
        case .finished: .finished
        case .postponed: .postponed
        case .cancelled: .cancelled
        }
    }
}

@MainActor
final class WidgetMatchSnapshotCoordinator {
    private let store: WidgetMatchSnapshotStore?
    private let timelineReloader: any WidgetTimelineReloading
    private var latestFixtures: [Fixture]?
    private var latestFollows: [SportsFollow] = []
    private var latestLanguage: AppLanguage = .arabic
    private var latestIsDemo = false
    private var latestSavedAt: Date?

    init(
        store: WidgetMatchSnapshotStore?,
        timelineReloader: any WidgetTimelineReloading = SystemWidgetTimelineReloader()
    ) {
        self.store = store
        self.timelineReloader = timelineReloader
    }

    static func system(bundle: Bundle = .main) -> WidgetMatchSnapshotCoordinator {
        guard let identifier = bundle.object(
            forInfoDictionaryKey: WidgetMatchContract.appGroupInfoKey
        ) as? String else {
            return unavailable()
        }
        return WidgetMatchSnapshotCoordinator(
            store: WidgetMatchSnapshotStore.appGroup(identifier: identifier)
        )
    }

    static func unavailable() -> WidgetMatchSnapshotCoordinator {
        WidgetMatchSnapshotCoordinator(store: nil)
    }

    @discardableResult
    func publish(
        fixtures: [Fixture],
        follows: [SportsFollow],
        language: AppLanguage,
        isDemo: Bool,
        now: Date = Date()
    ) -> WidgetMatchSnapshotPublishResult {
        latestFixtures = fixtures
        latestFollows = follows
        latestLanguage = language
        latestIsDemo = isDemo
        latestSavedAt = now
        return persist(savedAt: now)
    }

    @discardableResult
    func updateFollows(
        _ follows: [SportsFollow]
    ) -> WidgetMatchSnapshotPublishResult {
        latestFollows = follows
        guard latestFixtures != nil, let latestSavedAt else { return .unavailable }
        return persist(savedAt: latestSavedAt)
    }

    @discardableResult
    func updateLanguage(
        _ language: AppLanguage
    ) -> WidgetMatchSnapshotPublishResult {
        latestLanguage = language
        guard latestFixtures != nil, let latestSavedAt else { return .unavailable }
        return persist(savedAt: latestSavedAt)
    }

    @discardableResult
    func clear(resetCachedFixtures: Bool = true) -> WidgetMatchSnapshotPublishResult {
        if resetCachedFixtures {
            latestFixtures = nil
            latestSavedAt = nil
        }
        guard let store else { return .unavailable }
        do {
            try store.clear()
            timelineReloader.reloadNextMatchTimeline()
            return .cleared
        } catch {
            return .failed
        }
    }

    private func persist(savedAt: Date) -> WidgetMatchSnapshotPublishResult {
        guard let store, let latestFixtures else { return .unavailable }
        do {
            guard let snapshot = try WidgetMatchSnapshotSelector.select(
                from: latestFixtures,
                follows: latestFollows,
                language: latestLanguage,
                isDemo: latestIsDemo,
                savedAt: savedAt
            ) else {
                try store.clear()
                timelineReloader.reloadNextMatchTimeline()
                return .cleared
            }
            try store.write(snapshot)
            timelineReloader.reloadNextMatchTimeline()
            return .updated(snapshot)
        } catch {
            return .failed
        }
    }
}
