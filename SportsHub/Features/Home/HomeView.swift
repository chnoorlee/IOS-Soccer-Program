import Foundation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var feed: HomeFeed?
    @State private var failed = false
    @State private var freshness: PublicContentFreshness?
    @State private var loadRequestID: UUID?
    @State private var followLoadRequestID: UUID?
    @State private var savedNewsRequestID: UUID?
    @State private var followsReady = false
    @State private var savedArticles: [Article]?
    @State private var savedNewsFailed = false
    @State private var selectedMatchFilter: HomeMatchFilter = .all
    @State private var newsScope: HomeNewsScope = .all
    @State private var selectedNewsCategoryKey: String?
    @State private var predictionRefreshID = UUID()
    @AccessibilityFocusState private var freshnessFocused: Bool
    @AccessibilityFocusState private var savedNewsErrorFocused: Bool

    var body: some View {
        Group {
            if let feed {
                let personalization = HomePersonalization(
                    fixtures: feed.fixtures,
                    follows: followsReady ? appModel.orderedFollows : []
                )
                let matchPresentation = HomeMatchPresentation(
                    personalization: personalization,
                    selectedFilter: selectedMatchFilter
                )
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if let freshness {
                            PublicContentStatusView(
                                freshness: freshness,
                                identifier: "home"
                            )
                            .accessibilityFocused($freshnessFocused)
                        }
                        if followsReady {
                            followedInterests(appModel.orderedFollows)
                        } else {
                            followedInterestsLoading
                        }
                        PredictionGamesSection(refreshID: predictionRefreshID)
                        if !feed.fixtures.isEmpty {
                            matchFilterControls(matchPresentation)
                        }
                        if followsReady, appModel.hasFollowedInterests {
                            relatedMatches(
                                matchPresentation.relatedFixtures,
                                filter: matchPresentation.selectedFilter
                            )
                        }
                        if !matchPresentation.generalFixtures.isEmpty {
                            importantMatches(matchPresentation.generalFixtures)
                        }
                        newsSection(allArticles: feed.articles)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    predictionRefreshID = UUID()
                    async let feedLoad: Void = load(announceFreshness: true)
                    async let savedLoad: Void = loadSavedArticles(
                        focusFailure: newsScope == .saved
                    )
                    _ = await (feedLoad, savedLoad)
                }
            } else if failed {
                LoadStateView(state: .error) {
                    Task { await load(announceFreshness: true) }
                }
            } else {
                LoadStateView(state: .loading)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("home.greeting")
        .accessibilityIdentifier("home.screen")
        .task { await load() }
        .task { await synchronizeHomeFollows() }
        .task { await loadSavedArticles() }
        .onReceive(NotificationCenter.default.publisher(for: .articleFavoritesDidChange)) { _ in
            Task {
                await loadSavedArticles(focusFailure: newsScope == .saved)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationStateDidChange)) { _ in
            appModel.clearWidgetMatchSnapshot()
            loadRequestID = nil
            followLoadRequestID = nil
            savedNewsRequestID = nil
            feed = nil
            freshness = nil
            followsReady = false
            savedArticles = nil
            savedNewsFailed = false
            newsScope = .all
            selectedNewsCategoryKey = nil
            Task {
                async let feedLoad: Void = load(announceFreshness: true)
                async let followLoad: Void = synchronizeHomeFollows()
                async let savedLoad: Void = loadSavedArticles()
                _ = await (feedLoad, followLoad, savedLoad)
            }
        }
    }

    private var followedInterestsLoading: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "home.followedInterests")
            ProgressView("home.loadingInterests")
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .sportsCard()
        }
        .accessibilityIdentifier("home.interests.loading")
    }

    @ViewBuilder
    private func followedInterests(_ follows: [SportsFollow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "home.followedInterests")

            if follows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("home.noFollowedInterests", systemImage: "star")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                    editInterestsButton(expands: true)
                }
                .sportsCard()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.interests.empty")
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    ForEach(follows) { follow in
                        followedInterestEntry(follow, compact: false)
                    }
                    editInterestsButton(expands: true)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(follows) { follow in
                            followedInterestEntry(follow, compact: true)
                        }
                        editInterestsButton(expands: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func followedInterestEntry(
        _ follow: SportsFollow,
        compact: Bool
    ) -> some View {
        if let entity = follow.entity, follow.hasMatchingEntitySnapshot {
            NavigationLink {
                destination(for: entity)
            } label: {
                interestLabel(follow, entity: entity, compact: compact)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(entity.displayName(in: appModel.language))
                    + Text(", ")
                    + Text(LocalizedStringKey(follow.type.localizationKey))
            )
            .accessibilityHint(navigationHint(for: follow.type))
            .accessibilityIdentifier(
                "home.interest.\(follow.type.rawValue).\(follow.entityID)"
            )
        } else {
            unavailableInterestLabel(follow, compact: compact)
                .accessibilityIdentifier(
                    "home.interest.\(follow.type.rawValue).\(follow.entityID)"
                )
        }
    }

    private func interestLabel(
        _ follow: SportsFollow,
        entity: FollowEntitySnapshot,
        compact: Bool
    ) -> some View {
        Group {
            if compact {
                VStack(spacing: 8) {
                    entityIcon(entity, size: 52)
                    Text(entity.displayName(in: appModel.language))
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(LocalizedStringKey(follow.type.localizationKey))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(minWidth: 100, maxWidth: 100, minHeight: 112)
            } else {
                HStack(spacing: 14) {
                    entityIcon(entity, size: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entity.displayName(in: appModel.language))
                            .font(.headline)
                        Text(LocalizedStringKey(follow.type.localizationKey))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            }
        }
        .sportsCard()
    }

    private func unavailableInterestLabel(
        _ follow: SportsFollow,
        compact: Bool
    ) -> some View {
        Group {
            if compact {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                    Text("following.unavailableInterest")
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(LocalizedStringKey(follow.type.localizationKey))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.warm)
                }
                .frame(minWidth: 100, maxWidth: 100, minHeight: 112)
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("following.unavailableInterest")
                            .font(.headline)
                        Text(LocalizedStringKey(follow.type.localizationKey))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.warm)
                        Text(follow.entityID)
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            }
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func entityIcon(_ entity: FollowEntitySnapshot, size: CGFloat) -> some View {
        switch entity {
        case let .team(team):
            TeamBadge(team: team, size: size)
        case .player:
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: size * 0.82))
                .foregroundStyle(AppTheme.accent)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        case .competition:
            Image(systemName: "trophy.fill")
                .font(.system(size: size * 0.62))
                .foregroundStyle(AppTheme.warm)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func destination(for entity: FollowEntitySnapshot) -> some View {
        switch entity {
        case let .team(team):
            TeamDetailView(team: team)
        case let .player(player):
            PlayerDetailView(player: player)
        case let .competition(competition):
            CompetitionDetailView(competition: competition)
        }
    }

    private func navigationHint(for type: FollowEntityType) -> Text {
        switch type {
        case .team: Text("accessibility.opensTeam")
        case .player: Text("accessibility.opensPlayer")
        case .competition: Text("accessibility.opensCompetition")
        }
    }

    @ViewBuilder
    private func editInterestsButton(expands: Bool) -> some View {
        if expands {
            Button {
                appModel.resetOnboarding()
            } label: {
                Label("home.editInterests", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint(Text("home.editInterestsHint"))
            .accessibilityIdentifier("home.editInterests")
        } else {
            Button {
                appModel.resetOnboarding()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 42))
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                    Text("home.editInterests")
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(minWidth: 100, maxWidth: 100, minHeight: 112)
                .sportsCard()
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint(Text("home.editInterestsHint"))
            .accessibilityIdentifier("home.editInterests")
        }
    }

    @ViewBuilder
    private func matchFilterControls(
        _ presentation: HomeMatchPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("home.matches.filterTitle")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(presentation.availableFilters) { filter in
                        matchFilterButton(
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
                            matchFilterButton(
                                filter,
                                selectedFilter: presentation.selectedFilter,
                                expands: false
                            )
                        }
                    }
                }
                .accessibilityIdentifier("home.matchFilters.scroll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.matchFilters")
    }

    private func matchFilterButton(
        _ filter: HomeMatchFilter,
        selectedFilter: HomeMatchFilter,
        expands: Bool
    ) -> some View {
        let isSelected = filter == selectedFilter
        return Button {
            selectedMatchFilter = filter
        } label: {
            Label(
                LocalizedStringKey(filter.localizationKey),
                systemImage: isSelected
                    ? "checkmark.circle.fill"
                    : matchFilterIcon(filter)
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
        .accessibilityHint(Text("home.matches.filterHint"))
        .accessibilityIdentifier("home.matchFilter.\(filter.rawValue)")
    }

    private func matchFilterIcon(_ filter: HomeMatchFilter) -> String {
        switch filter {
        case .all: "line.3.horizontal.decrease.circle"
        case .live: "dot.radiowaves.left.and.right"
        case .upcoming: "calendar.badge.clock"
        case .finished: "checkmark.seal"
        case .postponed: "clock.arrow.circlepath"
        case .cancelled: "xmark.circle"
        }
    }

    private func relatedMatches(
        _ fixtures: [HomeRelatedFixture],
        filter: HomeMatchFilter
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "home.relatedMatches")
            Text("home.relatedMatchesExplanation")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)

            if fixtures.isEmpty {
                let emptyKey: LocalizedStringKey = filter == .all
                    ? "home.noRelatedMatches"
                    : "home.matches.noRelatedForFilter"
                Label(emptyKey, systemImage: "link.badge.plus")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .sportsCard()
                    .accessibilityIdentifier("home.relatedMatches.empty")
            } else {
                fixtureCollection(
                    fixtures.map {
                        HomeFixtureItem(fixture: $0.fixture, reason: $0.reason)
                    }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.relatedMatches")
    }

    private func importantMatches(_ fixtures: [Fixture]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "home.importantMatches")
            fixtureCollection(
                fixtures.map { HomeFixtureItem(fixture: $0, reason: nil) }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.importantMatches")
    }

    @ViewBuilder
    private func fixtureCollection(_ items: [HomeFixtureItem]) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    fixtureLink(item)
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        fixtureLink(item)
                            .frame(width: 290)
                    }
                }
            }
        }
    }

    private func fixtureLink(_ item: HomeFixtureItem) -> some View {
        NavigationLink {
            MatchCenterView(fixtureID: item.fixture.id)
        } label: {
            CompactFixtureCard(fixture: item.fixture, reason: item.reason)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("match.card.\(item.fixture.id)")
    }

    private func newsSection(allArticles: [Article]) -> some View {
        let presentation = HomeNewsPresentation(
            scope: newsScope,
            allArticles: allArticles,
            savedArticles: savedArticles ?? [],
            selectedCategoryKey: selectedNewsCategoryKey
        )
        let sourceArticles = presentation.sourceArticles

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "home.latestNews")
            newsScopeControls

            if newsScope == .saved, savedNewsFailed {
                savedNewsError
            } else if newsScope == .saved, savedArticles == nil {
                ProgressView("home.news.loadingSaved")
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .sportsCard()
                    .accessibilityIdentifier("home.news.saved.loading")
            } else {
                if !sourceArticles.isEmpty {
                    newsCategoryControls(presentation)
                }
                newsArticleHierarchy(presentation)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.latestNews")
    }

    @ViewBuilder
    private var newsScopeControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(HomeNewsScope.allCases) { scope in
                    newsScopeButton(scope)
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(HomeNewsScope.allCases) { scope in
                    newsScopeButton(scope)
                }
            }
        }
    }

    private func newsScopeButton(_ scope: HomeNewsScope) -> some View {
        let isSelected = newsScope == scope
        return Button {
            newsScope = scope
            selectedNewsCategoryKey = nil
            if scope == .saved, savedNewsFailed {
                focusSavedNewsError()
            }
        } label: {
            Label(
                LocalizedStringKey(scope.localizationKey),
                systemImage: isSelected ? "checkmark.circle.fill" : newsScopeIcon(scope)
            )
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: .infinity,
                minHeight: 44
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("home.news.scopeHint"))
        .accessibilityIdentifier("home.newsScope.\(scope.rawValue)")
    }

    private func newsScopeIcon(_ scope: HomeNewsScope) -> String {
        switch scope {
        case .all: "newspaper"
        case .saved: "bookmark"
        }
    }

    @ViewBuilder
    private func newsCategoryControls(
        _ presentation: HomeNewsPresentation
    ) -> some View {
        let controls = Group {
            newsCategoryButton(
                key: nil,
                isSelected: presentation.selectedCategoryKey == nil
            )
            ForEach(presentation.categoryKeys, id: \.self) { categoryKey in
                newsCategoryButton(
                    key: categoryKey,
                    isSelected: presentation.selectedCategoryKey == categoryKey
                )
            }
        }

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                controls
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    controls
                }
            }
        }
    }

    private func newsCategoryButton(
        key: String?,
        isSelected: Bool
    ) -> some View {
        let titleKey = key.map { LocalizedStringKey($0) }
            ?? LocalizedStringKey("home.news.category.all")
        return Button {
            selectedNewsCategoryKey = key
        } label: {
            Label(
                titleKey,
                systemImage: isSelected ? "checkmark.circle.fill" : "circle"
            )
            .font(.footnote.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                minHeight: 44,
                alignment: .leading
            )
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AppTheme.accent : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("home.news.categoryHint"))
        .accessibilityIdentifier(
            "home.newsCategory.\(key ?? "all")"
        )
    }

    @ViewBuilder
    private func newsArticleHierarchy(
        _ presentation: HomeNewsPresentation
    ) -> some View {
        if let leadingArticle = presentation.leadingArticle {
            NavigationLink {
                ArticleDetailView(article: leadingArticle)
            } label: {
                HomeLeadingArticleCard(article: leadingArticle)
            }
            .buttonStyle(.plain)

            ForEach(presentation.remainingArticles) { article in
                NavigationLink {
                    ArticleDetailView(article: article)
                } label: {
                    ArticleCard(article: article)
                }
                .buttonStyle(.plain)
            }
        } else {
            let emptyKey: LocalizedStringKey = newsScope == .saved
                ? "home.news.noSaved"
                : "home.news.noLatest"
            Label(
                emptyKey,
                systemImage: newsScope == .saved
                    ? "bookmark.slash"
                    : "newspaper"
            )
            .font(.subheadline)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .sportsCard()
            .accessibilityIdentifier("home.news.empty.\(newsScope.rawValue)")
        }
    }

    private var savedNewsError: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                "home.news.savedLoadFailed",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.warm)
            Text("home.news.savedLoadFailedBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            Button("action.retry") {
                Task { await loadSavedArticles(focusFailure: true) }
            }
            .buttonStyle(.borderedProminent)
            .frame(minWidth: 44, minHeight: 44)
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityFocused($savedNewsErrorFocused)
        .accessibilityIdentifier("home.news.saved.error")
    }

    @MainActor
    private func load(announceFreshness: Bool = false) async {
        let requestID = UUID()
        loadRequestID = requestID
        failed = false
        do {
            let loadedFeed = try await appModel.dataProvider.homeFeed()
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            let availableFilters = HomeMatchFilter.availableFilters(
                in: loadedFeed.fixtures
            )
            if !availableFilters.contains(selectedMatchFilter) {
                selectedMatchFilter = .all
            }
            feed = loadedFeed
        } catch {
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            failed = true
        }
        await updateFreshness(requestID: requestID, announce: announceFreshness)
        publishWidgetIfReady()
    }

    private func updateFreshness(requestID: UUID, announce: Bool) async {
        let updated = await appModel.publicContentFreshness(for: .home)
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshness = updated
        guard announce || updated?.requiresAttention == true else { return }
        freshnessFocused = false
        await Task.yield()
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshnessFocused = updated != nil
    }

    @MainActor
    private func synchronizeHomeFollows() async {
        let requestID = UUID()
        followLoadRequestID = requestID
        await appModel.synchronizeFollows()
        guard followLoadRequestID == requestID, !Task.isCancelled else { return }
        followsReady = true
        publishWidgetIfReady()
    }

    @MainActor
    private func publishWidgetIfReady() {
        guard followsReady, let feed else { return }
        let isDemo = appModel.usesDemoPublicData || freshness?.source == .demoFallback
        appModel.publishWidgetFixtures(feed.fixtures, isDemo: isDemo)
    }

    @MainActor
    private func loadSavedArticles(focusFailure: Bool = false) async {
        let requestID = UUID()
        savedNewsRequestID = requestID
        savedNewsFailed = false
        do {
            let loadedArticles = try await appModel.dataProvider.favoriteArticles()
            guard savedNewsRequestID == requestID, !Task.isCancelled else { return }
            savedArticles = loadedArticles
        } catch {
            guard savedNewsRequestID == requestID, !Task.isCancelled else { return }
            savedNewsFailed = true
            if focusFailure, newsScope == .saved {
                focusSavedNewsError()
            }
        }
    }

    @MainActor
    private func focusSavedNewsError() {
        savedNewsErrorFocused = false
        Task { @MainActor in
            await Task.yield()
            guard newsScope == .saved, savedNewsFailed else { return }
            savedNewsErrorFocused = true
        }
    }
}

private struct HomeFixtureItem: Identifiable {
    let fixture: Fixture
    let reason: HomeFixtureFollowReason?

    var id: String { fixture.id }
}

private struct CompactFixtureCard: View {
    @EnvironmentObject private var appModel: AppModel
    let fixture: Fixture
    let reason: HomeFixtureFollowReason?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let reason {
                Label(
                    LocalizedStringKey(reason.homeLocalizationKey),
                    systemImage: "link"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }

            HStack {
                StatusPill(
                    text: LocalizedStringKey(fixture.state.localizationKey),
                    color: fixture.state == .live ? AppTheme.live : AppTheme.accent
                )
                Spacer()
                if fixture.state == .live, let minute = fixture.minute {
                    Text("\(minute)′")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(AppTheme.live)
                }
            }

            teamRow(fixture.homeTeam, score: fixture.homeScore)
            teamRow(fixture.awayTeam, score: fixture.awayScore)

            Text(fixture.competition.displayName(in: appModel.language))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("accessibility.opensMatch"))
    }

    private func teamRow(_ team: Team, score: Int?) -> some View {
        HStack(spacing: 10) {
            TeamBadge(team: team, size: 34)
            Text(team.displayName(in: appModel.language))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer()
            if let score {
                Text("\(score)")
                    .font(.title3.monospacedDigit().weight(.black))
            }
        }
    }
}

struct ArticleCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ArticleCardMetadataRow(article: article)

            Text(article.title(in: appModel.language))
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.leading)

            ArticleHeroMediaView(article: article, presentation: .card)

            Text(article.summary(in: appModel.language))
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                .multilineTextAlignment(.leading)

            Text(article.source)
                .font(.caption.weight(.semibold))

            if article.isCorrected {
                Label("article.corrected", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warm)
            }

            if let engagement = article.engagement {
                ArticleEngagementSummaryView(
                    articleID: article.id,
                    summary: engagement
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("article.card.\(article.id)")
        .accessibilityHint(Text("accessibility.opensArticle"))
    }
}

private struct HomeLeadingArticleCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ArticleHeroMediaView(article: article, presentation: .leadingCard)

            ArticleCardMetadataRow(article: article)

            Text(article.title(in: appModel.language))
                .font(.title2.weight(.black))
                .multilineTextAlignment(.leading)

            Text(article.summary(in: appModel.language))
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 4)
                .multilineTextAlignment(.leading)

            Text(article.source)
                .font(.caption.weight(.semibold))

            if article.isCorrected {
                Label("article.corrected", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warm)
            }

            if let engagement = article.engagement {
                ArticleEngagementSummaryView(
                    articleID: article.id,
                    summary: engagement
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("article.card.\(article.id)")
        .accessibilityHint(Text("accessibility.opensArticle"))
    }
}
