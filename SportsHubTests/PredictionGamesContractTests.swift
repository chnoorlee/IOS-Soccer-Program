import Foundation
import XCTest
@testable import SportsHub

final class PredictionGamesContractTests: XCTestCase {
    func testDraftStartsInProviderOrderAndMovesOnePositionAtATime() throws {
        let game = try XCTUnwrap(MockSportsData.predictionGames.first)
        var draft = try PredictionDraft(game: game)
        let group = try XCTUnwrap(game.groups.first)

        XCTAssertEqual(draft.gameID, game.id)
        XCTAssertEqual(draft.teamIDs(in: group.id), group.teams.map(\.id))
        XCTAssertFalse(
            draft.canMove(
                teamID: group.teams[0].id,
                in: group.id,
                direction: .up
            )
        )

        draft.move(
            teamID: group.teams[1].id,
            in: group.id,
            direction: .up
        )

        XCTAssertEqual(
            draft.teamIDs(in: group.id),
            [group.teams[1].id, group.teams[0].id, group.teams[2].id, group.teams[3].id]
        )
        XCTAssertEqual(draft.position(of: group.teams[1].id, in: group.id), 1)
        XCTAssertFalse(
            draft.canMove(
                teamID: group.teams[1].id,
                in: group.id,
                direction: .up
            )
        )
    }

    func testEntryContractRequiresProviderGroupOrderAndAnExactTeamPermutation() throws {
        let game = twoGroupGame
        let valid = game.groups.map {
            PredictionGroupRanking(
                groupID: $0.id,
                orderedTeamIDs: Array($0.teams.map(\.id).reversed())
            )
        }

        XCTAssertNoThrow(try PredictionEntryContract.validate(valid, for: game))
        XCTAssertThrowsError(
            try PredictionEntryContract.validate(Array(valid.reversed()), for: game)
        )

        var incomplete = valid
        incomplete[0] = PredictionGroupRanking(
            groupID: incomplete[0].groupID,
            orderedTeamIDs: Array(incomplete[0].orderedTeamIDs.dropLast())
        )
        XCTAssertThrowsError(try PredictionEntryContract.validate(incomplete, for: game))

        var duplicated = valid
        duplicated[0] = PredictionGroupRanking(
            groupID: duplicated[0].groupID,
            orderedTeamIDs: ["team-a", "team-a"]
        )
        XCTAssertThrowsError(try PredictionEntryContract.validate(duplicated, for: game))
    }

    func testEditabilityRequiresOpenStateAndAClockBeforeServerLock() {
        let lockAt = Date(timeIntervalSince1970: 2_000)
        let open = game(state: .open, lockAt: lockAt)
        let locked = game(state: .locked, lockAt: lockAt)

        XCTAssertTrue(open.isEditable(at: Date(timeIntervalSince1970: 1_999)))
        XCTAssertFalse(open.isEditable(at: lockAt))
        XCTAssertEqual(open.effectiveState(at: lockAt), .locked)
        XCTAssertFalse(locked.isEditable(at: Date(timeIntervalSince1970: 1_999)))
    }

    func testRemoteListContractMapsProviderOrderAndHTTPSRules() throws {
        let decoded = try APIJSON.makeDecoder().decode(
            PredictionGameListResponseDTO.self,
            from: PredictionPayloads.gameList
        )

        let games = try decoded.domain()
        let game = try XCTUnwrap(games.first)

        XCTAssertEqual(games.map(\.id), ["prediction-1"])
        XCTAssertEqual(game.groups.map(\.id), ["group-a"])
        XCTAssertEqual(
            game.groups[0].teams.map(\.id),
            ["team-one", "team-two", "team-three", "team-four"]
        )
        XCTAssertEqual(game.rulesURL?.scheme, "https")
        XCTAssertEqual(game.groups[0].qualifyingPositions, 2)
    }

    func testRemoteListContractRejectsInsecureRulesAndDuplicateGames() throws {
        let insecure = PredictionPayloads.gameListText.replacingOccurrences(
            of: "https://rules.example.test/predictions/prediction-1",
            with: "http://rules.example.test/predictions/prediction-1"
        )
        let insecureDTO = try APIJSON.makeDecoder().decode(
            PredictionGameListResponseDTO.self,
            from: Data(insecure.utf8)
        )
        XCTAssertThrowsError(try insecureDTO.domain())

        let duplicate = "{\"data\":[\(PredictionPayloads.gameJSON),\(PredictionPayloads.gameJSON)]}"
        let duplicateDTO = try APIJSON.makeDecoder().decode(
            PredictionGameListResponseDTO.self,
            from: Data(duplicate.utf8)
        )
        XCTAssertThrowsError(try duplicateDTO.domain())
    }

    func testRemoteEntryContractRejectsWrongGameAndIncompleteRanking() throws {
        let game = try APIJSON.makeDecoder()
            .decode(PredictionGameListResponseDTO.self, from: PredictionPayloads.gameList)
            .domain()[0]
        let wrongGame = PredictionPayloads.entryResponseText.replacingOccurrences(
            of: "prediction-1",
            with: "prediction-2"
        )
        let wrongGameDTO = try APIJSON.makeDecoder().decode(
            PredictionEntryResponseDTO.self,
            from: Data(wrongGame.utf8)
        )
        XCTAssertThrowsError(try wrongGameDTO.data.domain(for: game))

        let incomplete = PredictionPayloads.entryResponseText.replacingOccurrences(
            of: ",\"team-four\"",
            with: ""
        )
        let incompleteDTO = try APIJSON.makeDecoder().decode(
            PredictionEntryResponseDTO.self,
            from: Data(incomplete.utf8)
        )
        XCTAssertThrowsError(try incompleteDTO.data.domain(for: game))
    }

    func testMockProviderPersistsOnlyEditableCompleteEntries() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let provider = MockSportsDataProvider(now: { now })
        let games = try await provider.predictionGames()
        let openGame = try XCTUnwrap(games.first(where: { $0.state == .open }))
        let settledGame = try XCTUnwrap(games.first(where: { $0.state == .settled }))
        var draft = try PredictionDraft(game: openGame)
        let group = try XCTUnwrap(openGame.groups.first)
        draft.move(teamID: group.teams[1].id, in: group.id, direction: .up)

        let saved = try await provider.savePredictionEntry(
            for: openGame,
            rankings: draft.rankings
        )
        let reloaded = try await provider.predictionEntry(for: openGame)

        XCTAssertEqual(saved.updatedAt, now)
        XCTAssertEqual(reloaded, saved)
        do {
            _ = try await provider.savePredictionEntry(
                for: settledGame,
                rankings: settledGame.groups.map {
                    PredictionGroupRanking(
                        groupID: $0.id,
                        orderedTeamIDs: $0.teams.map(\.id)
                    )
                }
            )
            XCTFail("Expected a settled game to reject writes")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .forbidden)
        }
    }

    func testFallbackProviderNeverSubstitutesDemoDataForAPrivateEntry() async throws {
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider()
        )
        let game = try XCTUnwrap(MockSportsData.predictionGames.first)

        do {
            _ = try await provider.predictionEntry(for: game)
            XCTFail("Expected the primary private-data error to pass through")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .networkUnavailable)
        }
    }

    func testMockIdentityScopedEntriesDoNotLeakAcrossAccounts() async throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let provider = MockSportsDataProvider(now: { now })
        let games = try await provider.predictionGames()
        let game = try XCTUnwrap(games.first(where: { $0.isEditable(at: now) }))
        let rankings = game.groups.map {
            PredictionGroupRanking(groupID: $0.id, orderedTeamIDs: $0.teams.map(\.id))
        }

        let saved = try await provider.savePredictionEntry(
            for: game,
            rankings: rankings,
            forAccountID: "account-1"
        )
        let firstAccount = try await provider.predictionEntry(
            for: game,
            forAccountID: "account-1"
        )
        let secondAccount = try await provider.predictionEntry(
            for: game,
            forAccountID: "account-2"
        )

        XCTAssertEqual(firstAccount, saved)
        XCTAssertNil(secondAccount)
    }

    func testIdentityScopedFallbackNeverSubstitutesDemoPrivateData() async throws {
        let primary = try RemoteSportsDataProvider(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/v1"))
        )
        let provider = FallbackSportsDataProvider(
            primary: primary,
            fallback: MockSportsDataProvider()
        )
        let game = try XCTUnwrap(MockSportsData.predictionGames.first)

        do {
            _ = try await provider.predictionEntry(
                for: game,
                forAccountID: "account-1"
            )
            XCTFail("Expected the primary authentication error to pass through")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .unauthorized)
        }
    }

    private var twoGroupGame: PredictionGame {
        PredictionGame(
            id: "two-groups",
            titleArabic: "تحدي",
            titleEnglish: "Challenge",
            summaryArabic: "ملخص",
            summaryEnglish: "Summary",
            lockAt: Date(timeIntervalSince1970: 2_000),
            state: .open,
            rulesURL: nil,
            groups: [
                PredictionGroup(
                    id: "group-a",
                    nameArabic: "أ",
                    nameEnglish: "A",
                    teams: [team(id: "team-a"), team(id: "team-b")],
                    qualifyingPositions: 1
                ),
                PredictionGroup(
                    id: "group-b",
                    nameArabic: "ب",
                    nameEnglish: "B",
                    teams: [team(id: "team-c"), team(id: "team-d")],
                    qualifyingPositions: 1
                )
            ]
        )
    }

    private func game(state: PredictionGameState, lockAt: Date) -> PredictionGame {
        PredictionGame(
            id: "clock-game",
            titleArabic: "تحدي",
            titleEnglish: "Challenge",
            summaryArabic: "ملخص",
            summaryEnglish: "Summary",
            lockAt: lockAt,
            state: state,
            rulesURL: nil,
            groups: [
                PredictionGroup(
                    id: "group-a",
                    nameArabic: "أ",
                    nameEnglish: "A",
                    teams: [team(id: "team-a"), team(id: "team-b")],
                    qualifyingPositions: 1
                )
            ]
        )
    }

    private func team(id: String) -> Team {
        Team(
            id: id,
            nameArabic: id,
            nameEnglish: id,
            monogram: "TM",
            colorHex: "006C75"
        )
    }
}

enum PredictionPayloads {
    static let gameListText = "{\"data\":[\(gameJSON)]}"
    static let gameList = Data(gameListText.utf8)

    static let entryResponseText =
        """
        {"data":{"gameId":"prediction-1","rankings":[{"groupId":"group-a","orderedTeamIds":["team-two","team-one","team-three","team-four"]}],"updatedAt":"2026-08-07T12:00:00Z"}}
        """
    static let entryResponse = Data(entryResponseText.utf8)

    static let gameJSON =
        """
        {
          "id":"prediction-1",
          "title":{"ar":"توقع المجموعة","en":"Group prediction"},
          "summary":{"ar":"رتب الفرق","en":"Rank the teams"},
          "lockAt":"2030-01-01T12:00:00Z",
          "state":"OPEN",
          "rulesURL":"https://rules.example.test/predictions/prediction-1",
          "groups":[{
            "id":"group-a",
            "name":{"ar":"المجموعة أ","en":"Group A"},
            "teams":[
              {"id":"team-one","name":{"ar":"الأول","en":"One"},"monogram":"ONE","accentColorHex":"006C75"},
              {"id":"team-two","name":{"ar":"الثاني","en":"Two"},"monogram":"TWO","accentColorHex":"9B5B00"},
              {"id":"team-three","name":{"ar":"الثالث","en":"Three"},"monogram":"THR","accentColorHex":"4E65D6"},
              {"id":"team-four","name":{"ar":"الرابع","en":"Four"},"monogram":"FOR","accentColorHex":"9B59B6"}
            ],
            "qualifyingPositions":2
          }]
        }
        """
}
