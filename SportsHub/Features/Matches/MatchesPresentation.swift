import Foundation

enum MatchesStatusFilter: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all
    case live

    var id: String { rawValue }
    var localizationKey: String { "matches.\(rawValue)" }

    func includes(_ state: FixtureState) -> Bool {
        switch self {
        case .all:
            true
        case .live:
            state == .live || state == .halfTime
        }
    }
}

enum MatchesScope: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all
    case following

    var id: String { rawValue }
    var localizationKey: String { "matches.scope.\(rawValue)" }
}

enum MatchesEmptyReason: String, Equatable, Sendable {
    case date
    case live
    case liveInCompetition
    case noMatchableFollows
    case following
    case followingInCompetition

    var localizationKey: String {
        switch self {
        case .date: "matches.noFixtures"
        case .live: "matches.noLiveFixtures"
        case .liveInCompetition: "matches.noLiveFixturesForCompetition"
        case .noMatchableFollows: "matches.noMatchableFollows"
        case .following: "matches.noFollowingFixtures"
        case .followingInCompetition: "matches.noFollowingFixturesForCompetition"
        }
    }

    var descriptionLocalizationKey: String? {
        switch self {
        case .date, .live, .liveInCompetition:
            nil
        case .noMatchableFollows:
            "matches.noMatchableFollowsBody"
        case .following:
            "matches.noFollowingFixturesBody"
        case .followingInCompetition:
            "matches.noFollowingFixturesForCompetitionBody"
        }
    }
}

struct CompetitionFixtureGroup: Equatable, Identifiable, Sendable {
    let competition: Competition
    let fixtures: [Fixture]

    var id: String { competition.id }
}

struct MatchesPresentation: Equatable, Sendable {
    let availableCompetitions: [Competition]
    let selectedCompetitionID: String?
    let groups: [CompetitionFixtureGroup]
    let followReasonsByFixtureID: [String: FixtureFollowReason]
    let emptyReason: MatchesEmptyReason?

    init(
        fixtures: [Fixture],
        statusFilter: MatchesStatusFilter,
        selectedCompetitionID requestedCompetitionID: String?,
        scope: MatchesScope = .all,
        follows: [SportsFollow] = []
    ) {
        let followMatcher = FixtureFollowMatcher(follows: follows)
        var seenCompetitionIDs = Set<String>()
        let availableCompetitions = fixtures.compactMap { fixture in
            seenCompetitionIDs.insert(fixture.competition.id).inserted
                ? fixture.competition
                : nil
        }
        let selectedCompetitionID = requestedCompetitionID.flatMap { requestedID in
            availableCompetitions.contains { $0.id == requestedID }
                ? requestedID
                : nil
        }

        let visibleFixtures = fixtures.filter { fixture in
            statusFilter.includes(fixture.state)
                && (scope == .all || followMatcher.reason(for: fixture) != nil)
                && (selectedCompetitionID == nil
                    || fixture.competition.id == selectedCompetitionID)
        }
        var fixturesByCompetitionID: [String: [Fixture]] = [:]
        for fixture in visibleFixtures {
            fixturesByCompetitionID[fixture.competition.id, default: []].append(fixture)
        }
        let groups: [CompetitionFixtureGroup] = availableCompetitions.compactMap { competition in
            guard let groupedFixtures = fixturesByCompetitionID[competition.id],
                  !groupedFixtures.isEmpty else {
                return nil
            }
            return CompetitionFixtureGroup(
                competition: competition,
                fixtures: groupedFixtures
            )
        }

        self.availableCompetitions = availableCompetitions
        self.selectedCompetitionID = selectedCompetitionID
        self.groups = groups
        if scope == .following {
            followReasonsByFixtureID = visibleFixtures.reduce(
                into: [String: FixtureFollowReason]()
            ) { reasons, fixture in
                if let reason = followMatcher.reason(for: fixture) {
                    reasons[fixture.id] = reason
                }
            }
        } else {
            followReasonsByFixtureID = [:]
        }
        if groups.isEmpty {
            if scope == .following, !followMatcher.hasMatchableFollows {
                emptyReason = .noMatchableFollows
            } else if scope == .following, selectedCompetitionID != nil {
                emptyReason = .followingInCompetition
            } else if scope == .following {
                emptyReason = .following
            } else if statusFilter == .live, selectedCompetitionID != nil {
                emptyReason = .liveInCompetition
            } else if statusFilter == .live {
                emptyReason = .live
            } else {
                emptyReason = .date
            }
        } else {
            emptyReason = nil
        }
    }
}
