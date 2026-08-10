import SwiftUI

enum EntityEditorialContentScope {
    case competition
    case player

    var identifier: String {
        switch self {
        case .competition: "competition.content"
        case .player: "player.content"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .competition: "competition.latestContent"
        case .player: "player.latestContent"
        }
    }

    var newsKey: LocalizedStringKey {
        switch self {
        case .competition: "competition.relatedNews"
        case .player: "player.relatedNews"
        }
    }

    var videosKey: LocalizedStringKey {
        switch self {
        case .competition: "competition.relatedVideos"
        case .player: "player.relatedVideos"
        }
    }

    var emptyNewsKey: LocalizedStringKey {
        switch self {
        case .competition: "competition.noRelatedNews"
        case .player: "player.noRelatedNews"
        }
    }

    var emptyVideosKey: LocalizedStringKey {
        switch self {
        case .competition: "competition.noRelatedVideos"
        case .player: "player.noRelatedVideos"
        }
    }
}

/// A provider-scoped editorial desk. Association belongs to the API contract;
/// this view deliberately performs no title, team, or statistics matching.
struct EntityEditorialContentSection: View {
    let scope: EntityEditorialContentScope
    let articles: [Article]?
    let videos: [SportsVideo]?
    let freshness: PublicContentFreshness?
    let loadFailed: Bool
    let isLoading: Bool
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: scope.titleKey)

            if let freshness {
                PublicContentStatusView(
                    freshness: freshness,
                    identifier: "\(scope.identifier).freshness"
                )
            }

            if articles == nil, videos == nil {
                LoadStateView(
                    state: loadFailed ? .error : (isLoading ? .loading : .empty),
                    retry: loadFailed ? retry : nil
                )
                .accessibilityIdentifier(
                    loadFailed ? "\(scope.identifier).error" : "\(scope.identifier).loading"
                )
            } else {
                editorialLane(
                    title: scope.newsKey,
                    systemImage: "newspaper.fill",
                    color: AppTheme.accent,
                    identifier: "\(scope.identifier).news"
                ) {
                    articleContent
                }

                editorialLane(
                    title: scope.videosKey,
                    systemImage: "play.rectangle.fill",
                    color: AppTheme.warm,
                    identifier: "\(scope.identifier).videos"
                ) {
                    videoContent
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(scope.identifier)
    }

    @ViewBuilder
    private var articleContent: some View {
        if let articles, !articles.isEmpty {
            ForEach(articles) { article in
                NavigationLink {
                    ArticleDetailView(article: article)
                } label: {
                    ArticleCard(article: article)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(scope.identifier).article.\(article.id)")
            }
        } else {
            emptyLane(
                title: scope.emptyNewsKey,
                systemImage: "newspaper",
                identifier: "\(scope.identifier).news.empty"
            )
        }
    }

    @ViewBuilder
    private var videoContent: some View {
        if let videos, !videos.isEmpty {
            ForEach(videos) { video in
                NavigationLink {
                    VideoDetailView(video: video)
                } label: {
                    VideoCard(video: video)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(scope.identifier).video.\(video.id)")
            }
        } else {
            emptyLane(
                title: scope.emptyVideosKey,
                systemImage: "play.slash",
                identifier: "\(scope.identifier).videos.empty"
            )
        }
    }

    private func editorialLane<Content: View>(
        title: LocalizedStringKey,
        systemImage: String,
        color: Color,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(color)
                    .frame(width: 5, height: 30)
                    .accessibilityHidden(true)
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(color)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(minHeight: 44)

            content()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func emptyLane(
        title: LocalizedStringKey,
        systemImage: String,
        identifier: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 14)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
    }
}
