import XCTest
@testable import SportsHub

final class ArabicSearchContractTests: XCTestCase {
    func testNormalizerRemovesArabicMarksAndCollapsesWhitespace() {
        XCTAssertEqual(
            ArabicSearchNormalizer.normalize("  إِلـى\n  أَهْلِي  "),
            "الي اهلي"
        )
    }

    func testNormalizerDoesNotTransliterateOrConflateTaaMarbuta() {
        XCTAssertNotEqual(
            ArabicSearchNormalizer.normalize("بطولة"),
            ArabicSearchNormalizer.normalize("بطوله")
        )
        XCTAssertNotEqual(
            ArabicSearchNormalizer.normalize("الهلال"),
            ArabicSearchNormalizer.normalize("Al Hilal")
        )
    }

    func testMockMatchPriorityIsExactThenPrefixThenTitleThenSupportingCopy() {
        XCTAssertEqual(
            ArabicSearchNormalizer.matchPriority(
                query: "صقور الرياض",
                primaryValues: ["صقور الرياض"]
            ),
            0
        )
        XCTAssertEqual(
            ArabicSearchNormalizer.matchPriority(
                query: "صقور",
                primaryValues: ["صقور الرياض"]
            ),
            1
        )
        XCTAssertEqual(
            ArabicSearchNormalizer.matchPriority(
                query: "الرياض",
                primaryValues: ["صقور الرياض"]
            ),
            2
        )
        XCTAssertEqual(
            ArabicSearchNormalizer.matchPriority(
                query: "الرياض",
                primaryValues: ["خبر اليوم"],
                secondaryValues: ["ملخص صقور الرياض"]
            ),
            3
        )
    }

    func testPresentationPreservesProviderOrderAndFilteredSubsequence() {
        let article = result(.article, id: "article-1")
        let team = result(.team, id: "team-1")
        let video = result(.video, id: "video-1")
        let secondArticle = result(.article, id: "article-2")
        let providerOrder = [article, team, video, secondArticle]

        let all = SearchResultsPresentation(results: providerOrder, selectedScope: .all)
        let articles = SearchResultsPresentation(results: providerOrder, selectedScope: .article)

        XCTAssertEqual(all.visibleResults.map(\.id), providerOrder.map(\.id))
        XCTAssertEqual(articles.visibleResults.map(\.id), [article.id, secondArticle.id])
        XCTAssertEqual(all.availableScopes, [.all, .article, .video, .team])
        XCTAssertEqual(all.count(for: .article), 2)
        XCTAssertEqual(all.loadedCount, 4)
    }

    func testPresentationNormalizesUnavailableScopeToAll() {
        let providerOrder = [result(.team, id: "team-1")]
        let presentation = SearchResultsPresentation(
            results: providerOrder,
            selectedScope: .competition
        )

        XCTAssertEqual(presentation.selectedScope, .all)
        XCTAssertEqual(presentation.visibleResults, providerOrder)
    }

    func testSearchResponseRejectsDuplicateTypedEntityIdentifiers() {
        let duplicate = resultDTO(.team, id: "team-1")
        let response = SearchResponseDTO(
            data: [duplicate, duplicate],
            page: PageInfoDTO(nextCursor: nil, hasMore: false)
        )

        XCTAssertThrowsError(try response.domain()) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data.id")
            )
        }
    }

    func testSearchResponseAllowsSameEntityIdentifierAcrossDifferentTypes() throws {
        let response = SearchResponseDTO(
            data: [
                resultDTO(.article, id: "shared-1"),
                resultDTO(.team, id: "shared-1")
            ],
            page: PageInfoDTO(nextCursor: "next", hasMore: true)
        )

        XCTAssertEqual(try response.domain().map(\.id), [
            "article:shared-1",
            "team:shared-1"
        ])
    }

    func testSearchResponseRejectsOversizedOrInconsistentPages() {
        let maximumSized = SearchResponseDTO(
            data: (0..<GlobalSearchContract.maximumResultCount).map {
                resultDTO(.article, id: "bounded-\($0)")
            },
            page: PageInfoDTO(nextCursor: nil, hasMore: false)
        )
        let oversized = SearchResponseDTO(
            data: (0...GlobalSearchContract.maximumResultCount).map {
                resultDTO(.article, id: "article-\($0)")
            },
            page: PageInfoDTO(nextCursor: nil, hasMore: false)
        )
        let missingCursor = SearchResponseDTO(
            data: [resultDTO(.article, id: "article-1")],
            page: PageInfoDTO(nextCursor: nil, hasMore: true)
        )
        let unexpectedCursor = SearchResponseDTO(
            data: [resultDTO(.article, id: "article-1")],
            page: PageInfoDTO(nextCursor: "unexpected", hasMore: false)
        )

        XCTAssertEqual(try? maximumSized.domain().count, GlobalSearchContract.maximumResultCount)
        XCTAssertThrowsError(try oversized.domain()) { error in
            XCTAssertEqual(error as? SportsDataError, .contractViolation(field: "data"))
        }
        XCTAssertThrowsError(try missingCursor.domain()) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "page.nextCursor")
            )
        }
        XCTAssertThrowsError(try unexpectedCursor.domain()) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "page.nextCursor")
            )
        }
    }

    func testSearchResponseRejectsUnsafeEntityIdentifier() {
        let response = SearchResponseDTO(
            data: [resultDTO(.team, id: "../team-1")],
            page: PageInfoDTO(nextCursor: nil, hasMore: false)
        )

        XCTAssertThrowsError(try response.domain()) { error in
            XCTAssertEqual(
                error as? SportsDataError,
                .contractViolation(field: "data[0].entityId")
            )
        }
    }

    func testRecoverableRemoteFailureDoesNotBecomeUnlabelledDemoSearchResults() async {
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .networkUnavailable),
            fallback: MockSportsDataProvider()
        )

        do {
            _ = try await provider.search(query: "صقور")
            XCTFail("Search must fail closed when demo provenance cannot be displayed")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .networkUnavailable)
        }
    }

    private func result(_ type: SearchEntityType, id: String) -> SearchResultItem {
        SearchResultItem(
            type: type,
            entityID: id,
            titleArabic: id,
            titleEnglish: id,
            subtitleArabic: nil,
            subtitleEnglish: nil
        )
    }

    private func resultDTO(_ type: SearchResultTypeDTO, id: String) -> SearchResultDTO {
        SearchResultDTO(
            type: type,
            entityId: id,
            title: LocalizedTextDTO(ar: id, en: id),
            subtitle: nil
        )
    }
}
