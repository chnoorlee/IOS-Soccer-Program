import Foundation

enum FixtureFollowReason: String, Equatable, Sendable {
    case team
    case competition
    case teamAndCompetition

    var homeLocalizationKey: String {
        "home.reason.\(rawValue)"
    }

    var matchesLocalizationKey: String {
        "matches.reason.\(rawValue)"
    }
}

struct FixtureFollowMatcher: Equatable, Sendable {
    private let followedTeamIDs: Set<String>
    private let followedCompetitionIDs: Set<String>

    init(follows: [SportsFollow]) {
        followedTeamIDs = Set(
            follows.lazy.filter { $0.type == .team }.map(\.entityID)
        )
        followedCompetitionIDs = Set(
            follows.lazy.filter { $0.type == .competition }.map(\.entityID)
        )
    }

    var hasMatchableFollows: Bool {
        !followedTeamIDs.isEmpty || !followedCompetitionIDs.isEmpty
    }

    func reason(for fixture: Fixture) -> FixtureFollowReason? {
        let matchesTeam = followedTeamIDs.contains(fixture.homeTeam.id)
            || followedTeamIDs.contains(fixture.awayTeam.id)
        let matchesCompetition = followedCompetitionIDs.contains(
            fixture.competition.id
        )

        switch (matchesTeam, matchesCompetition) {
        case (true, true): return .teamAndCompetition
        case (true, false): return .team
        case (false, true): return .competition
        case (false, false): return nil
        }
    }
}
