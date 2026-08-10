import Foundation
import SwiftUI

struct ArticleDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let articleID: String
    let preview: Article?

    @State private var details: ArticleDetails?
    @State private var loadError: SportsDataError?
    @State private var freshness: PublicContentFreshness?
    @State private var loadRequestID: UUID?
    @State private var isFavorite = false
    @State private var isLoadingFavorite = true
    @State private var isRequestingFavorite = false
    @State private var favoriteFailure: ArticleFavoriteFailure?
    @State private var favoriteRequestID: UUID?
    @State private var favoriteStateRequestID: UUID?
    @AccessibilityFocusState private var freshnessFocused: Bool
    @AccessibilityFocusState private var favoriteErrorFocused: Bool

    init(article: Article) {
        articleID = article.id
        preview = article
    }

    init(articleID: String, preview: Article? = nil) {
        self.articleID = articleID
        self.preview = preview
    }

    var body: some View {
        Group {
            if let details {
                articleContent(details)
            } else if loadError == .contentWithdrawn {
                ScrollView {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "article.withdrawn",
                            systemImage: "doc.badge.ellipsis",
                            description: Text("article.withdrawnBody")
                        )
                        favoriteCard
                    }
                    .padding(16)
                }
            } else if loadError != nil {
                LoadStateView(state: .error) {
                    Task { await load(announceFreshness: true) }
                }
            } else {
                LoadStateView(state: .loading)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("explore.news")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let article = details?.article ?? preview {
                    SportsShareButton(
                        route: .article(article.id),
                        fallbackText: article.title(in: appModel.language),
                        accessibilityHint: "accessibility.sharesArticle"
                    )
                }
            }
        }
        .task(id: articleID) {
            await load()
            await loadFavoriteState()
        }
        .task(id: favoriteRequestID) {
            guard favoriteRequestID != nil else { return }
            await updateFavorite()
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationStateDidChange)) { _ in
            favoriteStateRequestID = nil
            favoriteRequestID = nil
            isFavorite = false
            isLoadingFavorite = true
            favoriteFailure = nil
            Task { await loadFavoriteState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .articleFavoritesDidChange)) {
            notification in
            let changedArticleID = notification.object as? String
            guard changedArticleID == nil || changedArticleID == articleID,
                  favoriteRequestID == nil else {
                return
            }
            favoriteStateRequestID = nil
            Task { await loadFavoriteState() }
        }
        .onChange(of: favoriteFailure) { _, failure in
            guard failure != nil else { return }
            favoriteErrorFocused = false
            Task { @MainActor in
                await Task.yield()
                favoriteErrorFocused = true
            }
        }
    }

    private func articleContent(_ details: ArticleDetails) -> some View {
        let article = details.article
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let freshness {
                    PublicContentStatusView(
                        freshness: freshness,
                        identifier: "article"
                    )
                    .accessibilityFocused($freshnessFocused)
                }

                articleStatusRow(article)

                Text(article.title(in: appModel.language))
                    .font(.largeTitle.weight(.black))
                    .multilineTextAlignment(.leading)
                    .accessibilityAddTraits(.isHeader)

                ViewThatFits(in: .horizontal) {
                    metadata(article)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.source)
                        Text(article.publishedAt, style: .relative)
                    }
                    .font(.subheadline)
                }

                if article.format == .visualBrief, article.heroMedia == nil {
                    ArticleVisualBriefHero()
                } else {
                    ArticleHeroMediaView(article: article, presentation: .detail)
                }

                Text(article.summary(in: appModel.language))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.leading)

                if let visualBrief = details.visualBrief {
                    ArticleVisualBriefView(brief: visualBrief)
                }

                favoriteCard

                Divider()

                Text(details.body(in: appModel.language))
                    .font(.body)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)

                if article.isCorrected {
                    Text(String(format: NSLocalizedString("article.revisionFormat", comment: ""), details.revision))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sportsCard()
                }

                Divider()

                ArticleCommunitySection(articleID: articleID)
            }
            .padding(16)
        }
        .refreshable { await load(announceFreshness: true) }
        .accessibilityIdentifier("article.detail")
    }

    private var favoriteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                guard favoriteRequestID == nil else { return }
                favoriteRequestID = UUID()
            } label: {
                if isLoadingFavorite {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("article.loadingSavedState")
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                } else if isRequestingFavorite {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("article.updatingSaved")
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                } else if isFavorite {
                    Label("article.removeFromSaved", systemImage: "bookmark.slash.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    Label("article.saveArticle", systemImage: "bookmark.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .buttonStyle(.bordered)
            .disabled(
                isLoadingFavorite
                    || isRequestingFavorite
                    || (loadError == .contentWithdrawn && !isFavorite)
            )
            .accessibilityIdentifier("article.favorite")
            .accessibilityHint(Text("article.favoriteHint"))

            if loadError == .contentWithdrawn, !isFavorite, !isLoadingFavorite {
                Label("article.withdrawnCannotSave", systemImage: "bookmark.slash.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }

            if let favoriteFailure {
                Label(
                    LocalizedStringKey(favoriteFailure.localizationKey),
                    systemImage: favoriteFailure.systemImage
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
                .accessibilityFocused($favoriteErrorFocused)
                .accessibilityIdentifier("article.favorite.error")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .contain)
    }

    private func metadata(_ article: Article) -> some View {
        HStack(spacing: 8) {
            Text(article.source)
                .fontWeight(.semibold)
            Text("•")
                .accessibilityHidden(true)
            Text(article.publishedAt, style: .relative)
                .foregroundStyle(AppTheme.muted)
        }
        .font(.subheadline)
    }

    private func articleStatusRow(_ article: Article) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                articleStatusBadges(article)
            }
            VStack(alignment: .leading, spacing: 8) {
                articleStatusBadges(article)
            }
        }
    }

    @ViewBuilder
    private func articleStatusBadges(_ article: Article) -> some View {
        StatusPill(text: LocalizedStringKey(article.categoryKey), color: AppTheme.accent)
        if article.format == .visualBrief {
            ArticleFormatLabel(format: article.format)
        }
        if article.isCorrected {
            Label("article.corrected", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
        }
    }

    @MainActor
    private func load(announceFreshness: Bool = false) async {
        let requestID = UUID()
        loadRequestID = requestID
        loadError = nil
        do {
            let loadedDetails = try await appModel.dataProvider.articleDetails(id: articleID)
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            details = loadedDetails
        } catch let error as SportsDataError {
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            loadError = error
            if error == .contentWithdrawn {
                details = nil
            }
        } catch {
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            loadError = .serverUnavailable
        }
        let updated = await appModel.publicContentFreshness(
            for: .article(id: articleID)
        )
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshness = updated
        guard announceFreshness || updated?.requiresAttention == true else { return }
        freshnessFocused = false
        await Task.yield()
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshnessFocused = updated != nil
    }

    @MainActor
    private func loadFavoriteState() async {
        let requestID = UUID()
        favoriteStateRequestID = requestID
        isLoadingFavorite = true
        favoriteFailure = nil
        do {
            let state = try await appModel.dataProvider.articleFavorite(articleID: articleID)
            guard favoriteStateRequestID == requestID, !Task.isCancelled else { return }
            isFavorite = state.isFavorite
        } catch let error as SportsDataError {
            guard favoriteStateRequestID == requestID, !Task.isCancelled else { return }
            isFavorite = false
            favoriteFailure = ArticleFavoriteFailure(error: error)
        } catch {
            guard favoriteStateRequestID == requestID, !Task.isCancelled else { return }
            isFavorite = false
            favoriteFailure = .temporary
        }
        guard favoriteStateRequestID == requestID, !Task.isCancelled else { return }
        isLoadingFavorite = false
    }

    @MainActor
    private func updateFavorite() async {
        guard !isRequestingFavorite, !isLoadingFavorite else { return }
        isRequestingFavorite = true
        favoriteFailure = nil
        defer {
            isRequestingFavorite = false
            favoriteRequestID = nil
        }

        do {
            let state = try await appModel.dataProvider.setArticleFavorite(
                articleID: articleID,
                isFavorite: !isFavorite
            )
            guard !Task.isCancelled else { return }
            isFavorite = state.isFavorite
            NotificationCenter.default.post(
                name: .articleFavoritesDidChange,
                object: articleID
            )
        } catch let error as SportsDataError {
            guard !Task.isCancelled else { return }
            favoriteFailure = ArticleFavoriteFailure(error: error)
        } catch {
            guard !Task.isCancelled else { return }
            favoriteFailure = .temporary
        }
    }

    private enum ArticleFavoriteFailure: Hashable {
        case signInRequired
        case unavailable
        case temporary

        init(error: SportsDataError) {
            switch error {
            case .unauthorized:
                self = .signInRequired
            case .forbidden, .notFound, .contentWithdrawn:
                self = .unavailable
            default:
                self = .temporary
            }
        }

        var localizationKey: String {
            switch self {
            case .signInRequired: "article.savedSignInRequired"
            case .unavailable: "article.savedUnavailable"
            case .temporary: "article.savedTemporaryFailure"
            }
        }

        var systemImage: String {
            switch self {
            case .signInRequired: "person.crop.circle.badge.exclamationmark"
            case .unavailable: "bookmark.slash.fill"
            case .temporary: "wifi.exclamationmark"
            }
        }
    }
}
