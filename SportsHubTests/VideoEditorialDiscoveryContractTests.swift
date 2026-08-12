import Foundation
import XCTest
@testable import SportsHub

final class VideoEditorialDiscoveryContractTests: XCTestCase {
    func testEmptyResponseIsValidOnlyWithoutEditorialReferences() throws {
        let result = try decode(items: [], featured: nil, trending: [])

        XCTAssertEqual(result, .empty)
    }

    func testValidResponseMapsItemsPlacementAndSportsExactly() throws {
        let result = try decode(
            items: [("hero", "FOOTBALL"), ("trend-two", "ESPORTS"), ("trend-one", "BASKETBALL")],
            featured: "hero",
            trending: ["trend-one", "trend-two"]
        )

        XCTAssertEqual(result.items.map(\.id), ["hero", "trend-two", "trend-one"])
        XCTAssertEqual(result.items.map(\.sport), [.football, .esports, .basketball])
        XCTAssertEqual(result.featuredVideoID, "hero")
        XCTAssertEqual(result.trendingVideoIDs, ["trend-one", "trend-two"])
    }

    func testDuplicateItemIdentifiersFailClosed() {
        assertContractViolation(
            items: [("duplicate", "FOOTBALL"), ("duplicate", "ESPORTS")],
            featured: nil,
            trending: [],
            field: "data.items.id"
        )
    }

    func testDanglingFeaturedIdentifierFailsClosed() {
        assertContractViolation(
            items: [("one", "FOOTBALL")],
            featured: "missing",
            trending: [],
            field: "data.featuredVideoId"
        )
    }

    func testDuplicateOrDanglingTrendingIdentifiersFailClosed() {
        assertContractViolation(
            items: [("one", "FOOTBALL")],
            featured: nil,
            trending: ["one", "one"],
            field: "data.trendingVideoIds"
        )
        assertContractViolation(
            items: [("one", "FOOTBALL")],
            featured: nil,
            trending: ["missing"],
            field: "data.trendingVideoIds"
        )
    }

    func testFeaturedAndTrendingSurfacesMustBeDisjoint() {
        assertContractViolation(
            items: [("one", "FOOTBALL")],
            featured: "one",
            trending: ["one"],
            field: "data.featuredVideoId"
        )
    }

    func testTrendingListIsBounded() {
        let items = (0...10).map { ("video-\($0)", "FOOTBALL") }
        assertContractViolation(
            items: items,
            featured: nil,
            trending: items.map { $0.0 },
            field: "data.trendingVideoIds"
        )
    }

    func testItemListIsBounded() {
        let items = (0...100).map { ("video-\($0)", "FOOTBALL") }
        assertContractViolation(
            items: items,
            featured: nil,
            trending: [],
            field: "data.items"
        )
    }

    private func assertContractViolation(
        items: [(String, String)],
        featured: String?,
        trending: [String],
        field: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try decode(items: items, featured: featured, trending: trending),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: field),
                file: file,
                line: line
            )
        }
    }

    private func decode(
        items: [(String, String)],
        featured: String?,
        trending: [String]
    ) throws -> VideoDiscoveryFeed {
        let itemObjects = items.map { id, sport in
            [
                "video": videoObject(id: id),
                "sport": sport
            ] as [String: Any]
        }
        let payload = try JSONSerialization.data(withJSONObject: [
            "data": [
                "items": itemObjects,
                "featuredVideoId": featured.map { $0 as Any } ?? NSNull(),
                "trendingVideoIds": trending
            ]
        ])
        return try JSONDecoder().decode(VideoDiscoveryResponseDTO.self, from: payload).domain()
    }

    private func videoObject(id: String) -> [String: Any] {
        [
            "id": id,
            "type": "ORIGINAL",
            "title": ["ar": "عنوان \(id)", "en": "Title \(id)"],
            "description": ["ar": "وصف", "en": "Description"],
            "durationSeconds": 300,
            "isPlayable": false,
            "availabilityReason": "NOT_STARTED"
        ]
    }
}
