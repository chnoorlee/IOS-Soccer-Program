import XCTest
@testable import SportsHub

final class MultiEntityFollowContractTests: XCTestCase {
    func testCanonicalOrderUsesNewestThenTypeAndEntityID() {
        let timestamp = Date(timeIntervalSince1970: 1_785_931_200)
        let team = Team(
            id: "shared",
            nameArabic: "فريق",
            nameEnglish: "Team",
            monogram: "TM",
            colorHex: "0AA9C0"
        )
        let player = PlayerProfile(id: "shared", name: "Player", position: "Forward")
        let competition = Competition(
            id: "league",
            nameArabic: "دوري",
            nameEnglish: "League",
            currentSeasonID: nil,
            seasons: []
        )
        let follows = [
            SportsFollow(
                id: "player",
                type: .player,
                entityID: player.id,
                createdAt: timestamp,
                entity: .player(player)
            ),
            SportsFollow(
                id: "team",
                type: .team,
                entityID: team.id,
                createdAt: timestamp.addingTimeInterval(60),
                entity: .team(team)
            ),
            SportsFollow(
                id: "competition",
                type: .competition,
                entityID: competition.id,
                createdAt: timestamp,
                entity: .competition(competition)
            )
        ]

        XCTAssertEqual(
            follows.canonicalFollowOrder.map(\.id),
            ["team", "competition", "player"]
        )
    }

    func testEntitySnapshotMustMatchEnclosingTypeAndID() {
        let player = PlayerProfile(id: "shared", name: "Player", position: "Forward")
        let matching = SportsFollow(
            id: "matching",
            type: .player,
            entityID: "shared",
            createdAt: .distantPast,
            entity: .player(player)
        )
        let mismatched = SportsFollow(
            id: "mismatched",
            type: .team,
            entityID: "shared",
            createdAt: .distantPast,
            entity: .player(player)
        )

        XCTAssertTrue(matching.hasMatchingEntitySnapshot)
        XCTAssertFalse(mismatched.hasMatchingEntitySnapshot)
    }
}

@MainActor
final class MultiEntityFollowAppModelTests: XCTestCase {
    func testTeamPlayerAndCompetitionFollowsUseIndependentCompoundKeys() async throws {
        let suiteName = "SportsHubTests.MultiEntityFollows.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let provider = MockSportsDataProvider()
        let model = AppModel(dataProvider: provider, defaults: defaults)
        let sharedTeam = Team(
            id: "shared-id",
            nameArabic: "فريق",
            nameEnglish: "Team",
            monogram: "TM",
            colorHex: "0AA9C0"
        )
        let sharedPlayer = PlayerProfile(
            id: "shared-id",
            name: "Player",
            position: "Forward"
        )
        let competition = MockSportsData.competition

        model.toggleFollow(
            type: .team,
            entityID: sharedTeam.id,
            entity: .team(sharedTeam)
        )
        model.toggleFollow(
            type: .player,
            entityID: sharedPlayer.id,
            entity: .player(sharedPlayer)
        )
        model.toggleFollow(
            type: .competition,
            entityID: competition.id,
            entity: .competition(competition)
        )
        await waitForFollowMutations(model)

        XCTAssertEqual(model.followedTeamIDs, ["shared-id"])
        XCTAssertEqual(model.followedPlayerIDs, ["shared-id"])
        XCTAssertEqual(model.followedCompetitionIDs, [competition.id])
        XCTAssertEqual(model.orderedFollows.count, 3)

        model.toggleFollow(
            type: .player,
            entityID: sharedPlayer.id,
            entity: .player(sharedPlayer)
        )
        await waitForFollowMutations(model)

        XCTAssertEqual(model.followedTeamIDs, ["shared-id"])
        XCTAssertTrue(model.followedPlayerIDs.isEmpty)
        XCTAssertEqual(model.followedCompetitionIDs, [competition.id])
    }

    func testFailedMutationRestoresTheExactPreviousFollow() async throws {
        let suiteName = "SportsHubTests.FollowRollback.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let provider = MockSportsDataProvider()
        let model = AppModel(dataProvider: provider, defaults: defaults)
        let team = MockSportsData.teams[0]

        model.toggleFollow(type: .team, entityID: team.id, entity: .team(team))
        await waitForFollowMutations(model)
        let original = try XCTUnwrap(model.orderedFollows.first)
        await provider.failNextFollowMutation(with: .networkUnavailable)

        model.toggleFollow(type: .team, entityID: team.id, entity: .team(team))
        await waitForFollowMutations(model)

        XCTAssertEqual(model.orderedFollows, [original])
        XCTAssertEqual(model.followError, .networkUnavailable)
    }

    func testNewFollowIsRejectedAtTheBoundedCollectionLimit() throws {
        let suiteName = "SportsHubTests.FollowLimit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            (0..<500).map { "team-\($0)" },
            forKey: GuestPersonalizationDefaults.followedTeamIDs
        )
        let model = AppModel(dataProvider: MockSportsDataProvider(), defaults: defaults)
        let competition = MockSportsData.competition

        model.toggleFollow(
            type: .competition,
            entityID: competition.id,
            entity: .competition(competition)
        )

        XCTAssertEqual(model.orderedFollows.count, 500)
        XCTAssertTrue(model.followedCompetitionIDs.isEmpty)
        XCTAssertEqual(model.followError, .contractViolation(field: "follows"))
        XCTAssertFalse(model.isFollowActivityInProgress)
    }

    private func waitForFollowMutations(_ model: AppModel) async {
        while model.isFollowActivityInProgress {
            await Task.yield()
        }
    }
}
