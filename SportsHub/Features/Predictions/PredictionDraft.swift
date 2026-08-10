import Foundation

enum PredictionMoveDirection: Sendable {
    case up
    case down
}

struct PredictionDraft: Equatable, Sendable {
    let gameID: String
    private(set) var rankings: [PredictionGroupRanking]

    init(game: PredictionGame, entry: PredictionEntry? = nil) throws {
        gameID = game.id
        if let entry {
            guard entry.gameID == game.id else {
                throw SportsDataError.contractViolation(field: "predictionEntry.gameId")
            }
            try PredictionEntryContract.validate(entry.rankings, for: game)
            rankings = entry.rankings
        } else {
            rankings = game.groups.map {
                PredictionGroupRanking(
                    groupID: $0.id,
                    orderedTeamIDs: $0.teams.map(\.id)
                )
            }
        }
    }

    func teamIDs(in groupID: String) -> [String] {
        rankings.first(where: { $0.groupID == groupID })?.orderedTeamIDs ?? []
    }

    func position(of teamID: String, in groupID: String) -> Int? {
        guard let index = teamIDs(in: groupID).firstIndex(of: teamID) else { return nil }
        return index + 1
    }

    func canMove(
        teamID: String,
        in groupID: String,
        direction: PredictionMoveDirection
    ) -> Bool {
        guard let index = teamIDs(in: groupID).firstIndex(of: teamID) else { return false }
        switch direction {
        case .up: index > 0
        case .down: index < teamIDs(in: groupID).count - 1
        }
    }

    mutating func move(
        teamID: String,
        in groupID: String,
        direction: PredictionMoveDirection
    ) {
        guard let rankingIndex = rankings.firstIndex(where: { $0.groupID == groupID }) else {
            return
        }
        var teamIDs = rankings[rankingIndex].orderedTeamIDs
        guard let sourceIndex = teamIDs.firstIndex(of: teamID) else { return }
        let destinationIndex: Int
        switch direction {
        case .up:
            guard sourceIndex > 0 else { return }
            destinationIndex = sourceIndex - 1
        case .down:
            guard sourceIndex < teamIDs.count - 1 else { return }
            destinationIndex = sourceIndex + 1
        }
        teamIDs.swapAt(sourceIndex, destinationIndex)
        rankings[rankingIndex] = PredictionGroupRanking(
            groupID: groupID,
            orderedTeamIDs: teamIDs
        )
    }

}
