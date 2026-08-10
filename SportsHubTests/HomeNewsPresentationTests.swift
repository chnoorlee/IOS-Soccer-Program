import XCTest
@testable import SportsHub

final class HomeNewsPresentationTests: XCTestCase {
    func testCategoriesUseStableFirstOccurrenceOrderWithoutInventingValues() {
        let source = [
            article("a", category: "category.analysis"),
            article("b", category: "category.statistics"),
            article("c", category: "category.analysis")
        ]

        let result = HomeNewsPresentation(articles: source, selectedCategoryKey: nil)

        XCTAssertEqual(
            result.categoryKeys,
            ["category.analysis", "category.statistics"]
        )
    }

    func testAllCategoriesPreservesProviderOrderAndPartitionsFirstFromRest() {
        let source = [
            article("second", category: "category.analysis"),
            article("first", category: "category.statistics"),
            article("third", category: "category.analysis")
        ]

        let result = HomeNewsPresentation(articles: source, selectedCategoryKey: nil)

        XCTAssertNil(result.selectedCategoryKey)
        XCTAssertEqual(result.articles.map(\.id), ["second", "first", "third"])
        XCTAssertEqual(result.leadingArticle?.id, "second")
        XCTAssertEqual(result.remainingArticles.map(\.id), ["first", "third"])
    }

    func testCategorySelectionUsesExactKeyAndPreservesRelativeOrder() {
        let source = [
            article("a", category: "category.analysis"),
            article("b", category: "category.statistics"),
            article("c", category: "category.analysis")
        ]

        let result = HomeNewsPresentation(
            articles: source,
            selectedCategoryKey: "category.analysis"
        )

        XCTAssertEqual(result.selectedCategoryKey, "category.analysis")
        XCTAssertEqual(result.articles.map(\.id), ["a", "c"])
    }

    func testMissingSelectionNormalizesToAllCategories() {
        let source = [article("a", category: "category.analysis")]

        let result = HomeNewsPresentation(
            articles: source,
            selectedCategoryKey: "category.transfers"
        )

        XCTAssertNil(result.selectedCategoryKey)
        XCTAssertEqual(result.articles.map(\.id), ["a"])
    }

    func testEmptySourceHasNoCategoriesOrLeadingArticle() {
        let result = HomeNewsPresentation(articles: [], selectedCategoryKey: nil)

        XCTAssertTrue(result.sourceArticles.isEmpty)
        XCTAssertTrue(result.categoryKeys.isEmpty)
        XCTAssertTrue(result.articles.isEmpty)
        XCTAssertNil(result.leadingArticle)
        XCTAssertTrue(result.remainingArticles.isEmpty)
    }

    func testSavedSourceIsPresentedAsProvidedWithoutPublicFeedInference() {
        let publicFeed = [article("public-only", category: "category.analysis")]
        let saved = [article("saved-only", category: "category.interview")]

        let result = HomeNewsPresentation(
            scope: .saved,
            allArticles: publicFeed,
            savedArticles: saved,
            selectedCategoryKey: nil
        )

        XCTAssertEqual(result.categoryKeys, ["category.interview"])
        XCTAssertEqual(result.sourceArticles.map(\.id), ["saved-only"])
        XCTAssertEqual(result.articles.map(\.id), ["saved-only"])
    }

    func testAllScopeIgnoresSavedSource() {
        let publicFeed = [article("public-only", category: "category.analysis")]
        let saved = [article("saved-only", category: "category.interview")]

        let result = HomeNewsPresentation(
            scope: .all,
            allArticles: publicFeed,
            savedArticles: saved,
            selectedCategoryKey: nil
        )

        XCTAssertEqual(result.sourceArticles.map(\.id), ["public-only"])
        XCTAssertEqual(result.articles.map(\.id), ["public-only"])
    }

    private func article(_ id: String, category: String) -> Article {
        Article(
            id: id,
            titleArabic: id,
            titleEnglish: id,
            summaryArabic: id,
            summaryEnglish: id,
            source: "Test",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            categoryKey: category,
            isCorrected: false
        )
    }
}
