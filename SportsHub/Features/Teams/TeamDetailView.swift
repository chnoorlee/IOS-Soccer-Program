import Foundation
import SwiftUI

struct TeamDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let teamID: String
    let preview: Team?

    @State private var details: TeamDetails?
    @State private var teamContent: TeamContent?
    @State private var teamFreshness: PublicContentFreshness?
    @State private var contentFreshness: PublicContentFreshness?
    @State private var squad: [PlayerProfile]?
    @State private var loadFailed = false
    @State private var contentFailed = false
    @State private var squadFailed = false
    @State private var hasSquadSeason = true
    @State private var coreRequestID = UUID()
    @State private var contentRequestID = UUID()
    @State private var squadRequestID = UUID()

    init(team: Team) {
        teamID = team.id
        preview = team
    }

    init(teamID: String, preview: Team? = nil) {
        self.teamID = teamID
        self.preview = preview
    }

    var body: some View {
        Group {
            if let details {
                content(details)
            } else if loadFailed {
                LoadStateView(state: .error) {
                    Task { await load() }
                }
            } else {
                LoadStateView(state: .loading)
            }
        }
        .background(AppTheme.background)
        .navigationTitle(preview?.displayName(in: appModel.language) ?? String(localized: "team.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let team = details?.team ?? preview {
                    SportsShareButton(
                        route: .team(team.id),
                        fallbackText: team.displayName(in: appModel.language),
                        accessibilityHint: "accessibility.sharesTeam"
                    )
                }
            }
        }
        .task(id: teamID) { await load() }
    }

    private func content(_ details: TeamDetails) -> some View {
        let presentation = TeamContextPresentation(details: details)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                teamHeader(details.team)
                competitionsSection(details.competitions)
                matchSnapshotSection(presentation)
                teamContentSection
                squadSection
                if !presentation.additionalUpcomingFixtures.isEmpty {
                    fixtureSection(
                        title: "team.moreUpcomingFixtures",
                        fixtures: presentation.additionalUpcomingFixtures
                    )
                }
                if !presentation.additionalRecentFixtures.isEmpty {
                    fixtureSection(
                        title: "team.moreRecentFixtures",
                        fixtures: presentation.additionalRecentFixtures
                    )
                }
            }
            .padding(16)
        }
        .refreshable { await load() }
        .accessibilityIdentifier("team.detail")
    }

    private func matchSnapshotSection(_ presentation: TeamContextPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "team.matchSnapshot")
            if let teamFreshness {
                PublicContentStatusView(
                    freshness: teamFreshness,
                    identifier: "team.context.freshness"
                )
            }
            snapshotSlot(
                title: "team.previousMatch",
                emptyKey: "team.noPreviousMatch",
                systemImage: "backward.end.fill",
                fixture: presentation.previousFixture,
                identifier: "team.context.previous"
            )
            snapshotSlot(
                title: "team.nextMatch",
                emptyKey: "team.noNextMatch",
                systemImage: "forward.end.fill",
                fixture: presentation.nextFixture,
                identifier: "team.context.next"
            )
        }
        .accessibilityIdentifier("team.context")
    }

    @ViewBuilder
    private func snapshotSlot(
        title: LocalizedStringKey,
        emptyKey: LocalizedStringKey,
        systemImage: String,
        fixture: Fixture?,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .accessibilityAddTraits(.isHeader)
            if let fixture {
                NavigationLink {
                    MatchCenterView(fixtureID: fixture.id)
                } label: {
                    FixtureCard(fixture: fixture)
                }
                .buttonStyle(.plain)
            } else {
                Text(emptyKey)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .sportsCard()
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func teamHeader(_ team: Team) -> some View {
        VStack(spacing: 14) {
            TeamBadge(team: team, size: 88)
            Text(team.displayName(in: appModel.language))
                .font(.largeTitle.weight(.black))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            SportsFollowButton(
                type: .team,
                entityID: team.id,
                entity: .team(team),
                accessibilityIdentifier: "team.follow"
            )
            ContextualAlertSettingsButton(
                target: .entity(.team(team)),
                accessibilityIdentifier: "team.alerts"
            )
        }
        .frame(maxWidth: .infinity)
        .sportsCard()
    }

    @ViewBuilder
    private func competitionsSection(_ competitions: [Competition]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "team.competitions")
            if competitions.isEmpty {
                Text("team.noCompetitions")
                    .foregroundStyle(AppTheme.muted)
                    .sportsCard()
            } else {
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
                        .frame(minHeight: 44)
                        .sportsCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func fixtureSection(
        title: LocalizedStringKey,
        fixtures: [Fixture]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            ForEach(fixtures) { fixture in
                NavigationLink {
                    MatchCenterView(fixtureID: fixture.id)
                } label: {
                    FixtureCard(fixture: fixture)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var squadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "team.squad")
            if !hasSquadSeason {
                Text("competition.seasonUnavailable")
                    .foregroundStyle(AppTheme.muted)
                    .sportsCard()
            } else if squadFailed {
                LoadStateView(state: .error) {
                    Task { await loadSquad() }
                }
            } else if squad == nil {
                LoadStateView(state: .loading)
            } else if let squad, squad.isEmpty {
                Text("team.noSquad")
                    .foregroundStyle(AppTheme.muted)
                    .sportsCard()
            } else if let squad {
                ForEach(squad) { player in
                    NavigationLink {
                        PlayerDetailView(player: player)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 44, height: 44)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(player.name)
                                    .font(.headline)
                                Text(player.position)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.forward")
                                .foregroundStyle(AppTheme.muted)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 52)
                        .sportsCard()
                        .accessibilityElement(children: .combine)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var teamContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "team.latestContent")
            if let contentFreshness {
                PublicContentStatusView(
                    freshness: contentFreshness,
                    identifier: "team.content.freshness"
                )
            }
            if contentFailed {
                LoadStateView(state: .error) {
                    Task { await loadTeamContent() }
                }
            } else if teamContent == nil {
                LoadStateView(state: .loading)
            } else if let teamContent {
                relatedNewsSection(teamContent.articles)
                relatedVideosSection(teamContent.videos)
            }
        }
        .accessibilityIdentifier("team.content")
    }

    @ViewBuilder
    private func relatedNewsSection(_ articles: [Article]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("team.relatedNews")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            if articles.isEmpty {
                teamContentEmptyState(
                    title: "team.noRelatedNews",
                    systemImage: "newspaper"
                )
            } else {
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
        .accessibilityIdentifier("team.content.news")
    }

    @ViewBuilder
    private func relatedVideosSection(_ videos: [SportsVideo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("team.relatedVideos")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            if videos.isEmpty {
                teamContentEmptyState(
                    title: "team.noRelatedVideos",
                    systemImage: "play.rectangle"
                )
            } else {
                ForEach(videos) { video in
                    NavigationLink {
                        VideoDetailView(video: video)
                    } label: {
                        VideoCard(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier("team.content.videos")
    }

    private func teamContentEmptyState(
        title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .sportsCard()
    }

    @MainActor
    private func load() async {
        async let core: Void = loadCore()
        async let content: Void = loadTeamContent()
        _ = await (core, content)
    }

    @MainActor
    private func loadCore() async {
        let requestID = UUID()
        coreRequestID = requestID
        if details?.team.id != teamID {
            details = nil
            squad = nil
        }
        teamFreshness = nil
        loadFailed = false
        do {
            let loaded = try await appModel.dataProvider.teamDetails(id: teamID)
            guard coreRequestID == requestID else { return }
            details = loaded
            let freshness = await appModel.publicContentFreshness(for: .team(id: teamID))
            guard coreRequestID == requestID else { return }
            teamFreshness = freshness
            await loadSquad(from: loaded)
        } catch {
            guard coreRequestID == requestID else { return }
            loadFailed = true
            let freshness = await appModel.publicContentFreshness(for: .team(id: teamID))
            guard coreRequestID == requestID else { return }
            teamFreshness = freshness
        }
    }

    @MainActor
    private func loadTeamContent() async {
        let requestID = UUID()
        contentRequestID = requestID
        contentFreshness = nil
        if teamContent?.teamID != teamID {
            teamContent = nil
        }
        contentFailed = false
        do {
            let loaded = try await appModel.dataProvider.teamContent(id: teamID)
            guard contentRequestID == requestID else { return }
            teamContent = loaded
        } catch {
            guard contentRequestID == requestID else { return }
            contentFailed = true
        }
        let freshness = await appModel.publicContentFreshness(
            for: .teamContent(id: teamID)
        )
        guard contentRequestID == requestID else { return }
        contentFreshness = freshness
    }

    @MainActor
    private func loadSquad() async {
        guard let details else { return }
        await loadSquad(from: details)
    }

    @MainActor
    private func loadSquad(from details: TeamDetails) async {
        let requestID = UUID()
        squadRequestID = requestID
        guard let seasonID = details.competitions.compactMap(\.currentSeasonID).first else {
            guard squadRequestID == requestID else { return }
            squad = []
            squadFailed = false
            hasSquadSeason = false
            return
        }
        hasSquadSeason = true
        squadFailed = false
        do {
            let loaded = try await appModel.dataProvider.teamSquad(
                id: teamID,
                seasonID: seasonID
            )
            guard squadRequestID == requestID else { return }
            squad = loaded
        } catch {
            guard squadRequestID == requestID else { return }
            squadFailed = true
        }
    }
}
