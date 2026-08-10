import Foundation
import XCTest
@testable import SportsHub

final class VideoDetailEditorialContractTests: XCTestCase {
    func testValidDetailMapsEditorialContextAndPreservesRelatedOrderAndRights() throws {
        let result = try decode(related: [
            videoObject(id: "related-region", reason: "REGION_BLOCKED"),
            videoObject(id: "related-entitlement", reason: "ENTITLEMENT_REQUIRED")
        ])

        XCTAssertEqual(result.video.id, "current-video")
        XCTAssertEqual(result.publisher(in: .arabic), "ناشر تجريبي")
        XCTAssertEqual(result.publisher(in: .english), "Demo publisher")
        XCTAssertEqual(result.program?.id, "program-one")
        XCTAssertEqual(result.program?.title(in: .english), "Program One")
        XCTAssertEqual(
            result.relatedVideos.map(\.id),
            ["related-region", "related-entitlement"]
        )
        XCTAssertEqual(
            result.relatedVideos.map(\.availabilityReason),
            [.regionBlocked, .entitlementRequired]
        )
        XCTAssertTrue(result.relatedVideos.allSatisfy { !$0.isPlayable })
    }

    func testDetailResponseMustMatchRequestedPathIdentifier() {
        assertContractViolation(
            expectedVideoID: "different-video",
            related: [],
            field: "data.id"
        )
    }

    func testRelatedVideosRejectDuplicateAndSelfReferences() {
        assertContractViolation(
            related: [videoObject(id: "duplicate"), videoObject(id: "duplicate")],
            field: "data.relatedVideos.id"
        )
        assertContractViolation(
            related: [videoObject(id: "current-video")],
            field: "data.relatedVideos.id"
        )
    }

    func testRelatedVideosAreBounded() {
        assertContractViolation(
            related: (0...10).map { videoObject(id: "related-\($0)") },
            field: "data.relatedVideos"
        )
    }

    func testExpandableDescriptionUsesAnExplicitStableThreshold() {
        XCTAssertFalse(
            VideoDescriptionPresentation.isExpandable(
                String(repeating: "a", count: VideoDescriptionPresentation.collapseThreshold)
            )
        )
        XCTAssertTrue(
            VideoDescriptionPresentation.isExpandable(
                String(repeating: "a", count: VideoDescriptionPresentation.collapseThreshold + 1)
            )
        )
        XCTAssertEqual(VideoDescriptionPresentation.collapsedLineLimit, 4)
        XCTAssertNil(
            VideoDescriptionPresentation.lineLimit(
                for: String(repeating: "a", count: 80),
                isExpanded: false
            ),
            "Short copy must never be permanently clipped at large Dynamic Type sizes"
        )
        XCTAssertEqual(
            VideoDescriptionPresentation.lineLimit(
                for: String(repeating: "a", count: 161),
                isExpanded: false
            ),
            4
        )
        XCTAssertNil(
            VideoDescriptionPresentation.lineLimit(
                for: String(repeating: "a", count: 161),
                isExpanded: true
            )
        )
    }

    private func assertContractViolation(
        expectedVideoID: String = "current-video",
        related: [[String: Any]],
        field: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try decode(expectedVideoID: expectedVideoID, related: related),
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
        expectedVideoID: String = "current-video",
        related: [[String: Any]]
    ) throws -> SportsVideoDetails {
        let payload = try JSONSerialization.data(withJSONObject: [
            "data": [
                "id": "current-video",
                "type": "ORIGINAL",
                "title": ["ar": "فيديو تجريبي", "en": "Demo video"],
                "description": ["ar": "وصف تجريبي", "en": "Demo description"],
                "durationSeconds": 420,
                "isPlayable": false,
                "availabilityReason": "NOT_STARTED",
                "publishedAt": "2026-08-05T13:00:00Z",
                "audioLanguages": ["ar", "en"],
                "subtitleLanguages": ["ar"],
                "publisher": ["ar": "ناشر تجريبي", "en": "Demo publisher"],
                "program": [
                    "id": "program-one",
                    "title": ["ar": "البرنامج الأول", "en": "Program One"]
                ],
                "relatedVideos": related
            ]
        ])
        let response = try APIJSON.makeDecoder().decode(
            VideoDetailResponseDTO.self,
            from: payload
        )
        return try response.data.domain(expectedVideoID: expectedVideoID)
    }

    private func videoObject(
        id: String,
        reason: String = "NOT_STARTED"
    ) -> [String: Any] {
        [
            "id": id,
            "type": "HIGHLIGHT",
            "title": ["ar": "عنوان \(id)", "en": "Title \(id)"],
            "description": ["ar": "وصف", "en": "Description"],
            "durationSeconds": 300,
            "isPlayable": false,
            "availabilityReason": reason
        ]
    }
}
