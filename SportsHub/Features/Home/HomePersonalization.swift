import Foundation

typealias HomeFixtureFollowReason = FixtureFollowReason

struct HomeRelatedFixture: Equatable, Identifiable, Sendable {
    let fixture: Fixture
    let reason: HomeFixtureFollowReason

    var id: String { fixture.id }
}

struct HomePersonalization: Equatable, Sendable {
    let relatedFixtures: [HomeRelatedFixture]
    let generalFixtures: [Fixture]

    init(fixtures: [Fixture], follows: [SportsFollow]) {
        let matcher = FixtureFollowMatcher(follows: follows)

        var relatedFixtures: [HomeRelatedFixture] = []
        var generalFixtures: [Fixture] = []
        relatedFixtures.reserveCapacity(fixtures.count)
        generalFixtures.reserveCapacity(fixtures.count)

        for fixture in fixtures {
            if let reason = matcher.reason(for: fixture) {
                relatedFixtures.append(
                    HomeRelatedFixture(fixture: fixture, reason: reason)
                )
            } else {
                generalFixtures.append(fixture)
            }
        }

        self.relatedFixtures = relatedFixtures
        self.generalFixtures = generalFixtures
    }
}
