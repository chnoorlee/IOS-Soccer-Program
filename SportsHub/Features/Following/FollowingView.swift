import SwiftUI

struct FollowingView: View {
    private enum PersonalSection: Hashable {
        case articles
        case videos
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var savedArticles: [Article]?
    @State private var savedVideos: [SportsVideo]?
    @State private var teamMatchSnapshots: [TeamMatchSnapshot]?
    @State private var teamMatchSnapshotFailed = false
    @State private var teamMatchSnapshotFreshness: PublicContentFreshness?
    @State private var failedSections: Set<PersonalSection> = []
    @State private var didAttemptFollowLoad = false
    @State private var loadRequestID: UUID?
    @State private var articleRequestID: UUID?
    @State private var videoRequestID: UUID?
    @State private var teamMatchSnapshotRequestID: UUID?
    @AccessibilityFocusState private var focusedError: PersonalSection?
    @AccessibilityFocusState private var teamMatchSnapshotErrorFocused: Bool

    private var teamFollows: [SportsFollow] {
        appModel.orderedFollows.filter { $0.type == .team }
    }

    private var nonTeamFollows: [SportsFollow] {
        appModel.orderedFollows.filter { $0.type != .team }
    }

    private var dashboardTeamFollows: [SportsFollow] {
        Array(
            teamFollows.prefix(TeamMatchSnapshotRequestLimits.maximumTeamsPerDashboard)
        )
    }

    private var overflowTeamFollows: [SportsFollow] {
        Array(
            teamFollows.dropFirst(TeamMatchSnapshotRequestLimits.maximumTeamsPerDashboard)
        )
    }

    private var orderedFollowedTeamIDs: [String] {
        dashboardTeamFollows.map(\.entityID)
    }

    private var combinedIsEmpty: Bool {
        didAttemptFollowLoad
            && savedArticles != nil
            && savedVideos != nil
            && failedSections.isEmpty
            && appModel.followError == nil
            && appModel.orderedFollows.isEmpty
            && savedArticles?.isEmpty == true
            && savedVideos?.isEmpty == true
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                NotificationSettingsCard()

                if appModel.followError != nil {
                    followErrorCard
                }

                if combinedIsEmpty {
                    ContentUnavailableView(
                        "following.empty",
                        systemImage: "bookmark.slash"
                    )
                    .frame(minHeight: 240)
                    .accessibilityIdentifier("following.empty")
                } else {
                    followedTeamsDashboardSection
                    followedInterestsSection
                    savedArticlesSection
                    savedVideosSection
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("following.title")
        .accessibilityIdentifier("following.screen")
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .articleFavoritesDidChange)) { _ in
            Task { await reloadArticles() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoFavoritesDidChange)) { _ in
            Task { await reloadVideos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .followsDidChange)) { _ in
            guard didAttemptFollowLoad else { return }
            Task { await reloadTeamMatchSnapshots() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationStateDidChange)) { _ in
            loadRequestID = nil
            articleRequestID = nil
            videoRequestID = nil
            teamMatchSnapshotRequestID = nil
            savedArticles = nil
            savedVideos = nil
            teamMatchSnapshots = nil
            teamMatchSnapshotFailed = false
            teamMatchSnapshotFreshness = nil
            didAttemptFollowLoad = false
            failedSections.removeAll()
            Task { await load() }
        }
    }

    @ViewBuilder
    private var followedInterestsSection: some View {
        if !didAttemptFollowLoad && appModel.orderedFollows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "following.followedInterests")
                sectionLoading("following.loadingInterests")
            }
        } else if appModel.orderedFollows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "following.followedInterests")
                emptySectionMessage("following.noFollowedInterests", systemImage: "star")
                    .accessibilityIdentifier("following.interests.empty")
            }
        } else if !nonTeamFollows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "following.followedInterests")
                ForEach(nonTeamFollows) { follow in
                    followedInterestCard(follow)
                }
            }
        }
    }

    @ViewBuilder
    private var followedTeamsDashboardSection: some View {
        if didAttemptFollowLoad && !teamFollows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "following.teamDashboard.title")

                if teamMatchSnapshotFailed {
                    teamMatchSnapshotError
                    ForEach(teamFollows) { follow in
                        followedInterestCard(follow)
                    }
                } else if let teamMatchSnapshots {
                    if let teamMatchSnapshotFreshness {
                        PublicContentStatusView(
                            freshness: teamMatchSnapshotFreshness,
                            identifier: "following.teamDashboard"
                        )
                    }
                    ForEach(teamMatchSnapshots) { snapshot in
                        if let follow = dashboardTeamFollows.first(where: {
                            $0.entityID == snapshot.team.id
                        }) {
                            FollowingTeamSnapshotCard(snapshot: snapshot, follow: follow)
                        }
                    }
                    if !overflowTeamFollows.isEmpty {
                        Label(
                            "following.teamDashboard.limitBody",
                            systemImage: "info.circle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .sportsCard()
                        .accessibilityIdentifier("following.teamDashboard.limit")
                        ForEach(overflowTeamFollows) { follow in
                            followedInterestCard(follow)
                        }
                    }
                } else {
                    sectionLoading("following.teamDashboard.loading")
                        .accessibilityIdentifier("following.teamDashboard.loading")
                }
            }
            .accessibilityIdentifier("following.teamDashboard.section")
        }
    }

    private var teamMatchSnapshotError: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                "following.teamDashboard.loadFailed",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.warm)
            Text("following.teamDashboard.loadFailedBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            Button("action.retry") {
                Task { await reloadTeamMatchSnapshots() }
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityFocused($teamMatchSnapshotErrorFocused)
        .accessibilityIdentifier("following.teamDashboard.error")
    }

    @ViewBuilder
    private var savedArticlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "following.savedArticles")
            if failedSections.contains(.articles) {
                sectionError(.articles)
            } else if let savedArticles {
                if savedArticles.isEmpty {
                    emptySectionMessage("following.noSavedArticles", systemImage: "newspaper")
                } else {
                    ForEach(savedArticles) { article in
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            ArticleCard(article: article)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("accessibility.opensArticle"))
                        .accessibilityIdentifier("following.savedArticle.\(article.id)")
                    }
                }
            } else {
                sectionLoading("following.loadingSavedArticles")
            }
        }
    }

    @ViewBuilder
    private var savedVideosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "following.savedVideos")
            if failedSections.contains(.videos) {
                sectionError(.videos)
            } else if let savedVideos {
                if savedVideos.isEmpty {
                    emptySectionMessage("following.noSavedVideos", systemImage: "play.rectangle")
                } else {
                    ForEach(savedVideos) { video in
                        NavigationLink {
                            VideoDetailView(video: video)
                        } label: {
                            VideoCard(video: video)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("accessibility.opensVideo"))
                        .accessibilityIdentifier("following.savedVideo.\(video.id)")
                    }
                }
            } else {
                sectionLoading("following.loadingSavedVideos")
            }
        }
    }

    private var followErrorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("following.syncFailed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.warm)
            Text("following.syncFailedBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            HStack {
                Button("action.retry") {
                    Task {
                        await appModel.synchronizeFollows()
                        didAttemptFollowLoad = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                Button("action.dismiss") {
                    appModel.dismissFollowError()
                }
                .frame(minHeight: 44)
            }
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("following.syncError")
    }

    private func sectionError(_ section: PersonalSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(errorTitle(for: section), systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.warm)
            Text("following.sectionLoadFailedBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            Button("action.retry") {
                Task { await reload(section) }
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityFocused($focusedError, equals: section)
        .accessibilityIdentifier("following.error.\(identifier(for: section))")
    }

    private func emptySectionMessage(
        _ key: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        Label(key, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .sportsCard()
    }

    private func sectionLoading(_ key: LocalizedStringKey) -> some View {
        ProgressView(key)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .sportsCard()
    }

    @ViewBuilder
    private func followedInterestCard(_ follow: SportsFollow) -> some View {
        let content = Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    followedInterestPrimaryAction(follow)
                    unfollowButton(follow, expands: true)
                }
            } else {
                HStack(spacing: 14) {
                    followedInterestPrimaryAction(follow)
                    unfollowButton(follow, expands: false)
                }
            }
        }

        content
            .sportsCard()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(
                "following.entity.\(follow.type.rawValue).\(follow.entityID)"
            )
    }

    @ViewBuilder
    private func followedInterestPrimaryAction(_ follow: SportsFollow) -> some View {
        if let entity = follow.entity {
            NavigationLink {
                destination(for: entity)
            } label: {
                followedInterestLabel(follow, entity: entity)
            }
            .buttonStyle(.plain)
            .accessibilityHint(navigationHint(for: follow.type))
        } else {
            unavailableInterestLabel(follow)
        }
    }

    private func followedInterestLabel(
        _ follow: SportsFollow,
        entity: FollowEntitySnapshot
    ) -> some View {
        HStack(spacing: 14) {
            entityIcon(entity)
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
        .accessibilityElement(children: .combine)
    }

    private func unavailableInterestLabel(_ follow: SportsFollow) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
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
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func entityIcon(_ entity: FollowEntitySnapshot) -> some View {
        switch entity {
        case let .team(team):
            TeamBadge(team: team, size: 48)
        case .player:
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        case .competition:
            Image(systemName: "trophy.fill")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.warm)
                .frame(width: 48, height: 48)
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

    private func unfollowButton(_ follow: SportsFollow, expands: Bool) -> some View {
        let isBusy = appModel.isFollowMutationInProgress(
            type: follow.type,
            entityID: follow.entityID
        )
        return Button {
            appModel.toggleFollow(
                type: follow.type,
                entityID: follow.entityID,
                entity: follow.entity
            )
        } label: {
            if isBusy {
                ProgressView()
                    .frame(
                        minWidth: 44,
                        maxWidth: expands ? .infinity : nil,
                        minHeight: 44
                    )
            } else if expands {
                Label("action.unfollow", systemImage: "star.slash")
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Image(systemName: "star.slash")
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.bordered)
        .disabled(isBusy)
        .accessibilityLabel(unfollowAccessibilityLabel(follow))
        .accessibilityHint(Text("following.unfollowHint"))
        .accessibilityIdentifier(
            "following.unfollow.\(follow.type.rawValue).\(follow.entityID)"
        )
    }

    private func unfollowAccessibilityLabel(_ follow: SportsFollow) -> Text {
        Text("action.unfollow")
            + Text(" ")
            + Text(LocalizedStringKey(follow.type.localizationKey))
            + Text(" ")
            + Text(follow.entity?.displayName(in: appModel.language) ?? follow.entityID)
    }

    private func navigationHint(for type: FollowEntityType) -> Text {
        switch type {
        case .team: Text("accessibility.opensTeam")
        case .player: Text("accessibility.opensPlayer")
        case .competition: Text("accessibility.opensCompetition")
        }
    }

    @MainActor
    private func load() async {
        let requestID = UUID()
        loadRequestID = requestID
        let provider = appModel.dataProvider
        async let notificationRefresh: Void = appModel.notificationSettings.refresh()
        async let articleResult = followingResult { try await provider.favoriteArticles() }
        async let videoResult = followingResult { try await provider.favoriteVideos() }

        await appModel.synchronizeFollows()
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        didAttemptFollowLoad = true
        let teamIDs = orderedFollowedTeamIDs
        let snapshotRequestID = UUID()
        teamMatchSnapshotRequestID = snapshotRequestID
        teamMatchSnapshots = nil
        teamMatchSnapshotFailed = false
        teamMatchSnapshotFreshness = nil
        async let snapshotResult: Result<[TeamMatchSnapshot], SportsDataError> =
            followingResult {
                guard !teamIDs.isEmpty else { return [] }
                return try await provider.teamMatchSnapshots(ids: teamIDs)
            }
        let loaded = await (articleResult, videoResult, snapshotResult)
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        apply(loaded.0, to: .articles)
        apply(loaded.1, to: .videos)
        if teamMatchSnapshotRequestID == snapshotRequestID {
            applyTeamMatchSnapshots(loaded.2)
            if case .success = loaded.2, !teamIDs.isEmpty {
                let freshness = await appModel.publicContentFreshness(
                    for: .teamMatchSnapshots(ids: teamIDs)
                )
                guard teamMatchSnapshotRequestID == snapshotRequestID,
                      !Task.isCancelled else { return }
                teamMatchSnapshotFreshness = freshness
            }
        }
        _ = await notificationRefresh
    }

    @MainActor
    private func reload(_ section: PersonalSection) async {
        switch section {
        case .articles:
            await reloadArticles()
        case .videos:
            await reloadVideos()
        }
    }

    @MainActor
    private func reloadArticles() async {
        let requestID = UUID()
        articleRequestID = requestID
        let provider = appModel.dataProvider
        let result = await followingResult { try await provider.favoriteArticles() }
        guard articleRequestID == requestID, !Task.isCancelled else { return }
        apply(result, to: .articles)
    }

    @MainActor
    private func reloadVideos() async {
        let requestID = UUID()
        videoRequestID = requestID
        let provider = appModel.dataProvider
        let result = await followingResult { try await provider.favoriteVideos() }
        guard videoRequestID == requestID, !Task.isCancelled else { return }
        apply(result, to: .videos)
    }

    @MainActor
    private func reloadTeamMatchSnapshots() async {
        let requestID = UUID()
        teamMatchSnapshotRequestID = requestID
        let teamIDs = orderedFollowedTeamIDs
        teamMatchSnapshots = nil
        teamMatchSnapshotFailed = false
        teamMatchSnapshotFreshness = nil

        guard !teamIDs.isEmpty else {
            teamMatchSnapshots = []
            return
        }

        let provider = appModel.dataProvider
        let result = await followingResult {
            try await provider.teamMatchSnapshots(ids: teamIDs)
        }
        guard teamMatchSnapshotRequestID == requestID,
              !Task.isCancelled else { return }
        applyTeamMatchSnapshots(result)
        guard case .success = result else { return }
        let freshness = await appModel.publicContentFreshness(
            for: .teamMatchSnapshots(ids: teamIDs)
        )
        guard teamMatchSnapshotRequestID == requestID,
              !Task.isCancelled else { return }
        teamMatchSnapshotFreshness = freshness
    }

    @MainActor
    private func applyTeamMatchSnapshots(
        _ result: Result<[TeamMatchSnapshot], SportsDataError>
    ) {
        switch result {
        case let .success(value):
            teamMatchSnapshots = value
            teamMatchSnapshotFailed = false
        case .failure:
            teamMatchSnapshots = nil
            teamMatchSnapshotFailed = true
            teamMatchSnapshotErrorFocused = nil
            Task { @MainActor in
                await Task.yield()
                teamMatchSnapshotErrorFocused = true
            }
        }
    }

    @MainActor
    private func apply(
        _ result: Result<[Article], SportsDataError>,
        to section: PersonalSection
    ) {
        switch result {
        case let .success(value):
            savedArticles = value
            failedSections.remove(section)
        case .failure:
            failedSections.insert(section)
            focusError(section)
        }
    }

    @MainActor
    private func apply(
        _ result: Result<[SportsVideo], SportsDataError>,
        to section: PersonalSection
    ) {
        switch result {
        case let .success(value):
            savedVideos = value
            failedSections.remove(section)
        case .failure:
            failedSections.insert(section)
            focusError(section)
        }
    }

    @MainActor
    private func focusError(_ section: PersonalSection) {
        focusedError = nil
        Task { @MainActor in
            await Task.yield()
            focusedError = section
        }
    }

    private func errorTitle(for section: PersonalSection) -> LocalizedStringKey {
        switch section {
        case .articles: "following.savedArticlesLoadFailed"
        case .videos: "following.savedVideosLoadFailed"
        }
    }

    private func identifier(for section: PersonalSection) -> String {
        switch section {
        case .articles: "articles"
        case .videos: "videos"
        }
    }
}

private func followingResult<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
) async -> Result<Value, SportsDataError> {
    do {
        return .success(try await operation())
    } catch let error as SportsDataError {
        return .failure(error)
    } catch {
        return .failure(.serverUnavailable)
    }
}
