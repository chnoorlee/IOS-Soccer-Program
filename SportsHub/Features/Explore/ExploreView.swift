import Foundation
import SwiftUI
import UIKit

struct ExploreView: View {
    private enum Category: String, CaseIterable, Identifiable, Hashable {
        case news
        case videos
        case teams
        case competitions

        var id: String { rawValue }
        var key: String { "explore.\(rawValue)" }
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""
    @State private var selectedCategory: Category = .news
    @State private var selectedVideoSport: VideoSport?
    @State private var selectedVideoFilter: VideoDiscoveryFilter = .all
    @State private var articles: [Article] = []
    @State private var videoDiscovery: VideoDiscoveryFeed = .empty
    @State private var continueWatching: [ContinueWatchingItem] = []
    @State private var favoriteVideos: [SportsVideo] = []
    @State private var teams: [Team] = []
    @State private var competitions: [Competition] = []
    @State private var failedCategories: Set<Category> = []
    @State private var hasLoaded = false
    @State private var isLoading = false
    @State private var searchResults: [SearchResultItem] = []
    @State private var selectedSearchScope: SearchResultScope = .all
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var freshnessByCategory: [Category: PublicContentFreshness] = [:]
    @State private var loadRequestID: UUID?
    @State private var personalStateRequestID: UUID?
    @State private var searchRequestID: UUID?
    @AccessibilityFocusState private var freshnessFocused: Bool
    @AccessibilityFocusState private var searchErrorFocused: Bool

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var videos: [SportsVideo] {
        videoDiscovery.items.map(\.video)
    }

    private var videoPresentation: VideoEditorialDiscoveryPresentation {
        VideoEditorialDiscoveryPresentation(
            feed: videoDiscovery,
            selectedSport: selectedVideoSport,
            selectedFilter: selectedVideoFilter
        )
    }

    var body: some View {
        Group {
            if !hasLoaded && isLoading {
                LoadStateView(state: .loading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if trimmedSearchText.isEmpty {
                            discoveryTools
                            categoryGrid
                            categoryContent
                        } else {
                            searchContent
                        }
                    }
                    .padding(16)
                }
                .refreshable { await load(announceFreshness: true) }
            }
        }
        .background(AppTheme.background)
        .navigationTitle("explore.title")
        .searchable(text: $searchText, prompt: Text("explore.searchPrompt"))
        .accessibilityIdentifier("explore.screen")
        .task { await load() }
        .task(id: searchText) { await updateSearch() }
        .onReceive(NotificationCenter.default.publisher(for: .watchProgressDidChange)) { _ in
            Task { await loadPersonalVideoSections() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoFavoritesDidChange)) { _ in
            Task { await loadPersonalVideoSections() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationStateDidChange)) { _ in
            personalStateRequestID = nil
            continueWatching = []
            favoriteVideos = []
            Task { await loadPersonalVideoSections() }
        }
    }

    private var discoveryTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("explore.toolsTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            videoProgramsEntry
            transferCenterEntry
            seasonCalendarEntry
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("explore.tools")
    }

    private var videoProgramsEntry: some View {
        NavigationLink {
            VideoProgramLibraryView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.warm.opacity(0.22))
                    Image(systemName: "rectangle.stack.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.warm)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("video.programs.title")
                        .font(.headline)
                    Text("video.programs.entryBody")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.ink)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.warm)
                    .frame(width: 5)
                    .padding(.vertical, 12)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("video.programs.entryHint"))
        .accessibilityIdentifier("video.programs.entry")
    }

    private var transferCenterEntry: some View {
        NavigationLink {
            TransferCenterView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.warm.opacity(0.18))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.warm)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("transfer.center.title")
                        .font(.headline)
                    Text("transfer.center.entryBody")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.ink)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("transfer.center.entryHint"))
        .accessibilityIdentifier("explore.transferCenter")
    }

    private var seasonCalendarEntry: some View {
        NavigationLink {
            SeasonCalendarView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                    Image(systemName: "calendar.badge.clock")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("seasonCalendar.title")
                        .font(.headline)
                    Text("seasonCalendar.entryBody")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("seasonCalendar.entryHint"))
        .accessibilityIdentifier("explore.seasonCalendar")
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible()),
                count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
            ),
            spacing: 12
        ) {
            categoryTile(.news, icon: "newspaper.fill", color: AppTheme.accent)
            categoryTile(.videos, icon: "play.rectangle.fill", color: AppTheme.warm)
            categoryTile(.teams, icon: "person.3.fill", color: .indigo)
            categoryTile(.competitions, icon: "trophy.fill", color: .purple)
        }
    }

    private func categoryTile(
        _ category: Category,
        icon: String,
        color: Color
    ) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(selectedCategory == category ? .white : color)
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(category.key))
                    .font(.headline)
                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 16)
            .background(selectedCategory == category ? AppTheme.ink : AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("explore.category.\(category.rawValue)")
        .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
        .accessibilityHint(Text("accessibility.selectsCategory"))
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch selectedCategory {
        case .news:
            newsSection
        case .videos:
            videosSection
        case .teams:
            teamsSection
        case .competitions:
            competitionsSection
        }
    }

    @ViewBuilder
    private var newsSection: some View {
        contentSection(title: "explore.news", category: .news, isEmpty: articles.isEmpty) {
            ForEach(articles) { article in
                NavigationLink {
                    ArticleDetailView(article: article)
                } label: {
                    ArticleCard(article: article)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !continueWatching.isEmpty {
                personalVideoSection(title: "video.continueWatching") {
                    ForEach(continueWatching) { item in
                        NavigationLink {
                            VideoDetailView(video: item.video)
                        } label: {
                            VideoCard(video: item.video, continuation: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !favoriteVideos.isEmpty {
                personalVideoSection(title: "video.savedVideos") {
                    ForEach(favoriteVideos) { video in
                        NavigationLink {
                            VideoDetailView(video: video)
                        } label: {
                            VideoCard(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            contentSection(title: "explore.videos", category: .videos, isEmpty: videos.isEmpty) {
                if let featuredItem = videoPresentation.featuredItem {
                    NavigationLink {
                        VideoDetailView(video: featuredItem.video)
                    } label: {
                        FeaturedVideoCard(item: featuredItem)
                    }
                    .buttonStyle(.plain)
                }

                if !videoPresentation.trendingItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "video.trending")
                        ForEach(videoPresentation.trendingItems) { rankedItem in
                            NavigationLink {
                                VideoDetailView(video: rankedItem.item.video)
                            } label: {
                                TrendingVideoCard(rankedItem: rankedItem)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("video.trending")
                }

                SectionHeader(title: "video.library")
                videoSportControls(videoPresentation)
                videoFilterControls(videoPresentation)

                ForEach(videoPresentation.libraryItems) { item in
                    NavigationLink {
                        VideoDetailView(video: item.video)
                    } label: {
                        VideoCard(video: item.video)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func videoFilterControls(
        _ presentation: VideoEditorialDiscoveryPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("video.filterTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(presentation.availableFilters) { filter in
                        videoFilterButton(
                            filter,
                            selectedFilter: presentation.selectedFilter,
                            expands: true
                        )
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presentation.availableFilters) { filter in
                            videoFilterButton(
                                filter,
                                selectedFilter: presentation.selectedFilter,
                                expands: false
                            )
                        }
                    }
                }
                .accessibilityIdentifier("video.filters.scroll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.filters")
    }

    @ViewBuilder
    private func videoSportControls(
        _ presentation: VideoEditorialDiscoveryPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("video.sportTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    videoSportButton(nil, selectedSport: presentation.selectedSport, expands: true)
                    ForEach(presentation.availableSports) { sport in
                        videoSportButton(
                            sport,
                            selectedSport: presentation.selectedSport,
                            expands: true
                        )
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        videoSportButton(
                            nil,
                            selectedSport: presentation.selectedSport,
                            expands: false
                        )
                        ForEach(presentation.availableSports) { sport in
                            videoSportButton(
                                sport,
                                selectedSport: presentation.selectedSport,
                                expands: false
                            )
                        }
                    }
                }
                .accessibilityIdentifier("video.sports.scroll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.sports")
    }

    private func videoSportButton(
        _ sport: VideoSport?,
        selectedSport: VideoSport?,
        expands: Bool
    ) -> some View {
        let isSelected = sport == selectedSport
        let localizationKey = sport?.localizationKey ?? "video.sport.all"
        let systemImage = sport?.systemImage ?? "square.grid.2x2.fill"
        let identifier = sport?.rawValue ?? "all"
        return Button {
            selectedVideoSport = sport
            let normalized = VideoEditorialDiscoveryPresentation(
                feed: videoDiscovery,
                selectedSport: sport,
                selectedFilter: selectedVideoFilter
            )
            selectedVideoFilter = normalized.selectedFilter
        } label: {
            Label(
                LocalizedStringKey(localizationKey),
                systemImage: isSelected ? "checkmark.circle.fill" : systemImage
            )
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: expands ? .infinity : nil,
                minHeight: 44,
                alignment: .leading
            )
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("accessibility.filtersVideoSports"))
        .accessibilityIdentifier("video.sport.\(identifier)")
    }

    private func videoFilterButton(
        _ filter: VideoDiscoveryFilter,
        selectedFilter: VideoDiscoveryFilter,
        expands: Bool
    ) -> some View {
        let isSelected = filter == selectedFilter
        return Button {
            selectedVideoFilter = filter
        } label: {
            Label(
                LocalizedStringKey(filter.localizationKey),
                systemImage: isSelected ? "checkmark.circle.fill" : filter.systemImage
            )
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: expands ? .infinity : nil,
                minHeight: 44,
                alignment: .leading
            )
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("accessibility.filtersVideos"))
        .accessibilityIdentifier("video.filter.\(filter.rawValue)")
    }

    private func personalVideoSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            content()
        }
    }

    @ViewBuilder
    private var teamsSection: some View {
        contentSection(title: "explore.teams", category: .teams, isEmpty: teams.isEmpty) {
            ForEach(teams) { team in
                NavigationLink {
                    TeamDetailView(team: team)
                } label: {
                    HStack(spacing: 14) {
                        TeamBadge(team: team, size: 48)
                        Text(team.displayName(in: appModel.language))
                            .font(.headline)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(AppTheme.muted)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 48)
                    .sportsCard()
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("team.card.\(team.id)")
            }
        }
    }

    @ViewBuilder
    private var competitionsSection: some View {
        contentSection(
            title: "explore.competitions",
            category: .competitions,
            isEmpty: competitions.isEmpty
        ) {
            ForEach(competitions) { competition in
                NavigationLink {
                    CompetitionDetailView(competition: competition)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(AppTheme.warm)
                            .accessibilityHidden(true)
                        Text(competition.displayName(in: appModel.language))
                            .font(.headline)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(AppTheme.muted)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .sportsCard()
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("competition.card.\(competition.id)")
            }
        }
    }

    private func contentSection<Content: View>(
        title: String,
        category: Category,
        isEmpty: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            if let freshness = freshnessByCategory[category] {
                PublicContentStatusView(
                    freshness: freshness,
                    identifier: "explore.\(category.rawValue)"
                )
                .accessibilityFocused($freshnessFocused)
            }
            if failedCategories.contains(category), isEmpty {
                LoadStateView(state: .error) {
                    Task { await load(announceFreshness: true) }
                }
            } else if isEmpty {
                LoadStateView(state: .empty)
            } else {
                if failedCategories.contains(category), freshnessByCategory[category] == nil {
                    Label("common.refreshFailed", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.warm)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(AppTheme.warm.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityElement(children: .combine)
                }
                content()
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        let presentation = SearchResultsPresentation(
            results: searchResults,
            selectedScope: selectedSearchScope
        )
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "search.results")

            if trimmedSearchText.count < GlobalSearchContract.minimumQueryLength {
                ContentUnavailableView(
                    "search.moreCharacters",
                    systemImage: "text.magnifyingglass",
                    description: Text("search.moreCharactersBody")
                )
                .frame(minHeight: 220)
            } else if trimmedSearchText.count > GlobalSearchContract.maximumQueryLength {
                ContentUnavailableView(
                    "search.tooManyCharacters",
                    systemImage: "text.badge.xmark",
                    description: Text("search.tooManyCharactersBody")
                )
                .frame(minHeight: 220)
            } else if isSearching {
                LoadStateView(state: .loading)
            } else if searchFailed {
                LoadStateView(state: .error) {
                    Task { await performSearch(query: trimmedSearchText, debounce: false) }
                }
                .accessibilityFocused($searchErrorFocused)
            } else if searchResults.isEmpty {
                searchSummary(presentation)
                ContentUnavailableView.search(text: trimmedSearchText)
                    .frame(minHeight: 220)
            } else {
                searchSummary(presentation)
                searchScopeControls(presentation)
                ForEach(presentation.visibleResults) { result in
                    searchResultView(result)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func searchSummary(_ presentation: SearchResultsPresentation) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    searchQuerySummary
                    searchLoadedCount(presentation.loadedCount, expands: true)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 16) {
                        searchQuerySummary
                        Spacer(minLength: 8)
                        searchLoadedCount(presentation.loadedCount, expands: false)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        searchQuerySummary
                        searchLoadedCount(presentation.loadedCount, expands: true)
                    }
                }
            }
        }
        .padding(16)
        .foregroundStyle(Color.white)
        .background(
            LinearGradient(
                colors: [AppTheme.ink, AppTheme.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: searchResultsAccessibilityText(presentation.loadedCount)))
        .accessibilityIdentifier("search.summary")
    }

    private var searchQuerySummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("search.resultsFor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white)
            Text(verbatim: trimmedSearchText)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func searchLoadedCount(_ count: Int, expands: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: count.formatted())
                .font(.title.bold())
                .monospacedDigit()
            Text("search.loaded")
                .font(.caption.weight(.semibold))
        }
        .frame(
            minWidth: 72,
            maxWidth: expands ? .infinity : nil,
            minHeight: 64,
            alignment: .leading
        )
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func searchScopeControls(_ presentation: SearchResultsPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("search.filterTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(presentation.availableScopes) { scope in
                        searchScopeButton(scope, presentation: presentation, expands: true)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presentation.availableScopes) { scope in
                            searchScopeButton(scope, presentation: presentation, expands: false)
                        }
                    }
                }
                .accessibilityIdentifier("search.scopes.scroll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.scopes")
    }

    private func searchScopeButton(
        _ scope: SearchResultScope,
        presentation: SearchResultsPresentation,
        expands: Bool
    ) -> some View {
        let isSelected = scope == presentation.selectedScope
        let count = presentation.count(for: scope)
        return Button {
            selectedSearchScope = scope
        } label: {
            HStack(spacing: 8) {
                Label(
                    LocalizedStringKey(scope.localizationKey),
                    systemImage: isSelected ? "checkmark.circle.fill" : scope.systemImage
                )
                Text(verbatim: count.formatted())
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.18)
                            : AppTheme.accent.opacity(0.12)
                    )
                    .clipShape(Capsule())
            }
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: expands ? .infinity : nil,
                minHeight: 44,
                alignment: .leading
            )
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("search.scopeHint"))
        .accessibilityIdentifier("search.scope.\(scope.rawValue)")
    }

    @ViewBuilder
    private func searchResultView(_ result: SearchResultItem) -> some View {
        switch result.type {
        case .article:
            NavigationLink {
                ArticleDetailView(
                    articleID: result.entityID,
                    preview: articles.first { $0.id == result.entityID }
                )
            } label: {
                SearchResultRow(result: result, showsDisclosure: true)
            }
            .buttonStyle(.plain)
        case .video:
            NavigationLink {
                VideoDetailView(
                    videoID: result.entityID,
                    preview: videos.first { $0.id == result.entityID }
                )
            } label: {
                SearchResultRow(result: result, showsDisclosure: true)
            }
            .buttonStyle(.plain)
        case .team:
            NavigationLink {
                TeamDetailView(
                    teamID: result.entityID,
                    preview: teams.first { $0.id == result.entityID }
                )
            } label: {
                SearchResultRow(result: result, showsDisclosure: true)
            }
            .buttonStyle(.plain)
        case .player:
            NavigationLink {
                PlayerDetailView(
                    playerID: result.entityID,
                    previewName: result.title(in: appModel.language)
                )
            } label: {
                SearchResultRow(result: result, showsDisclosure: true)
            }
            .buttonStyle(.plain)
        case .competition:
            NavigationLink {
                CompetitionDetailView(
                    competition: competitions.first { $0.id == result.entityID }
                        ?? Competition(
                            id: result.entityID,
                            nameArabic: result.titleArabic,
                            nameEnglish: result.titleEnglish,
                            currentSeasonID: nil,
                            seasons: []
                        )
                )
            } label: {
                SearchResultRow(result: result, showsDisclosure: true)
            }
            .buttonStyle(.plain)
        }
    }

    @MainActor
    private func load(announceFreshness: Bool = false) async {
        let requestID = UUID()
        loadRequestID = requestID
        isLoading = true
        let provider = appModel.dataProvider
        async let articleRequest = provider.articles()
        async let videoRequest = provider.videoDiscovery()
        async let teamRequest = provider.teams()
        async let competitionRequest = provider.competitions()

        var failures = Set<Category>()
        var loadedArticles: [Article]?
        var loadedVideoDiscovery: VideoDiscoveryFeed?
        var loadedTeams: [Team]?
        var loadedCompetitions: [Competition]?
        do { loadedArticles = try await articleRequest } catch { failures.insert(.news) }
        do { loadedVideoDiscovery = try await videoRequest } catch { failures.insert(.videos) }
        do { loadedTeams = try await teamRequest } catch { failures.insert(.teams) }
        do { loadedCompetitions = try await competitionRequest } catch { failures.insert(.competitions) }
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        if let loadedArticles { articles = loadedArticles }
        if let loadedVideoDiscovery {
            let normalized = VideoEditorialDiscoveryPresentation(
                feed: loadedVideoDiscovery,
                selectedSport: selectedVideoSport,
                selectedFilter: selectedVideoFilter
            )
            selectedVideoSport = normalized.selectedSport
            selectedVideoFilter = normalized.selectedFilter
            videoDiscovery = loadedVideoDiscovery
        }
        if let loadedTeams { teams = loadedTeams }
        if let loadedCompetitions { competitions = loadedCompetitions }
        failedCategories = failures
        let newsFreshness = await appModel.publicContentFreshness(for: .articles)
        let videoFreshness = await appModel.publicContentFreshness(for: .videoDiscovery)
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshnessByCategory[.news] = newsFreshness
        freshnessByCategory[.videos] = videoFreshness
        hasLoaded = true
        isLoading = false
        let selectedFreshness = freshnessByCategory[selectedCategory]
        if announceFreshness || selectedFreshness?.requiresAttention == true {
            freshnessFocused = false
            await Task.yield()
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            freshnessFocused = selectedFreshness != nil
        }
        await loadPersonalVideoSections()
    }

    @MainActor
    private func loadPersonalVideoSections() async {
        let requestID = UUID()
        personalStateRequestID = requestID
        let provider = appModel.dataProvider
        async let progressRequest = provider.continueWatching()
        async let favoriteRequest = provider.favoriteVideos()

        let loadedContinueWatching: [ContinueWatchingItem]
        do {
            loadedContinueWatching = try await progressRequest
        } catch {
            loadedContinueWatching = []
        }
        let loadedFavoriteVideos: [SportsVideo]
        do {
            loadedFavoriteVideos = try await favoriteRequest
        } catch {
            loadedFavoriteVideos = []
        }
        guard personalStateRequestID == requestID, !Task.isCancelled else { return }
        continueWatching = loadedContinueWatching
        favoriteVideos = loadedFavoriteVideos
    }

    @MainActor
    private func updateSearch() async {
        let query = trimmedSearchText
        selectedSearchScope = .all
        guard GlobalSearchContract.validQueryLength.contains(query.count) else {
            searchRequestID = nil
            searchResults = []
            searchFailed = false
            isSearching = false
            searchErrorFocused = false
            return
        }
        await performSearch(query: query, debounce: true)
    }

    @MainActor
    private func performSearch(query: String, debounce: Bool) async {
        let requestID = UUID()
        searchRequestID = requestID
        isSearching = true
        searchFailed = false
        searchErrorFocused = false
        if debounce {
            do {
                try await Task.sleep(nanoseconds: GlobalSearchContract.debounceNanoseconds)
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              searchRequestID == requestID,
              query == trimmedSearchText else { return }

        do {
            let results = try await appModel.dataProvider.search(query: query)
            guard !Task.isCancelled,
                  searchRequestID == requestID,
                  query == trimmedSearchText else { return }
            searchResults = results
            searchFailed = false
            isSearching = false
            announceSearchResults(count: results.count, query: query)
        } catch {
            guard !Task.isCancelled,
                  searchRequestID == requestID,
                  query == trimmedSearchText else { return }
            searchResults = []
            searchFailed = true
            isSearching = false
            await Task.yield()
            guard searchRequestID == requestID, query == trimmedSearchText else { return }
            searchErrorFocused = true
        }
    }

    private func searchResultsAccessibilityText(_ count: Int) -> String {
        String(
            format: String(
                localized: "search.resultsLoadedFormat",
                locale: appModel.language.locale
            ),
            Int64(count),
            trimmedSearchText
        )
    }

    private func announceSearchResults(count: Int, query: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let message = String(
            format: String(
                localized: "search.resultsLoadedFormat",
                locale: appModel.language.locale
            ),
            Int64(count),
            query
        )
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

private struct SearchResultRow: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let result: SearchResultItem
    let showsDisclosure: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: result.type.systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 44, height: 44)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title(in: appModel.language))
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                if let subtitle = result.subtitle(in: appModel.language), !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .multilineTextAlignment(.leading)
                }
                Text(LocalizedStringKey(result.type.localizationKey))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
            if showsDisclosure {
                Image(systemName: "chevron.forward")
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 56)
        .sportsCard()
        .accessibilityIdentifier("search.result.\(result.id)")
        .accessibilityElement(children: .combine)
    }
}
