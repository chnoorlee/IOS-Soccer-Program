import Foundation

struct FixtureEventMutation: Equatable, Sendable {
    let id: String
    let revision: Int
    let event: FixtureEvent?

    static func upsert(_ event: FixtureEvent) -> FixtureEventMutation {
        FixtureEventMutation(id: event.id, revision: event.revision, event: event)
    }

    static func deleted(id: String, revision: Int) -> FixtureEventMutation {
        FixtureEventMutation(id: id, revision: revision, event: nil)
    }
}

struct FixtureEventBatch: Equatable, Sendable {
    let fixture: Fixture
    let fixtureRevision: Int
    let mutations: [FixtureEventMutation]
    let updatedAt: Date
}

enum FixtureEventChange: Equatable, Sendable {
    case inserted(FixtureEvent)
    case corrected(FixtureEvent)
    case deleted(id: String)
}

struct MatchLiveTimeline: Equatable, Sendable {
    private(set) var details: MatchDetails
    private var tombstonedEventIDs: Set<String>

    init(snapshot: MatchDetails) throws {
        let normalized = try Self.normalized(snapshot: snapshot)
        details = normalized
        tombstonedEventIDs = []
    }

    @discardableResult
    mutating func replace(with snapshot: MatchDetails) throws -> Bool {
        guard snapshot.fixture.id == details.fixture.id else {
            throw SportsDataError.contractViolation(field: "data.fixture.id")
        }
        guard snapshot.fixture.revision >= details.fixture.revision else {
            return false
        }
        self = try MatchLiveTimeline(snapshot: snapshot)
        return true
    }

    @discardableResult
    mutating func apply(_ batch: FixtureEventBatch) throws -> [FixtureEventChange] {
        guard batch.fixture.id == details.fixture.id else {
            throw SportsDataError.contractViolation(field: "data.fixture.id")
        }
        guard batch.fixtureRevision == batch.fixture.revision else {
            throw SportsDataError.contractViolation(field: "fixtureRevision")
        }
        guard batch.fixtureRevision >= 0 else {
            throw SportsDataError.contractViolation(field: "fixtureRevision")
        }
        guard batch.fixtureRevision > details.fixture.revision else {
            return []
        }

        var previousRevision = details.fixture.revision
        var pendingTombstones = tombstonedEventIDs
        for (index, mutation) in batch.mutations.enumerated() {
            guard mutation.revision > previousRevision,
                  mutation.revision <= batch.fixtureRevision else {
                throw SportsDataError.contractViolation(field: "data[\(index)].revision")
            }
            guard !mutation.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SportsDataError.contractViolation(field: "data[\(index)].id")
            }
            if let event = mutation.event {
                guard event.id == mutation.id, event.revision == mutation.revision else {
                    throw SportsDataError.contractViolation(field: "data[\(index)]")
                }
                guard !pendingTombstones.contains(event.id) else {
                    throw SportsDataError.contractViolation(field: "data[\(index)].id")
                }
                try Self.validate(
                    event: event,
                    fixture: batch.fixture,
                    maximumRevision: batch.fixtureRevision,
                    field: "data[\(index)]"
                )
            } else {
                pendingTombstones.insert(mutation.id)
            }
            previousRevision = mutation.revision
        }

        var eventsByID = Dictionary(uniqueKeysWithValues: details.events.map { ($0.id, $0) })
        var changes: [FixtureEventChange] = []

        for mutation in batch.mutations {
            if let event = mutation.event {
                if eventsByID[event.id] == nil {
                    changes.append(.inserted(event))
                } else if eventsByID[event.id] != event {
                    changes.append(.corrected(event))
                }
                eventsByID[event.id] = event
            } else {
                if eventsByID.removeValue(forKey: mutation.id) != nil {
                    changes.append(.deleted(id: mutation.id))
                }
                tombstonedEventIDs.insert(mutation.id)
            }
        }

        details = MatchDetails(
            fixture: batch.fixture,
            events: Self.sorted(Array(eventsByID.values)),
            homeLineup: details.homeLineup,
            awayLineup: details.awayLineup,
            statistics: details.statistics,
            sourceName: details.sourceName,
            updatedAt: batch.updatedAt
        )
        return changes
    }

    private static func normalized(snapshot: MatchDetails) throws -> MatchDetails {
        guard snapshot.fixture.revision >= 0 else {
            throw SportsDataError.contractViolation(field: "data.fixture.revision")
        }
        var seen = Set<String>()
        for (index, event) in snapshot.events.enumerated() {
            guard seen.insert(event.id).inserted else {
                throw SportsDataError.contractViolation(field: "data.events[\(index)].id")
            }
            try validate(
                event: event,
                fixture: snapshot.fixture,
                maximumRevision: snapshot.fixture.revision,
                field: "data.events[\(index)]"
            )
        }
        return MatchDetails(
            fixture: snapshot.fixture,
            events: sorted(snapshot.events),
            homeLineup: snapshot.homeLineup,
            awayLineup: snapshot.awayLineup,
            statistics: snapshot.statistics,
            sourceName: snapshot.sourceName,
            updatedAt: snapshot.updatedAt
        )
    }

    private static func validate(
        event: FixtureEvent,
        fixture: Fixture,
        maximumRevision: Int,
        field: String
    ) throws {
        guard !event.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SportsDataError.contractViolation(field: "\(field).id")
        }
        guard (0...maximumRevision).contains(event.revision) else {
            throw SportsDataError.contractViolation(field: "\(field).revision")
        }
        guard (0...200).contains(event.minute) else {
            throw SportsDataError.contractViolation(field: "\(field).minute")
        }
        if let addedTime = event.addedTime, addedTime < 0 {
            throw SportsDataError.contractViolation(field: "\(field).addedTime")
        }
        if let teamID = event.teamID,
           teamID != fixture.homeTeam.id,
           teamID != fixture.awayTeam.id {
            throw SportsDataError.contractViolation(field: "\(field).teamId")
        }
    }

    private static func sorted(_ events: [FixtureEvent]) -> [FixtureEvent] {
        events.sorted {
            ($0.minute, $0.addedTime ?? 0, $0.revision, $0.id)
                < ($1.minute, $1.addedTime ?? 0, $1.revision, $1.id)
        }
    }
}

enum MatchLivePollingPolicy {
    private static let liveInterval: TimeInterval = 5
    private static let halfTimeInterval: TimeInterval = 10
    private static let nearKickoffInterval: TimeInterval = 15
    private static let distantKickoffInterval: TimeInterval = 60
    private static let nearKickoffWindow: TimeInterval = 60 * 60
    private static let retryDelays: [TimeInterval] = [2, 5, 10, 20, 30]

    static func allowsIncrementalUpdates(
        after source: PublicContentFreshnessSource?
    ) -> Bool {
        source != .demoFallback
    }

    static func interval(for fixture: Fixture, now: Date) -> TimeInterval? {
        switch fixture.state {
        case .live:
            liveInterval
        case .halfTime:
            halfTimeInterval
        case .upcoming:
            fixture.kickoff.timeIntervalSince(now) <= nearKickoffWindow
                ? nearKickoffInterval
                : distantKickoffInterval
        case .finished, .postponed, .cancelled:
            nil
        }
    }

    static func retryDelay(forAttempt attempt: Int) -> TimeInterval {
        let index = min(max(attempt, 1), retryDelays.count) - 1
        return retryDelays[index]
    }
}
