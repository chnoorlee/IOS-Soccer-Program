import Foundation
import SwiftUI

struct CompetitionDetailView: View {
    private enum DetailSection: String, CaseIterable, Identifiable, Hashable {
        case latest
        case standings
        case leaders
        case fixtures

        var id: String { rawValue }
        var localizationKey: String { "competition.\(rawValue)" }

        var systemImage: String {
            switch self {
            case .latest: "newspaper.fill"
            case .standings: "list.number"
            case .leaders: "medal.fill"
            case .fixtures: "calendar"
            }
        }
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let competition: Competition

    @State private var selectedSeasonID: String?
    @State private var selectedSection: DetailSection = .standings
    @State private var leaderCategory: CompetitionLeaderCategory = .goals
    @State private var standings: [StandingGroup]?
    @State private var leaders: [CompetitionLeader]?
    @State private var fixtures: [Fixture]?
    @State private var competitionContent: CompetitionContent?
    @State private var competitionContentFreshness: PublicContentFreshness?
    @State private var standingsFailed = false
    @State private var leadersFailed = false
    @State private var fixturesFailed = false
    @State private var competitionContentFailed = false
    @State private var activeRequestID: UUID?
    @AccessibilityFocusState private var loadErrorFocused: Bool

    init(competition: Competition) {
        self.competition = competition
        _selectedSeasonID = State(initialValue: competition.currentSeason?.id ?? competition.seasons.first?.id)
        _selectedSection = State(initialValue: competition.seasons.isEmpty ? .latest : .standings)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                competitionHeader
                sectionControls
                if selectedSection == .latest {
                    selectedContent
                } else if competition.seasons.isEmpty || selectedSeasonID == nil {
                    ContentUnavailableView(
                        "competition.seasonUnavailable",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("competition.seasonUnavailableBody")
                    )
                    .frame(minHeight: 260)
                } else {
                    seasonPicker
                    selectedContent
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle(competition.displayName(in: appModel.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SportsShareButton(
                    route: .competition(competition.id),
                    fallbackText: competition.displayName(in: appModel.language),
                    accessibilityHint: "accessibility.sharesCompetition"
                )
            }
        }
        .accessibilityIdentifier("competition.detail")
        .task(id: contentRequest) { await loadSelectedContent(contentRequest) }
        .refreshable { await loadSelectedContent(contentRequest) }
        .onChange(of: selectedSeasonID) {
            standings = nil
            leaders = nil
            fixtures = nil
        }
    }

    private var contentRequest: ContentRequest {
        ContentRequest(
            seasonID: selectedSeasonID,
            section: selectedSection,
            leaderCategory: leaderCategory
        )
    }

    private var selectedSeason: Season? {
        guard let selectedSeasonID else { return nil }
        return competition.seasons.first(where: { $0.id == selectedSeasonID })
    }

    private var competitionHeader: some View {
        VStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.warm)
                .accessibilityHidden(true)
            Text(competition.displayName(in: appModel.language))
                .font(.largeTitle.weight(.black))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            SportsFollowButton(
                type: .competition,
                entityID: competition.id,
                entity: .competition(competition),
                accessibilityIdentifier: "competition.follow"
            )
            ContextualAlertSettingsButton(
                target: .entity(.competition(competition)),
                accessibilityIdentifier: "competition.alerts"
            )
        }
        .frame(maxWidth: .infinity)
        .sportsCard()
    }

    private var seasonPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("competition.seasonArchive.title", systemImage: "archivebox.fill")
                .font(.headline.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text("competition.seasonArchive.sourceNote")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            if let selectedSeason {
                Menu {
                    ForEach(competition.seasons) { season in
                        Button {
                            selectedSeasonID = season.id
                        } label: {
                            HStack {
                                Text(season.displayName(in: appModel.language))
                                Spacer(minLength: 8)
                                Text(seasonStatusKey(season))
                                if season.id == selectedSeasonID {
                                    Image(systemName: "checkmark")
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(
                            season.id == selectedSeasonID ? .isSelected : []
                        )
                        .accessibilityIdentifier("competition.season.option.\(season.id)")
                    }
                } label: {
                    seasonSelectionLabel(selectedSeason)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("competition.seasonArchive.hint"))
                .accessibilityIdentifier("competition.season.archive")
            }
        }
        .sportsCard()
    }

    @ViewBuilder
    private func seasonSelectionLabel(_ season: Season) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                seasonIdentity(season)
                seasonStatus(season)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else {
            HStack(spacing: 12) {
                seasonIdentity(season)
                Spacer(minLength: 8)
                seasonStatus(season)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    private func seasonIdentity(_ season: Season) -> some View {
        HStack(spacing: 12) {
            Image(systemName: season.isCurrent ? "sparkles" : "clock.arrow.circlepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(season.displayName(in: appModel.language))
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                HStack(spacing: 4) {
                    Text(season.startDate, format: .dateTime.month(.abbreviated).year())
                    Text(verbatim: "–")
                    Text(season.endDate, format: .dateTime.month(.abbreviated).year())
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func seasonStatus(_ season: Season) -> some View {
        Text(seasonStatusKey(season))
        .font(.caption.weight(.bold))
        .foregroundStyle(season.isCurrent ? Color.white : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(season.isCurrent ? AppTheme.ink : AppTheme.background)
        .clipShape(Capsule())
    }

    private func seasonStatusKey(_ season: Season) -> LocalizedStringKey {
        LocalizedStringKey(
            season.isCurrent
                ? "competition.seasonArchive.current"
                : "competition.seasonArchive.archived"
        )
    }

    @ViewBuilder
    private var sectionControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(DetailSection.allCases) { sectionButton($0, expands: true) }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DetailSection.allCases) { sectionButton($0, expands: false) }
                }
            }
            .accessibilityIdentifier("competition.sections.scroll")
        }
    }

    private func sectionButton(_ section: DetailSection, expands: Bool) -> some View {
        let isSelected = section == selectedSection
        return Button {
            selectedSection = section
        } label: {
            Label(
                LocalizedStringKey(section.localizationKey),
                systemImage: isSelected ? "checkmark.circle.fill" : section.systemImage
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
        .accessibilityHint(Text("competition.sectionHint"))
        .accessibilityIdentifier("competition.section.\(section.rawValue)")
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .latest: latestSection
        case .standings: standingsSection
        case .leaders: leadersSection
        case .fixtures: fixturesSection
        }
    }

    private var latestSection: some View {
        EntityEditorialContentSection(
            scope: .competition,
            articles: competitionContent?.articles,
            videos: competitionContent?.videos,
            freshness: competitionContentFreshness,
            loadFailed: competitionContentFailed,
            isLoading: competitionContent == nil && !competitionContentFailed
        ) {
            reloadSelectedContent()
        }
        .accessibilityFocused($loadErrorFocused)
    }

    @ViewBuilder
    private var standingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "competition.standings")
            if standingsFailed {
                LoadStateView(state: .error) { reloadSelectedContent() }
                    .accessibilityFocused($loadErrorFocused)
            } else if standings == nil {
                LoadStateView(state: .loading)
            } else if let standings, standings.isEmpty {
                LoadStateView(state: .empty)
            } else if let standings {
                StandingsTableView(groups: standings)
            }
        }
    }

    @ViewBuilder
    private var leadersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "competition.leaders")
            leaderPicker
            if leadersFailed {
                LoadStateView(state: .error) { reloadSelectedContent() }
                    .accessibilityFocused($loadErrorFocused)
            } else if leaders == nil {
                LoadStateView(state: .loading)
            } else if let leaders, leaders.isEmpty {
                LoadStateView(state: .empty)
            } else if let leaders {
                ForEach(leaders) { leader in
                    NavigationLink {
                        PlayerDetailView(player: leader.player)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(leader.rank)")
                                .font(.title3.monospacedDigit().weight(.black))
                                .frame(width: 30)
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(leader.player.name).font(.headline)
                                Text(leader.team.displayName(in: appModel.language))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer(minLength: 0)
                            Text(leader.value, format: .number.precision(.fractionLength(0...2)))
                                .font(.title2.monospacedDigit().weight(.black))
                        }
                        .frame(minHeight: 56)
                        .sportsCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(Text("accessibility.opensPlayer"))
                }
            }
        }
    }

    @ViewBuilder
    private var fixturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "competition.fixtures")
            if fixturesFailed {
                LoadStateView(state: .error) { reloadSelectedContent() }
                    .accessibilityFocused($loadErrorFocused)
            } else if fixtures == nil {
                LoadStateView(state: .loading)
            } else if let fixtures, fixtures.isEmpty {
                LoadStateView(state: .empty)
            } else if let fixtures {
                let presentation = CompetitionFixturesPresentation(fixtures: fixtures)
                ForEach(presentation.sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(
                            LocalizedStringKey(section.kind.localizationKey),
                            systemImage: section.kind.systemImage
                        )
                        .font(.title3.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(
                            "competition.fixtures.section.\(section.kind.rawValue)"
                        )
                        ForEach(section.fixtures) { fixture in
                            NavigationLink {
                                MatchCenterView(fixtureID: fixture.id)
                            } label: {
                                FixtureCard(fixture: fixture, showsCompetition: false)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("competition.fixture.\(fixture.id)")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("competition.fixtures")
    }

    @ViewBuilder
    private var leaderPicker: some View {
        let picker = Picker("competition.leaderCategory", selection: $leaderCategory) {
            ForEach(CompetitionLeaderCategory.allCases) { category in
                Text(LocalizedStringKey(category.localizationKey)).tag(category)
            }
        }
        if dynamicTypeSize.isAccessibilitySize || appModel.language == .arabic {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private func reloadSelectedContent() {
        Task { await loadSelectedContent(contentRequest) }
    }

    @MainActor
    private func loadSelectedContent(_ request: ContentRequest) async {
        let requestID = UUID()
        activeRequestID = requestID
        resetLoadState(for: request.section)
        do {
            switch request.section {
            case .latest:
                let value = try await appModel.dataProvider.competitionContent(
                    id: competition.id
                )
                guard accepts(requestID, request: request) else { return }
                competitionContent = value
            case .standings:
                guard let seasonID = request.seasonID else { return }
                let value = try await appModel.dataProvider.competitionStandings(
                    id: competition.id,
                    seasonID: seasonID
                )
                guard accepts(requestID, request: request) else { return }
                standings = value
            case .leaders:
                guard let seasonID = request.seasonID else { return }
                let value = try await appModel.dataProvider.competitionLeaders(
                    id: competition.id,
                    seasonID: seasonID,
                    category: request.leaderCategory
                )
                guard accepts(requestID, request: request) else { return }
                leaders = value
            case .fixtures:
                guard let seasonID = request.seasonID else { return }
                let value = try await appModel.dataProvider.competitionFixtures(
                    id: competition.id,
                    seasonID: seasonID
                )
                guard accepts(requestID, request: request) else { return }
                fixtures = value
            }
        } catch is CancellationError {
            return
        } catch {
            guard accepts(requestID, request: request) else { return }
            setFailure(for: request.section)
        }
        if request.section == .latest {
            let freshness = await appModel.publicContentFreshness(
                for: .competitionContent(id: competition.id)
            )
            guard accepts(requestID, request: request) else { return }
            competitionContentFreshness = freshness
        }
    }

    @MainActor
    private func accepts(_ requestID: UUID, request: ContentRequest) -> Bool {
        activeRequestID == requestID && contentRequest == request && !Task.isCancelled
    }

    @MainActor
    private func resetLoadState(for section: DetailSection) {
        loadErrorFocused = false
        switch section {
        case .latest:
            competitionContent = nil
            competitionContentFreshness = nil
            competitionContentFailed = false
        case .standings:
            standings = nil
            standingsFailed = false
        case .leaders:
            leaders = nil
            leadersFailed = false
        case .fixtures:
            fixtures = nil
            fixturesFailed = false
        }
    }

    @MainActor
    private func setFailure(for section: DetailSection) {
        switch section {
        case .latest: competitionContentFailed = true
        case .standings: standingsFailed = true
        case .leaders: leadersFailed = true
        case .fixtures: fixturesFailed = true
        }
        loadErrorFocused = true
    }

    private struct ContentRequest: Hashable {
        let seasonID: String?
        let section: DetailSection
        let leaderCategory: CompetitionLeaderCategory
    }
}
