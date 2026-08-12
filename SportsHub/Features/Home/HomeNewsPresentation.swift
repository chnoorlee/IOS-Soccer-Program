import Foundation

enum HomeNewsScope: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all
    case saved

    var id: String { rawValue }
    var localizationKey: String { "home.news.scope.\(rawValue)" }
}

struct HomeNewsPresentation: Equatable, Sendable {
    let sourceArticles: [Article]
    let categoryKeys: [String]
    let selectedCategoryKey: String?
    let articles: [Article]

    var leadingArticle: Article? { articles.first }
    var remainingArticles: ArraySlice<Article> { articles.dropFirst() }

    init(articles sourceArticles: [Article], selectedCategoryKey: String?) {
        self.sourceArticles = sourceArticles
        var seenCategoryKeys: Set<String> = []
        let categoryKeys = sourceArticles.compactMap { article in
            seenCategoryKeys.insert(article.categoryKey).inserted
                ? article.categoryKey
                : nil
        }
        self.categoryKeys = categoryKeys

        let effectiveCategoryKey = selectedCategoryKey.flatMap { candidate in
            categoryKeys.contains(candidate) ? candidate : nil
        }
        self.selectedCategoryKey = effectiveCategoryKey
        articles = effectiveCategoryKey.map { categoryKey in
            sourceArticles.filter { $0.categoryKey == categoryKey }
        } ?? sourceArticles
    }

    init(
        scope: HomeNewsScope,
        allArticles: [Article],
        savedArticles: [Article],
        selectedCategoryKey: String?
    ) {
        self.init(
            articles: scope == .all ? allArticles : savedArticles,
            selectedCategoryKey: selectedCategoryKey
        )
    }
}
