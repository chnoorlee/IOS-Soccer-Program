import ActivityKit
import Foundation

enum MatchLiveActivityEligibility: Equatable, Sendable {
    case eligible
    case kickoffTooDistant
    case terminal
}

enum MatchLiveActivityOperationError: Error, Equatable, Sendable {
    case disabled
    case ineligible(MatchLiveActivityEligibility)
    case invalidPayload
    case requestFailed
}

enum MatchLiveActivitySyncResult: Equatable, Sendable {
    case started
    case updated
    case unchanged
    case ended
    case noActivity
    case failed
}

enum MatchLiveActivityDismissal: Equatable, Sendable {
    case immediate
    case after(Date)
}

struct MatchLiveActivityPayload: Equatable, Sendable {
    let attributes: MatchActivityAttributes
    let state: MatchActivityAttributes.ContentState
    let staleDate: Date?
    let relevanceScore: Double
}

enum MatchLiveActivityPolicy {
    static let maximumActivityRuntime: TimeInterval = 8 * 60 * 60
    static let maximumUpcomingLeadInterval: TimeInterval = maximumActivityRuntime / 2
    static let maximumKickoffGraceInterval: TimeInterval = 15 * 60
    static let maximumUpcomingFreshnessInterval: TimeInterval = 15 * 60

    static func eligibility(
        for fixture: Fixture,
        now: Date = Date()
    ) -> MatchLiveActivityEligibility {
        switch fixture.state {
        case .live, .halfTime:
            return .eligible
        case .upcoming:
            let intervalUntilKickoff = fixture.kickoff.timeIntervalSince(now)
            if intervalUntilKickoff < -maximumKickoffGraceInterval {
                return .terminal
            } else if intervalUntilKickoff <= maximumUpcomingLeadInterval {
                return .eligible
            } else {
                return .kickoffTooDistant
            }
        case .finished, .postponed, .cancelled:
            return .terminal
        }
    }

    static func payload(
        for fixture: Fixture,
        language: AppLanguage,
        isDemo: Bool,
        updatedAt: Date
    ) throws -> MatchLiveActivityPayload {
        guard Self.isValidIdentifier(fixture.id),
              Self.isValidText(fixture.competition.displayName(in: language)),
              Self.isValidText(fixture.homeTeam.displayName(in: language)),
              Self.isValidText(fixture.awayTeam.displayName(in: language)),
              fixture.revision >= 0,
              updatedAt.timeIntervalSinceReferenceDate.isFinite,
              (fixture.homeScore == nil) == (fixture.awayScore == nil),
              [fixture.homeScore, fixture.awayScore]
                .compactMap({ $0 })
                .allSatisfy({ (0...99).contains($0) }),
              fixture.minute.map({ (0...200).contains($0) }) ?? true,
              fixture.state != .upcoming || fixture.homeScore == nil,
              fixture.state != .upcoming || fixture.minute == nil,
              !Self.isLive(fixture.state) || fixture.homeScore != nil else {
            throw MatchLiveActivityOperationError.invalidPayload
        }

        return MatchLiveActivityPayload(
            attributes: MatchActivityAttributes(
                fixtureID: fixture.id
            ),
            state: MatchActivityAttributes.ContentState(
                competitionName: fixture.competition.displayName(in: language),
                homeTeamName: fixture.homeTeam.displayName(in: language),
                awayTeamName: fixture.awayTeam.displayName(in: language),
                preferredLanguageCode: language.rawValue,
                homeScore: fixture.homeScore,
                awayScore: fixture.awayScore,
                minute: fixture.minute,
                fixtureState: fixture.state.rawValue,
                statusText: statusText(for: fixture.state, language: language),
                updatedAt: updatedAt,
                isDemo: isDemo
            ),
            staleDate: staleDate(for: fixture, updatedAt: updatedAt),
            relevanceScore: relevanceScore(for: fixture.state)
        )
    }

    static func dismissal(
        for fixture: Fixture,
        now: Date = Date()
    ) -> MatchLiveActivityDismissal {
        fixture.state == .finished
            ? .after(now.addingTimeInterval(60 * 60))
            : .immediate
    }

    private static func staleDate(for fixture: Fixture, updatedAt: Date) -> Date? {
        switch fixture.state {
        case .live:
            updatedAt.addingTimeInterval(30)
        case .halfTime:
            updatedAt.addingTimeInterval(2 * 60)
        case .upcoming:
            min(
                updatedAt.addingTimeInterval(maximumUpcomingFreshnessInterval),
                fixture.kickoff.addingTimeInterval(maximumKickoffGraceInterval)
            )
        case .finished, .postponed, .cancelled:
            nil
        }
    }

    private static func relevanceScore(for state: FixtureState) -> Double {
        switch state {
        case .live: 100
        case .halfTime: 80
        case .upcoming: 40
        case .finished: 20
        case .postponed, .cancelled: 0
        }
    }

    private static func statusText(
        for state: FixtureState,
        language: AppLanguage
    ) -> String {
        switch state {
        case .upcoming:
            String(localized: "match.upcoming", locale: language.locale)
        case .live:
            String(localized: "match.live", locale: language.locale)
        case .halfTime:
            String(localized: "match.halftime", locale: language.locale)
        case .finished:
            String(localized: "match.finished", locale: language.locale)
        case .postponed:
            String(localized: "match.postponed", locale: language.locale)
        case .cancelled:
            String(localized: "match.cancelled", locale: language.locale)
        }
    }

    private static func isLive(_ state: FixtureState) -> Bool {
        state == .live || state == .halfTime
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        guard (1...128).contains(value.count), value != ".", value != ".." else {
            return false
        }
        let punctuation = CharacterSet(charactersIn: "-._~")
        return value.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) || punctuation.contains(scalar)
        }
    }

    private static func isValidText(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == value
            && (1...120).contains(value.count)
            && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }
}

@MainActor
protocol MatchActivityClient: AnyObject {
    var areActivitiesEnabled: Bool { get }
    func activeFixtureIDs() -> Set<String>
    func request(_ payload: MatchLiveActivityPayload) throws
    func update(_ payload: MatchLiveActivityPayload) async
    func end(
        _ payload: MatchLiveActivityPayload?,
        fixtureID: String,
        dismissal: MatchLiveActivityDismissal
    ) async
}

@MainActor
final class SystemMatchActivityClient: MatchActivityClient {
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func activeFixtureIDs() -> Set<String> {
        Set(Activity<MatchActivityAttributes>.activities.map(\.attributes.fixtureID))
    }

    func request(_ payload: MatchLiveActivityPayload) throws {
        let content = ActivityContent(
            state: payload.state,
            staleDate: payload.staleDate,
            relevanceScore: payload.relevanceScore
        )
        _ = try Activity.request(
            attributes: payload.attributes,
            content: content,
            pushType: nil
        )
    }

    func update(_ payload: MatchLiveActivityPayload) async {
        let content = ActivityContent(
            state: payload.state,
            staleDate: payload.staleDate,
            relevanceScore: payload.relevanceScore
        )
        for activity in Activity<MatchActivityAttributes>.activities
        where activity.attributes.fixtureID == payload.attributes.fixtureID {
            await activity.update(content)
        }
    }

    func end(
        _ payload: MatchLiveActivityPayload?,
        fixtureID: String,
        dismissal: MatchLiveActivityDismissal
    ) async {
        let content = payload.map {
            ActivityContent(
                state: $0.state,
                staleDate: $0.staleDate,
                relevanceScore: $0.relevanceScore
            )
        }
        let policy: ActivityUIDismissalPolicy
        switch dismissal {
        case .immediate:
            policy = .immediate
        case let .after(date):
            policy = .after(date)
        }
        for activity in Activity<MatchActivityAttributes>.activities
        where activity.attributes.fixtureID == fixtureID {
            await activity.end(content, dismissalPolicy: policy)
        }
    }
}

@MainActor
final class MatchLiveActivityCoordinator {
    private let client: any MatchActivityClient
    private var lastPayloadByFixtureID: [String: MatchLiveActivityPayload] = [:]

    init(client: any MatchActivityClient = SystemMatchActivityClient()) {
        self.client = client
    }

    static func system() -> MatchLiveActivityCoordinator {
        MatchLiveActivityCoordinator()
    }

    var areActivitiesEnabled: Bool { client.areActivitiesEnabled }

    func isActive(fixtureID: String) -> Bool {
        client.activeFixtureIDs().contains(fixtureID)
    }

    func start(
        fixture: Fixture,
        language: AppLanguage,
        isDemo: Bool,
        updatedAt: Date
    ) async throws -> MatchLiveActivitySyncResult {
        guard client.areActivitiesEnabled else {
            throw MatchLiveActivityOperationError.disabled
        }
        let eligibility = MatchLiveActivityPolicy.eligibility(for: fixture)
        guard eligibility == .eligible else {
            throw MatchLiveActivityOperationError.ineligible(eligibility)
        }
        let payload = try MatchLiveActivityPolicy.payload(
            for: fixture,
            language: language,
            isDemo: isDemo,
            updatedAt: updatedAt
        )
        if isActive(fixtureID: fixture.id) {
            if lastPayloadByFixtureID[fixture.id] == payload { return .unchanged }
            await client.update(payload)
            lastPayloadByFixtureID[fixture.id] = payload
            return .updated
        }
        do {
            try client.request(payload)
            lastPayloadByFixtureID[fixture.id] = payload
            return .started
        } catch {
            throw MatchLiveActivityOperationError.requestFailed
        }
    }

    func synchronize(
        fixture: Fixture,
        language: AppLanguage,
        isDemo: Bool,
        updatedAt: Date,
        now: Date = Date()
    ) async -> MatchLiveActivitySyncResult {
        guard isActive(fixtureID: fixture.id) else {
            lastPayloadByFixtureID.removeValue(forKey: fixture.id)
            return .noActivity
        }

        let eligibility = MatchLiveActivityPolicy.eligibility(for: fixture, now: now)
        if eligibility != .eligible {
            let finalPayload: MatchLiveActivityPayload?
            let dismissal: MatchLiveActivityDismissal
            do {
                finalPayload = try MatchLiveActivityPolicy.payload(
                    for: fixture,
                    language: language,
                    isDemo: isDemo,
                    updatedAt: updatedAt
                )
                dismissal = eligibility == .terminal
                    ? MatchLiveActivityPolicy.dismissal(for: fixture, now: now)
                    : .immediate
            } catch {
                finalPayload = nil
                dismissal = .immediate
            }
            await client.end(
                finalPayload,
                fixtureID: fixture.id,
                dismissal: dismissal
            )
            lastPayloadByFixtureID.removeValue(forKey: fixture.id)
            return .ended
        }

        do {
            let payload = try MatchLiveActivityPolicy.payload(
                for: fixture,
                language: language,
                isDemo: isDemo,
                updatedAt: updatedAt
            )
            guard lastPayloadByFixtureID[fixture.id] != payload else { return .unchanged }
            await client.update(payload)
            lastPayloadByFixtureID[fixture.id] = payload
            return .updated
        } catch {
            return .failed
        }
    }

    func stop(
        fixture: Fixture,
        language: AppLanguage,
        isDemo: Bool,
        updatedAt: Date
    ) async {
        let payload: MatchLiveActivityPayload?
        do {
            payload = try MatchLiveActivityPolicy.payload(
                for: fixture,
                language: language,
                isDemo: isDemo,
                updatedAt: updatedAt
            )
        } catch {
            payload = lastPayloadByFixtureID[fixture.id]
        }
        await client.end(payload, fixtureID: fixture.id, dismissal: .immediate)
        lastPayloadByFixtureID.removeValue(forKey: fixture.id)
    }
}
