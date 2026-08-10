import XCTest
@testable import SportsHub

final class ArticleVisualBriefContractTests: XCTestCase {
    func testLegacySavedArticleWithoutFormatMigratesToStory() throws {
        let data = Data(
            """
            {
              "id": "legacy-article",
              "titleArabic": "عنوان",
              "titleEnglish": "Title",
              "summaryArabic": "ملخص",
              "summaryEnglish": "Summary",
              "source": "Desk",
              "publishedAt": 0,
              "categoryKey": "category.analysis",
              "isCorrected": false
            }
            """.utf8
        )

        let article = try JSONDecoder().decode(Article.self, from: data)

        XCTAssertEqual(article.format, .story)
        let encoded = try JSONEncoder().encode(article)
        XCTAssertEqual(
            try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])["format"] as? String,
            "story"
        )
    }

    func testLegacyArticlePayloadWithoutFormatMapsToStory() throws {
        let data = Data(
            """
            {
              "id": "legacy-api-article",
              "title": {"ar": "عنوان", "en": "Title"},
              "summary": {"ar": "ملخص", "en": "Summary"},
              "source": "Desk",
              "publishedAt": "2026-08-08T10:00:00Z",
              "category": "ANALYSIS",
              "correctionStatus": "ORIGINAL"
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let article = try decoder.decode(ArticleDTO.self, from: data).domain(field: "article")

        XCTAssertEqual(article.format, .story)
    }

    func testValidVisualBriefPreservesProviderSectionAndItemOrder() throws {
        let details = try detail(
            format: .visualBrief,
            visualBrief: brief(sections: [
                section(id: "metrics", kind: .metricGrid, itemIDs: ["shots", "possession"]),
                section(id: "timeline", kind: .sequence, itemIDs: ["first", "second"])
            ])
        ).domain()

        XCTAssertEqual(details.article.format, .visualBrief)
        XCTAssertEqual(details.visualBrief?.sections.map(\.id), ["metrics", "timeline"])
        XCTAssertEqual(
            details.visualBrief?.sections.flatMap { $0.items.map(\.id) },
            ["shots", "possession", "first", "second"]
        )
    }

    func testVisualBriefFormatRequiresStructuredPayload() {
        XCTAssertThrowsError(try detail(format: .visualBrief, visualBrief: nil).domain()) {
            XCTAssertEqual($0 as? SportsDataError, .contractViolation(field: "data.visualBrief"))
        }
    }

    func testStoryRejectsUnexpectedVisualPayload() {
        XCTAssertThrowsError(
            try detail(format: .story, visualBrief: brief()).domain()
        ) {
            XCTAssertEqual($0 as? SportsDataError, .contractViolation(field: "data.visualBrief"))
        }
    }

    func testComparisonRequiresExactlyTwoItems() {
        let payload = brief(sections: [
            section(id: "comparison", kind: .comparison, itemIDs: ["one", "two", "three"])
        ])

        XCTAssertThrowsError(try detail(format: .visualBrief, visualBrief: payload).domain()) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.visualBrief.sections[0].items")
            )
        }
    }

    func testDuplicateItemIDsAcrossSectionsAreRejected() {
        let payload = brief(sections: [
            section(id: "metrics", kind: .metricGrid, itemIDs: ["shared", "two"]),
            section(id: "sequence", kind: .sequence, itemIDs: ["shared", "three"])
        ])

        XCTAssertThrowsError(try detail(format: .visualBrief, visualBrief: payload).domain()) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.visualBrief.sections.items.id")
            )
        }
    }

    func testDuplicateSectionIDsAreRejected() {
        let payload = brief(sections: [
            section(id: "duplicate", kind: .metricGrid, itemIDs: ["one", "two"]),
            section(id: "duplicate", kind: .sequence, itemIDs: ["three", "four"])
        ])

        XCTAssertThrowsError(try detail(format: .visualBrief, visualBrief: payload).domain()) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.visualBrief.sections.id")
            )
        }
    }

    func testMetricAndSequenceSectionsRejectMoreThanSixItems() {
        for kind in [ArticleVisualSectionKindDTO.metricGrid, .sequence] {
            let payload = brief(sections: [
                section(
                    id: "bounded",
                    kind: kind,
                    itemIDs: (1...7).map { "item-\($0)" }
                )
            ])

            XCTAssertThrowsError(
                try detail(format: .visualBrief, visualBrief: payload).domain()
            ) {
                XCTAssertEqual(
                    $0 as? SportsDataError,
                    .contractViolation(field: "data.visualBrief.sections[0].items")
                )
            }
        }
    }

    func testMoreThanFourSectionsAreRejected() {
        let payload = brief(sections: (1...5).map {
            section(
                id: "section-\($0)",
                kind: .metricGrid,
                itemIDs: ["item-\($0)-a", "item-\($0)-b"]
            )
        })

        XCTAssertThrowsError(try detail(format: .visualBrief, visualBrief: payload).domain()) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.visualBrief.sections")
            )
        }
    }

    func testVisualValueLengthAndControlCharactersFailClosed() {
        let oversized = item(id: "oversized", value: String(repeating: "x", count: 33))
        let oversizedMultiScalar = item(
            id: "multi-scalar",
            value: String(repeating: "👨‍👩‍👧‍👦", count: 5)
        )
        let controlled = item(id: "controlled", label: "Unsafe\u{0007}label")

        XCTAssertThrowsError(
            try detail(
                format: .visualBrief,
                visualBrief: brief(
                    sections: [section(id: "one", items: [oversized, item(id: "safe")])]
                )
            ).domain()
        ) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.visualBrief.sections[0].items[0].value")
            )
        }
        XCTAssertThrowsError(
            try detail(
                format: .visualBrief,
                visualBrief: brief(
                    sections: [
                        section(id: "one", items: [oversizedMultiScalar, item(id: "safe")])
                    ]
                )
            ).domain()
        ) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.visualBrief.sections[0].items[0].value")
            )
        }
        XCTAssertThrowsError(
            try detail(
                format: .visualBrief,
                visualBrief: brief(sections: [section(id: "one", items: [controlled, item(id: "safe")])])
            ).domain()
        ) {
            XCTAssertEqual(
                $0 as? SportsDataError,
                .contractViolation(field: "data.visualBrief.sections[0].items[0].label")
            )
        }
    }

    private func detail(
        format: ArticleFormatDTO?,
        visualBrief: ArticleVisualBriefDTO?
    ) -> ArticleDetailDataDTO {
        ArticleDetailDataDTO(
            id: "article-visual",
            title: text("Title"),
            summary: text("Summary"),
            source: "Licensed Desk",
            publishedAt: Date(timeIntervalSince1970: 1_788_000_000),
            category: .statistics,
            format: format,
            correctionStatus: .original,
            engagement: nil,
            body: text("Body"),
            revision: 1,
            visualBrief: visualBrief
        )
    }

    private func brief(
        sections: [ArticleVisualSectionDTO]? = nil
    ) -> ArticleVisualBriefDTO {
        ArticleVisualBriefDTO(
            title: text("Visual brief"),
            sourceNote: text("Synthetic test data"),
            sections: sections ?? [section(id: "metrics", itemIDs: ["one", "two"])]
        )
    }

    private func section(
        id: String,
        kind: ArticleVisualSectionKindDTO = .metricGrid,
        itemIDs: [String]
    ) -> ArticleVisualSectionDTO {
        section(id: id, kind: kind, items: itemIDs.map { item(id: $0) })
    }

    private func section(
        id: String,
        kind: ArticleVisualSectionKindDTO = .metricGrid,
        items: [ArticleVisualItemDTO]
    ) -> ArticleVisualSectionDTO {
        ArticleVisualSectionDTO(
            id: id,
            kind: kind,
            title: text("Section"),
            items: items
        )
    }

    private func item(
        id: String,
        value: String = "14",
        label: String = "Shots"
    ) -> ArticleVisualItemDTO {
        ArticleVisualItemDTO(
            id: id,
            value: text(value),
            label: text(label),
            detail: text("Supporting context")
        )
    }

    private func text(_ english: String) -> LocalizedTextDTO {
        LocalizedTextDTO(ar: "عربي", en: english)
    }
}
