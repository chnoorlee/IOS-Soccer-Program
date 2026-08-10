import XCTest
@testable import SportsHub

final class TransferCenterContractTests: XCTestCase {
    func testFiltersMapOnlyExplicitStatuses() {
        XCTAssertNil(TransferCenterFilter.all.status)
        XCTAssertEqual(TransferCenterFilter.completed.status, .completed)
        XCTAssertEqual(TransferCenterFilter.agreed.status, .agreed)
        XCTAssertEqual(TransferCenterFilter.rumored.status, .rumored)
    }

    func testFirstPageAndOlderPageAppendInProviderOrder() throws {
        var state = TransferCenterFeedState()
        let first = TransferPage(
            transfers: [
                transfer(id: "a", day: 4, status: .completed),
                transfer(id: "b", day: 3, status: .completed)
            ],
            nextCursor: "page-2",
            hasMore: true
        )
        let second = TransferPage(
            transfers: [transfer(id: "c", day: 2, status: .completed)],
            nextCursor: nil,
            hasMore: false
        )

        try state.replace(with: first, expectedStatus: .completed)
        try state.append(second, requestedCursor: "page-2", expectedStatus: .completed)

        XCTAssertEqual(state.transfers.map(\.id), ["a", "b", "c"])
        XCTAssertFalse(state.hasMore)
        XCTAssertNil(state.nextCursor)
        XCTAssertEqual(state.loadedCursors, ["page-2"])
    }

    func testPageRejectsDuplicateIDsAndStatusMismatch() {
        var state = TransferCenterFeedState()
        let duplicate = transfer(id: "same", day: 4, status: .completed)
        XCTAssertThrowsError(try state.replace(
            with: TransferPage(
                transfers: [duplicate, duplicate],
                nextCursor: nil,
                hasMore: false
            ),
            expectedStatus: .completed
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.id"))
        }

        XCTAssertThrowsError(try state.replace(
            with: TransferPage(
                transfers: [transfer(id: "rumor", day: 3, status: .rumored)],
                nextCursor: nil,
                hasMore: false
            ),
            expectedStatus: .completed
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.status"))
        }
    }

    func testPageRejectsMissingOrIdenticalTeamRoute() {
        var state = TransferCenterFeedState()
        let noRoute = PlayerTransfer(
            id: "no-route",
            player: player,
            fromTeam: nil,
            toTeam: nil,
            transferDate: date(day: 4),
            status: .completed
        )
        XCTAssertThrowsError(try state.replace(
            with: TransferPage(transfers: [noRoute], nextCursor: nil, hasMore: false),
            expectedStatus: nil
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.teams"))
        }

        let sameRoute = PlayerTransfer(
            id: "same-route",
            player: player,
            fromTeam: origin,
            toTeam: origin,
            transferDate: date(day: 4),
            status: .completed
        )
        XCTAssertThrowsError(try state.replace(
            with: TransferPage(transfers: [sameRoute], nextCursor: nil, hasMore: false),
            expectedStatus: nil
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.teams"))
        }
    }

    func testPageRejectsOrderAndCursorContradictions() {
        var state = TransferCenterFeedState()
        XCTAssertThrowsError(try state.replace(
            with: TransferPage(
                transfers: [
                    transfer(id: "older", day: 2, status: .completed),
                    transfer(id: "newer", day: 4, status: .completed)
                ],
                nextCursor: nil,
                hasMore: false
            ),
            expectedStatus: nil
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.order"))
        }

        XCTAssertThrowsError(try state.replace(
            with: TransferPage(transfers: [], nextCursor: "next", hasMore: true),
            expectedStatus: nil
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "page.nextCursor"))
        }

        XCTAssertThrowsError(try state.replace(
            with: TransferPage(
                transfers: [transfer(id: "one", day: 4, status: .completed)],
                nextCursor: "unexpected",
                hasMore: false
            ),
            expectedStatus: nil
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "page.nextCursor"))
        }
    }

    func testEqualDatesUseAscendingIDsAndCursorIsNormalized() throws {
        var state = TransferCenterFeedState()
        let sharedDate = date(day: 4)
        let first = PlayerTransfer(
            id: "a",
            player: player,
            fromTeam: origin,
            toTeam: destination,
            transferDate: sharedDate,
            status: .completed
        )
        let second = PlayerTransfer(
            id: "b",
            player: player,
            fromTeam: origin,
            toTeam: destination,
            transferDate: sharedDate,
            status: .completed
        )

        try state.replace(
            with: TransferPage(
                transfers: [first, second],
                nextCursor: "  page-2  ",
                hasMore: true
            ),
            expectedStatus: .completed
        )
        XCTAssertEqual(state.nextCursor, "page-2")

        XCTAssertThrowsError(try state.replace(
            with: TransferPage(
                transfers: [second, first],
                nextCursor: nil,
                hasMore: false
            ),
            expectedStatus: .completed
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.order"))
        }
    }

    func testPageRejectsOversizedPayloadAndUnsafeCursor() {
        var state = TransferCenterFeedState()
        let oversized = (0...TransferCenterContract.pageSize).map { index in
            transfer(id: "transfer-\(index)", day: 100 - index, status: .completed)
        }
        XCTAssertThrowsError(try state.replace(
            with: TransferPage(transfers: oversized, nextCursor: nil, hasMore: false),
            expectedStatus: .completed
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data"))
        }

        XCTAssertThrowsError(try state.replace(
            with: TransferPage(
                transfers: [transfer(id: "one", day: 4, status: .completed)],
                nextCursor: "page 2",
                hasMore: true
            ),
            expectedStatus: .completed
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "page.nextCursor"))
        }
    }

    func testAppendRejectsDuplicateTransferAndCursorLoop() throws {
        var state = TransferCenterFeedState()
        let firstTransfer = transfer(id: "first", day: 4, status: .completed)
        try state.replace(
            with: TransferPage(
                transfers: [firstTransfer],
                nextCursor: "page-2",
                hasMore: true
            ),
            expectedStatus: nil
        )

        XCTAssertThrowsError(try state.append(
            TransferPage(transfers: [firstTransfer], nextCursor: nil, hasMore: false),
            requestedCursor: "page-2",
            expectedStatus: nil
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data.id"))
        }

        XCTAssertThrowsError(try state.append(
            TransferPage(
                transfers: [transfer(id: "second", day: 3, status: .completed)],
                nextCursor: "page-2",
                hasMore: true
            ),
            requestedCursor: "page-2",
            expectedStatus: nil
        )) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "page.nextCursor"))
        }
    }

    private var player: PlayerProfile {
        PlayerProfile(id: "player-1", name: "Demo Player", position: "Forward")
    }

    private var origin: Team {
        Team(
            id: "origin",
            nameArabic: "الفريق السابق",
            nameEnglish: "Origin",
            monogram: "ORG",
            colorHex: "006C75"
        )
    }

    private var destination: Team {
        Team(
            id: "destination",
            nameArabic: "الفريق الجديد",
            nameEnglish: "Destination",
            monogram: "DST",
            colorHex: "B87912"
        )
    }

    private func transfer(
        id: String,
        day: Int,
        status: TransferStatus
    ) -> PlayerTransfer {
        PlayerTransfer(
            id: id,
            player: player,
            fromTeam: origin,
            toTeam: destination,
            transferDate: date(day: day),
            status: status
        )
    }

    private func date(day: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day * 86_400))
    }
}
