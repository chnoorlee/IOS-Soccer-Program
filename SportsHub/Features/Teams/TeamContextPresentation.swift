import Foundation

/// Maps the server-ordered team channel window into the two primary match
/// slots. Association, state and ordering are validated at the data boundary.
struct TeamContextPresentation: Equatable, Sendable {
    let previousFixture: Fixture?
    let nextFixture: Fixture?
    let additionalRecentFixtures: [Fixture]
    let additionalUpcomingFixtures: [Fixture]

    init(details: TeamDetails) {
        previousFixture = details.recentFixtures.first
        nextFixture = details.nextFixtures.first
        additionalRecentFixtures = Array(details.recentFixtures.dropFirst())
        additionalUpcomingFixtures = Array(details.nextFixtures.dropFirst())
    }
}
