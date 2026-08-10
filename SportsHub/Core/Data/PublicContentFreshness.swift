import Foundation

enum PublicContentResource: Hashable, Sendable {
    case home
    case fixtures(day: String, timeZone: String)
    case competitionFixtures(id: String, seasonID: String)
    case team(id: String)
    case teamMatchSnapshots(ids: [String])
    case fixture(id: String)
    case fixtureContent(id: String)
    case fixtureStandings(id: String)
    case fixtureHeadToHead(id: String)
    case teamContent(id: String)
    case playerContent(id: String)
    case competitionContent(id: String)
    case transfers(status: TransferStatus?)
    case seasonCalendar
    case articles
    case article(id: String)
    case videoDiscovery
    case videoPrograms(sport: VideoSport?)
    case videoProgram(id: String)
    case videos
    case video(id: String)
    case predictionGames

    static func fixtures(
        on date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> PublicContentResource {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return .fixtures(
            day: formatter.string(from: date),
            timeZone: timeZone.identifier
        )
    }
}

enum PublicContentFreshnessSource: String, Hashable, Sendable {
    case network
    case revalidated
    case offlineSnapshot
    case accountLive
    case demo
    case demoFallback
    case refreshFailed
}

struct PublicContentFreshness: Equatable, Sendable {
    let source: PublicContentFreshnessSource
    let contentStoredAt: Date?
    let checkedAt: Date?

    static func network(at date: Date) -> PublicContentFreshness {
        PublicContentFreshness(source: .network, contentStoredAt: date, checkedAt: date)
    }

    static func revalidated(
        storedAt: Date,
        checkedAt: Date
    ) -> PublicContentFreshness {
        PublicContentFreshness(
            source: .revalidated,
            contentStoredAt: storedAt,
            checkedAt: checkedAt
        )
    }

    static func offlineSnapshot(
        storedAt: Date,
        checkedAt: Date
    ) -> PublicContentFreshness {
        PublicContentFreshness(
            source: .offlineSnapshot,
            contentStoredAt: storedAt,
            checkedAt: checkedAt
        )
    }

    static func accountLive(checkedAt: Date) -> PublicContentFreshness {
        PublicContentFreshness(
            source: .accountLive,
            contentStoredAt: nil,
            checkedAt: checkedAt
        )
    }

    static let demo = PublicContentFreshness(
        source: .demo,
        contentStoredAt: nil,
        checkedAt: nil
    )

    static func demoFallback(checkedAt: Date) -> PublicContentFreshness {
        PublicContentFreshness(
            source: .demoFallback,
            contentStoredAt: nil,
            checkedAt: checkedAt
        )
    }

    static func refreshFailed(at date: Date) -> PublicContentFreshness {
        PublicContentFreshness(
            source: .refreshFailed,
            contentStoredAt: nil,
            checkedAt: date
        )
    }

    var requiresAttention: Bool {
        switch source {
        case .offlineSnapshot, .demoFallback, .refreshFailed:
            true
        case .network, .revalidated, .accountLive, .demo:
            false
        }
    }
}

protocol PublicContentFreshnessReporting: Sendable {
    func record(
        _ freshness: PublicContentFreshness,
        for resource: PublicContentResource
    ) async
    func removeStatus(for resource: PublicContentResource) async
}

protocol PublicContentFreshnessReading: Sendable {
    func status(for resource: PublicContentResource) async -> PublicContentFreshness?
}

actor PublicContentFreshnessStore: PublicContentFreshnessReporting, PublicContentFreshnessReading {
    private static let maximumResourceCount = 256
    private var statuses: [PublicContentResource: PublicContentFreshness]

    init(initialStatuses: [PublicContentResource: PublicContentFreshness] = [:]) {
        statuses = initialStatuses
    }

    func record(
        _ freshness: PublicContentFreshness,
        for resource: PublicContentResource
    ) {
        if let existing = statuses[resource],
           let existingCheckedAt = existing.checkedAt,
           let incomingCheckedAt = freshness.checkedAt,
           existingCheckedAt > incomingCheckedAt {
            return
        }
        statuses[resource] = freshness
        pruneIfNeeded()
    }

    func removeStatus(for resource: PublicContentResource) {
        statuses[resource] = nil
    }

    func status(for resource: PublicContentResource) -> PublicContentFreshness? {
        statuses[resource]
    }

    private func pruneIfNeeded() {
        while statuses.count > Self.maximumResourceCount {
            guard let oldestResource = statuses.min(by: {
                ($0.value.checkedAt ?? .distantPast) < ($1.value.checkedAt ?? .distantPast)
            })?.key else {
                return
            }
            statuses[oldestResource] = nil
        }
    }
}

struct NoopPublicContentFreshnessReporter: PublicContentFreshnessReporting {
    func record(
        _ freshness: PublicContentFreshness,
        for resource: PublicContentResource
    ) async {}

    func removeStatus(for resource: PublicContentResource) async {}
}
