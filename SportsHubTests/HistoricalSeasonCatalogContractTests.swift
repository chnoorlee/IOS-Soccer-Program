import XCTest
@testable import SportsHub

final class HistoricalSeasonCatalogContractTests: XCTestCase {
    func testValidCatalogPreservesNewestFirstProviderOrderAndCurrentSeason() throws {
        let dto = competition(
            currentSeasonID: "season-current",
            seasons: [
                season("season-current", start: 300, end: 500, isCurrent: true),
                season("season-archive", start: 100, end: 250, isCurrent: false)
            ]
        )

        let domain = try dto.domain(field: "competition")

        XCTAssertEqual(domain.seasons.map(\.id), ["season-current", "season-archive"])
        XCTAssertEqual(domain.currentSeason?.id, "season-current")
    }

    func testCatalogRejectsDuplicateSeasonIdentifiers() {
        assertViolation(
            competition(
                currentSeasonID: "season-one",
                seasons: [
                    season("season-one", start: 300, end: 500, isCurrent: true),
                    season("season-one", start: 100, end: 250, isCurrent: false)
                ]
            ),
            field: "competition.seasons.id"
        )
    }

    func testCatalogRejectsOldestFirstOrdering() {
        assertViolation(
            competition(
                currentSeasonID: "season-current",
                seasons: [
                    season("season-archive", start: 100, end: 250, isCurrent: false),
                    season("season-current", start: 300, end: 500, isCurrent: true)
                ]
            ),
            field: "competition.seasons.order"
        )
    }

    func testEqualStartDatesRequireIdentifierAscendingTieBreak() {
        assertViolation(
            competition(
                currentSeasonID: nil,
                seasons: [
                    season("season-z", start: 100, end: 250, isCurrent: false),
                    season("season-a", start: 100, end: 200, isCurrent: false)
                ]
            ),
            field: "competition.seasons.order"
        )
    }

    func testSeasonRequiresARealDateInterval() {
        assertViolation(
            competition(
                currentSeasonID: "season-current",
                seasons: [
                    season("season-current", start: 300, end: 300, isCurrent: true)
                ]
            ),
            field: "competition.seasons[0].startDate"
        )
    }

    func testCurrentSeasonIdentifierAndFlagMustResolveToTheSameEntry() {
        assertViolation(
            competition(
                currentSeasonID: "season-current",
                seasons: [
                    season("season-current", start: 300, end: 500, isCurrent: false),
                    season("season-archive", start: 100, end: 250, isCurrent: true)
                ]
            ),
            field: "competition.currentSeasonId"
        )
    }

    func testCurrentFlagIsRejectedWhenCurrentSeasonIdentifierIsAbsent() {
        assertViolation(
            competition(
                currentSeasonID: nil,
                seasons: [
                    season("season-archive", start: 100, end: 250, isCurrent: true)
                ]
            ),
            field: "competition.currentSeasonId"
        )
    }

    func testCurrentSeasonIdentifierCannotReferenceAnOmittedCatalog() {
        assertViolation(
            competition(currentSeasonID: "season-current", seasons: []),
            field: "competition.currentSeasonId"
        )
    }

    func testCatalogIsBounded() {
        var seasons: [SeasonDTO] = []
        for index in 0...CompetitionSeasonCatalogContract.maximumSeasonCount {
            let offset = TimeInterval(index * 10)
            seasons.append(season(
                String(format: "season-%03d", index),
                start: 10_000 - offset,
                end: 10_005 - offset,
                isCurrent: index == 0
            ))
        }
        assertViolation(
            competition(currentSeasonID: "season-000", seasons: seasons),
            field: "competition.seasons"
        )
    }

    private func competition(
        currentSeasonID: String?,
        seasons: [SeasonDTO]
    ) -> CompetitionDTO {
        CompetitionDTO(
            id: "competition",
            name: LocalizedTextDTO(ar: "بطولة", en: "Competition"),
            sport: .football,
            currentSeasonId: currentSeasonID,
            seasons: seasons
        )
    }

    private func season(
        _ id: String,
        start: TimeInterval,
        end: TimeInterval,
        isCurrent: Bool
    ) -> SeasonDTO {
        SeasonDTO(
            id: id,
            name: LocalizedTextDTO(ar: id, en: id),
            startDate: Date(timeIntervalSince1970: start),
            endDate: Date(timeIntervalSince1970: end),
            isCurrent: isCurrent
        )
    }

    private func assertViolation(
        _ dto: CompetitionDTO,
        field: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try dto.domain(field: "competition"), file: file, line: line) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: field),
                file: file,
                line: line
            )
        }
    }
}
