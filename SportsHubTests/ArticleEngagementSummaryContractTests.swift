import XCTest
@testable import SportsHub

final class ArticleEngagementSummaryContractTests: XCTestCase {
    func testLegacySavedArticleWithoutEngagementKeepsSummaryUnavailable() throws {
        let article = try JSONDecoder().decode(
            Article.self,
            from: savedArticleJSON(engagement: nil)
        )

        XCTAssertNil(article.engagement)
        let encoded = try JSONEncoder().encode(article)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertNil(object["engagement"])
    }

    func testLegacyAPIPayloadWithoutEngagementKeepsSummaryUnavailable() throws {
        let article = try decodeDTO(engagement: nil).domain(field: "article")

        XCTAssertNil(article.engagement)
    }

    func testValidEngagementMapsExactPublicCounts() throws {
        let article = try decodeDTO(
            engagement: "\"engagement\": {\"totalReactions\": 202, \"publishedComments\": 3},"
        ).domain(field: "article")

        XCTAssertEqual(article.engagement?.totalReactions, 202)
        XCTAssertEqual(article.engagement?.publishedComments, 3)
    }

    func testInvalidWireCountsFailClosedWithExactField() throws {
        let cases = [
            (
                "\"engagement\": {\"totalReactions\": -1, \"publishedComments\": 3},",
                "article.engagement.totalReactions"
            ),
            (
                "\"engagement\": {\"totalReactions\": 2, \"publishedComments\": 2000000001},",
                "article.engagement.publishedComments"
            )
        ]

        for (engagement, field) in cases {
            let dto = try decodeDTO(engagement: engagement)
            XCTAssertThrowsError(try dto.domain(field: "article")) {
                XCTAssertEqual(
                    $0 as? SportsDataError,
                    .contractViolation(field: field)
                )
            }
        }
    }

    func testCorruptPersistedEngagementIsRejected() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                Article.self,
                from: savedArticleJSON(
                    engagement: "\"engagement\": {\"totalReactions\": 2, \"publishedComments\": -1},"
                )
            )
        ) {
            guard case DecodingError.dataCorrupted(_) = $0 else {
                return XCTFail("Expected corrupt persisted counts to fail decoding")
            }
        }
    }

    private func decodeDTO(engagement: String?) throws -> ArticleDTO {
        let engagement = engagement ?? ""
        let data = Data(
            """
            {
              "id": "article-engagement",
              "title": {"ar": "عنوان", "en": "Title"},
              "summary": {"ar": "ملخص", "en": "Summary"},
              "source": "Licensed Desk",
              "publishedAt": "2026-08-08T10:00:00Z",
              "category": "ANALYSIS",
              "format": "STORY",
              \(engagement)
              "correctionStatus": "ORIGINAL"
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArticleDTO.self, from: data)
    }

    private func savedArticleJSON(engagement: String?) -> Data {
        let engagement = engagement ?? ""
        return Data(
            """
            {
              "id": "saved-engagement",
              "titleArabic": "عنوان",
              "titleEnglish": "Title",
              "summaryArabic": "ملخص",
              "summaryEnglish": "Summary",
              "source": "Desk",
              "publishedAt": 0,
              "categoryKey": "category.analysis",
              "format": "story",
              \(engagement)
              "isCorrected": false
            }
            """.utf8
        )
    }
}
