import Foundation

enum TransferCenterFilter: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all
    case completed
    case agreed
    case rumored

    var id: String { rawValue }

    var localizationKey: String {
        "transfer.filter.\(rawValue)"
    }

    var status: TransferStatus? {
        switch self {
        case .all: nil
        case .completed: .completed
        case .agreed: .agreed
        case .rumored: .rumored
        }
    }
}

enum TransferCenterContract {
    static let pageSize = 30
}

struct TransferCenterFeedState: Equatable, Sendable {
    private(set) var transfers: [PlayerTransfer] = []
    private(set) var nextCursor: String?
    private(set) var hasMore = false
    private(set) var loadedCursors: Set<String> = []

    mutating func replace(
        with page: TransferPage,
        expectedStatus: TransferStatus?
    ) throws {
        let normalizedNextCursor = try Self.validate(
            page: page,
            expectedStatus: expectedStatus,
            maximumCount: TransferCenterContract.pageSize
        )
        transfers = page.transfers
        nextCursor = normalizedNextCursor
        hasMore = page.hasMore
        loadedCursors = []
    }

    mutating func append(
        _ page: TransferPage,
        requestedCursor: String,
        expectedStatus: TransferStatus?
    ) throws {
        guard hasMore,
              nextCursor == requestedCursor,
              !loadedCursors.contains(requestedCursor) else {
            throw SportsDataError.contractViolation(field: "page.cursor")
        }
        let normalizedNextCursor = try Self.validate(
            page: page,
            expectedStatus: expectedStatus,
            maximumCount: TransferCenterContract.pageSize
        )
        let existingIDs = Set(transfers.map(\.id))
        guard page.transfers.allSatisfy({ !existingIDs.contains($0.id) }) else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        let combined = transfers + page.transfers
        try Self.validateOrder(combined)
        guard normalizedNextCursor != requestedCursor,
              normalizedNextCursor.map({ !loadedCursors.contains($0) }) ?? true else {
            throw SportsDataError.contractViolation(field: "page.nextCursor")
        }

        transfers = combined
        loadedCursors.insert(requestedCursor)
        nextCursor = normalizedNextCursor
        hasMore = page.hasMore
    }

    private static func validate(
        page: TransferPage,
        expectedStatus: TransferStatus?,
        maximumCount: Int
    ) throws -> String? {
        guard page.transfers.count <= maximumCount else {
            throw SportsDataError.contractViolation(field: "data")
        }
        guard Set(page.transfers.map(\.id)).count == page.transfers.count else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        guard page.transfers.allSatisfy({ transfer in
            (transfer.fromTeam != nil || transfer.toTeam != nil)
                && transfer.fromTeam?.id != transfer.toTeam?.id
        }) else {
            throw SportsDataError.contractViolation(field: "data.teams")
        }
        if let expectedStatus,
           !page.transfers.allSatisfy({ $0.status == expectedStatus }) {
            throw SportsDataError.contractViolation(field: "data.status")
        }
        try validateOrder(page.transfers)
        if page.hasMore {
            guard !page.transfers.isEmpty,
                  let cursor = page.nextCursor?.trimmingCharacters(in: .whitespacesAndNewlines),
                  (1...TransferPaginationContract.maximumCursorLength).contains(cursor.count),
                  cursor.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
                  cursor.unicodeScalars.allSatisfy({
                      !CharacterSet.controlCharacters.contains($0)
                  }) else {
                throw SportsDataError.contractViolation(field: "page.nextCursor")
            }
            return cursor
        } else if page.nextCursor != nil {
            throw SportsDataError.contractViolation(field: "page.nextCursor")
        }
        return nil
    }

    private static func validateOrder(_ transfers: [PlayerTransfer]) throws {
        for (current, next) in zip(transfers, transfers.dropFirst()) {
            guard current.transferDate > next.transferDate
                    || (current.transferDate == next.transferDate && current.id < next.id) else {
                throw SportsDataError.contractViolation(field: "data.order")
            }
        }
    }
}
