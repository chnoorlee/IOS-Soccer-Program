import ActivityKit
import Foundation

struct MatchActivityAttributes: ActivityAttributes, Hashable, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        let competitionName: String
        let homeTeamName: String
        let awayTeamName: String
        let preferredLanguageCode: String
        let homeScore: Int?
        let awayScore: Int?
        let minute: Int?
        let fixtureState: String
        let statusText: String
        let updatedAt: Date
        let isDemo: Bool
    }

    let fixtureID: String
}
