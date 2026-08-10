import Foundation
import SwiftUI
import UIKit

struct MatchCenterView: View {
    private enum Tab: String, CaseIterable, Identifiable, Hashable {
        case summary
        case timeline
        case lineups
        case statistics
        case standings
        case headToHead

        var id: String { rawValue }
        var key: String { "match.\(rawValue)" }

        var usesSnapshotSource: Bool {
            switch self {
            case .summary, .timeline, .lineups, .statistics: true
            case .standings, .headToHead: false
            }
        }
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let fixtureID: String

    @State private var timeline: MatchLiveTimeline?
    @State private var selectedTab: Tab = .summary
    @State private var failed = false
    @State private var freshness: PublicContentFreshness?
    @State private var loadRequestID: UUID?
    @State private var livePhase: MatchLiveUpdatePhase = .connecting
    @State private var liveSessionGeneration = 0
    @State private var skipSnapshotForGeneration: Int?
    @State private var standingsState: MatchContextLoadState<FixtureStandingsContext> = .idle
    @State private var headToHeadState: MatchContextLoadState<FixtureHeadToHeadContext> = .idle
    @State private var fixtureContentState: MatchContextLoadState<FixtureContent> = .idle
    @State private var standingsRequestID: UUID?
    @State private var headToHeadRequestID: UUID?
    @State private var fixtureContentRequestID: UUID?
    @State private var isLiveActivityActive = false
    @State private var liveActivityOperationInProgress = false
    @State private var liveActivityErrorKey: String?
    @AccessibilityFocusState private var freshnessFocused: Bool
    @AccessibilityFocusState private var liveStatusFocused: Bool
    @AccessibilityFocusState private var standingsErrorFocused: Bool
    @AccessibilityFocusState private var headToHeadErrorFocused: Bool
    @AccessibilityFocusState private var fixtureContentErrorFocused: Bool
    @AccessibilityFocusState private var liveActivityErrorFocused: Bool

    private var details: MatchDetails? {
        timeline?.details
    }

    private var liveTaskKey: String {
        "\(fixtureID)|\(String(describing: scenePhase))|\(liveSessionGeneration)"
    }

    var body: some View {
        Group {
            if let details {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        if let freshness {
                            PublicContentStatusView(
                                freshness: freshness,
                                identifier: "match"
                            )
                            .accessibilityFocused($freshnessFocused)
                        }
                        MatchLiveStatusView(phase: livePhase) {
                            restartLiveSession()
                        }
                        .accessibilityFocused($liveStatusFocused)
                        scoreHeader(details)
                        if shouldShowLiveActivityControl(for: details.fixture) {
                            liveActivityControl(details)
                        }
                        tabPicker
                        tabContent(details)
                        if selectedTab.usesSnapshotSource {
                            sourceFooter(details)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await manualRefresh() }
            } else if failed {
                LoadStateView(state: .error) {
                    restartLiveSession()
                }
            } else {
                LoadStateView(state: .loading)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("matches.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let fixture = details?.fixture {
                    ContextualAlertSettingsButton(
                        target: .fixture(fixture),
                        accessibilityIdentifier: "match.alerts",
                        compact: true
                    )
                    SportsShareButton(
                        route: .fixture(fixture.id),
                        fallbackText: matchShareText(fixture),
                        accessibilityHint: "accessibility.sharesMatch"
                    )
                }
            }
        }
        .accessibilityIdentifier("matchCenter.screen")
        .task(id: liveTaskKey) {
            await runLiveSession(generation: liveSessionGeneration)
        }
        .task(id: fixtureID) {
            await loadFixtureContent()
        }
        .task(id: selectedTab) {
            await loadSelectedContextIfNeeded()
        }
        .task(id: fixtureID) {
            refreshLiveActivityState()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshLiveActivityState()
        }
        .onChange(of: appModel.language) { _, _ in
            Task { await synchronizeLiveActivityIfNeeded() }
        }
    }

    private func matchShareText(_ fixture: Fixture) -> String {
        let status: String
        if let homeScore = fixture.homeScore,
           let awayScore = fixture.awayScore {
            status = "\(homeScore.formatted(.number.locale(appModel.language.locale))) – "
                + awayScore.formatted(.number.locale(appModel.language.locale))
        } else {
            status = fixture.kickoff.formatted(
                .dateTime
                    .hour()
                    .minute()
                    .locale(appModel.language.locale)
            )
        }
        let format = String(
            localized: "share.match.fallbackFormat",
            locale: appModel.language.locale
        )
        return String(
            format: format,
            locale: appModel.language.locale,
            fixture.homeTeam.displayName(in: appModel.language),
            status,
            fixture.awayTeam.displayName(in: appModel.language)
        )
    }

    private func scoreHeader(_ details: MatchDetails) -> some View {
        let fixture = details.fixture

        return VStack(spacing: 18) {
            HStack {
                Text(fixture.competition.displayName(in: appModel.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                StatusPill(
                    text: LocalizedStringKey(fixture.state.localizationKey),
                    color: fixture.state == .live ? AppTheme.live : AppTheme.accent
                )
            }

            HStack(alignment: .center, spacing: 16) {
                scoreTeam(fixture.homeTeam)

                VStack(spacing: 6) {
                    Text(fixture.scoreText ?? "–")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .monospacedDigit()

                    if let minute = fixture.minute, fixture.state == .live {
                        Text("\(minute)′")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AppTheme.live)
                    } else {
                        Text(fixture.kickoff, format: .dateTime.hour().minute())
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .frame(minWidth: 84)

                scoreTeam(fixture.awayTeam)
            }

            Label(fixture.venue(in: appModel.language), systemImage: "mappin.and.ellipse")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
    }

    private func scoreTeam(_ team: Team) -> some View {
        VStack(spacing: 8) {
            TeamBadge(team: team, size: 68)
            Text(team.displayName(in: appModel.language))
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    private func shouldShowLiveActivityControl(for fixture: Fixture) -> Bool {
        isLiveActivityActive
            || MatchLiveActivityPolicy.eligibility(for: fixture) != .terminal
    }

    private func liveActivityControl(_ details: MatchDetails) -> some View {
        let fixture = details.fixture
        let eligibility = MatchLiveActivityPolicy.eligibility(for: fixture)
        let systemEnabled = appModel.matchLiveActivityCoordinator.areActivitiesEnabled
        let canStart = systemEnabled && eligibility == .eligible

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("match.activity.title", systemImage: "waveform.path.ecg.rectangle")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text(LocalizedStringKey(
                    isLiveActivityActive
                        ? "match.activity.active"
                        : "match.activity.inactive"
                ))
                .font(.caption.weight(.bold))
                .foregroundStyle(
                    isLiveActivityActive ? AppTheme.accent : Color.primary
                )
            }

            Text(liveActivityAvailabilityKey(
                eligibility: eligibility,
                systemEnabled: systemEnabled
            ))
            .font(.subheadline)
            .foregroundStyle(Color.primary)
            .fixedSize(horizontal: false, vertical: true)

            Text("match.activity.localUpdatesOnly")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await toggleLiveActivity(details) }
            } label: {
                HStack(spacing: 8) {
                    if liveActivityOperationInProgress {
                        ProgressView()
                            .tint(.white)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: isLiveActivityActive ? "stop.fill" : "play.fill")
                            .accessibilityHidden(true)
                    }
                    Text(LocalizedStringKey(
                        isLiveActivityActive
                            ? "match.activity.stop"
                            : "match.activity.start"
                    ))
                    .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(isLiveActivityActive ? AppTheme.ink : AppTheme.accent)
            .disabled(
                liveActivityOperationInProgress
                    || (!isLiveActivityActive && !canStart)
            )
            .accessibilityValue(
                Text(LocalizedStringKey(
                    isLiveActivityActive
                        ? "match.activity.active"
                        : "match.activity.inactive"
                ))
            )
            .accessibilityHint(
                Text(LocalizedStringKey(
                    isLiveActivityActive
                        ? "match.activity.stopHint"
                        : "match.activity.startHint"
                ))
            )
            .accessibilityIdentifier("match.activity.toggle")

            if let liveActivityErrorKey {
                Label(
                    LocalizedStringKey(liveActivityErrorKey),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.live)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($liveActivityErrorFocused)
                .accessibilityIdentifier("match.activity.error")
            }
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("match.activity.control")
    }

    private func liveActivityAvailabilityKey(
        eligibility: MatchLiveActivityEligibility,
        systemEnabled: Bool
    ) -> LocalizedStringKey {
        guard systemEnabled else { return "match.activity.disabled" }
        switch eligibility {
        case .eligible:
            return isLiveActivityActive
                ? "match.activity.activeBody"
                : "match.activity.ready"
        case .kickoffTooDistant:
            return "match.activity.tooEarly"
        case .terminal:
            return "match.activity.terminal"
        }
    }

    @MainActor
    private func toggleLiveActivity(_ details: MatchDetails) async {
        guard !liveActivityOperationInProgress else { return }
        liveActivityOperationInProgress = true
        liveActivityErrorKey = nil
        liveActivityErrorFocused = false
        defer { liveActivityOperationInProgress = false }

        if isLiveActivityActive {
            await appModel.matchLiveActivityCoordinator.stop(
                fixture: details.fixture,
                language: appModel.language,
                isDemo: isDemoMatchContent,
                updatedAt: details.updatedAt
            )
            isLiveActivityActive = false
            return
        }

        do {
            _ = try await appModel.matchLiveActivityCoordinator.start(
                fixture: details.fixture,
                language: appModel.language,
                isDemo: isDemoMatchContent,
                updatedAt: details.updatedAt
            )
            isLiveActivityActive = true
        } catch let error as MatchLiveActivityOperationError {
            liveActivityErrorKey = liveActivityErrorLocalizationKey(error)
            await focusLiveActivityError()
        } catch {
            liveActivityErrorKey = "match.activity.error.request"
            await focusLiveActivityError()
        }
    }

    private var isDemoMatchContent: Bool {
        appModel.usesDemoPublicData || freshness?.source == .demoFallback
    }

    private func liveActivityErrorLocalizationKey(
        _ error: MatchLiveActivityOperationError
    ) -> String {
        switch error {
        case .disabled:
            "match.activity.error.disabled"
        case let .ineligible(eligibility):
            eligibility == .kickoffTooDistant
                ? "match.activity.error.tooEarly"
                : "match.activity.error.terminal"
        case .invalidPayload:
            "match.activity.error.invalidData"
        case .requestFailed:
            "match.activity.error.request"
        }
    }

    @MainActor
    private func focusLiveActivityError() async {
        liveActivityErrorFocused = false
        await Task.yield()
        guard liveActivityErrorKey != nil else { return }
        liveActivityErrorFocused = true
    }

    @MainActor
    private func refreshLiveActivityState() {
        isLiveActivityActive = appModel.matchLiveActivityCoordinator.isActive(
            fixtureID: fixtureID
        )
    }

    @MainActor
    private func synchronizeLiveActivityIfNeeded(
        _ matchDetails: MatchDetails? = nil
    ) async {
        guard let matchDetails = matchDetails ?? details else {
            refreshLiveActivityState()
            return
        }
        let result = await appModel.matchLiveActivityCoordinator.synchronize(
            fixture: matchDetails.fixture,
            language: appModel.language,
            isDemo: isDemoMatchContent,
            updatedAt: matchDetails.updatedAt
        )
        refreshLiveActivityState()
        guard result == .failed else { return }
        liveActivityErrorKey = "match.activity.error.invalidData"
        await focusLiveActivityError()
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(LocalizedStringKey(tab.key))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                            .background(selectedTab == tab ? AppTheme.ink : AppTheme.surface)
                            .clipShape(Capsule())
                    }
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    .accessibilityIdentifier("matchCenter.tab.\(tab.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("matchCenter.tabs")
    }

    @ViewBuilder
    private func tabContent(_ details: MatchDetails) -> some View {
        switch selectedTab {
        case .summary:
            summary(details)
        case .timeline:
            timeline(details.events)
        case .lineups:
            lineups(details)
        case .statistics:
            statistics(details)
        case .standings:
            standingsContent(details.fixture)
        case .headToHead:
            headToHeadContent(details.fixture)
        }
    }

    private func summary(_ details: MatchDetails) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "match.summary")

            HStack(spacing: 12) {
                summaryTile(
                    icon: "mappin.circle.fill",
                    title: "match.venue",
                    value: details.fixture.venue(in: appModel.language)
                )
                summaryTile(
                    icon: "clock.fill",
                    title: "match.minute",
                    value: details.fixture.minute.map { "\($0)′" } ?? "–"
                )
            }

            broadcastGuide(details.fixture)

            if let possession = details.statistics.first(where: { $0.titleKey == "stat.possession" }) {
                StatisticRow(
                    statistic: possession,
                    homeTeamName: details.fixture.homeTeam.displayName(in: appModel.language),
                    awayTeamName: details.fixture.awayTeam.displayName(in: appModel.language),
                    locale: appModel.language.locale
                )
            }

            fixtureContentSection
        }
    }

    private func broadcastGuide(_ fixture: Fixture) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "match.broadcast.title")
            Text("match.broadcast.rightsNotice")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)

            if fixture.broadcasts.isEmpty {
                Label(
                    fixture.state == .postponed || fixture.state == .cancelled
                        ? LocalizedStringKey("match.broadcast.rescheduleBody")
                        : LocalizedStringKey("match.broadcast.emptyBody"),
                    systemImage: "antenna.radiowaves.left.and.right"
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .sportsCard()
                .accessibilityIdentifier("matchCenter.broadcasts.empty")
            } else {
                ForEach(Array(fixture.broadcasts.enumerated()), id: \.offset) {
                    index,
                    broadcast in
                    broadcastRow(broadcast, index: index)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matchCenter.broadcasts")
    }

    private func broadcastRow(_ broadcast: FixtureBroadcast, index: Int) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    broadcastSignalIcon
                    broadcastText(broadcast)
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    broadcastSignalIcon
                    broadcastText(broadcast)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("matchCenter.broadcast.\(broadcast.regionCode).\(index)")
    }

    private var broadcastSignalIcon: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)
    }

    private func broadcastText(_ broadcast: FixtureBroadcast) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: broadcast.channel(in: appModel.language))
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.leading)

            Text(verbatim: broadcast.regionName(in: appModel.language))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(Capsule())

            if let commentator = broadcast.commentator(in: appModel.language) {
                Label {
                    Text("match.broadcast.commentator")
                    + Text(verbatim: ": \(commentator)")
                } icon: {
                    Image(systemName: "mic.fill")
                }
                .font(.subheadline)
            }

            if let audioLanguage = broadcast.audioLanguageName(in: appModel.language) {
                Label {
                    Text("match.broadcast.audioLanguage")
                    + Text(verbatim: ": \(audioLanguage)")
                } icon: {
                    Image(systemName: "waveform")
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var fixtureContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "match.content.title")
            switch fixtureContentState {
            case .idle, .loading:
                LoadStateView(state: .loading)
            case .failed:
                LoadStateView(state: .error) {
                    Task { await loadFixtureContent(force: true) }
                }
                .accessibilityFocused($fixtureContentErrorFocused)
            case let .loaded(content, freshness):
                if let freshness {
                    PublicContentStatusView(
                        freshness: freshness,
                        identifier: "match-content"
                    )
                }
                if content.moments.isEmpty, content.articles.isEmpty {
                    ContentUnavailableView(
                        "match.content.emptyTitle",
                        systemImage: "play.rectangle.on.rectangle",
                        description: Text("match.content.emptyBody")
                    )
                    .accessibilityIdentifier("matchCenter.content.empty")
                } else {
                    if !content.moments.isEmpty {
                        matchMoments(content.moments)
                    }
                    if !content.articles.isEmpty {
                        matchReports(content.articles)
                    }
                }
            }
        }
        .accessibilityIdentifier("matchCenter.content")
    }

    @ViewBuilder
    private func matchMoments(_ moments: [FixtureContentMoment]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("match.content.moments")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    ForEach(moments) { moment in
                        matchMomentLink(moment)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(moments) { moment in
                            matchMomentLink(moment)
                                .frame(width: 252)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .accessibilityIdentifier("matchCenter.content.moments")
    }

    private func matchMomentLink(_ moment: FixtureContentMoment) -> some View {
        NavigationLink {
            VideoDetailView(video: moment.video)
        } label: {
            FixtureContentMomentCard(moment: moment)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("matchCenter.moment.\(moment.id)")
    }

    private func matchReports(_ articles: [Article]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("match.content.reports")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            ForEach(articles) { article in
                NavigationLink {
                    ArticleDetailView(article: article)
                } label: {
                    ArticleCard(article: article)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier("matchCenter.content.reports")
    }

    private func summaryTile(
        icon: String,
        title: LocalizedStringKey,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func timeline(_ events: [FixtureEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "match.timeline")

            if events.isEmpty {
                ContentUnavailableView("match.noEvents", systemImage: "clock.arrow.circlepath")
            } else {
                ForEach(events.reversed()) { event in
                    EventRow(event: event)
                }
            }
        }
    }

    private func lineups(_ details: MatchDetails) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "match.lineups")

            if details.homeLineup.isEmpty, details.awayLineup.isEmpty {
                ContentUnavailableView(
                    "match.lineups.empty.title",
                    systemImage: "person.3.sequence",
                    description: Text(emptyLineupBodyKey(for: details.fixture.state))
                )
                .accessibilityIdentifier("matchCenter.lineups.empty")
            } else {
                if details.homeLineup.isEmpty || details.awayLineup.isEmpty {
                    Label("match.lineups.partial", systemImage: "exclamationmark.triangle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                        .accessibilityIdentifier("matchCenter.lineups.partial")
                }
                lineupSection(team: details.fixture.homeTeam, lineup: details.homeLineup)
                lineupSection(team: details.fixture.awayTeam, lineup: details.awayLineup)
            }
        }
        .accessibilityIdentifier("matchCenter.lineups.content")
    }

    private func lineupSection(team: Team, lineup: TeamLineup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TeamLineupHeader(
                team: team,
                formation: lineup.formation,
                language: appModel.language
            )

            if lineup.isEmpty {
                Label("match.lineups.teamUnavailable", systemImage: "person.3")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .frame(minHeight: 44)
            } else {
                if let lines = lineup.pitchLines {
                    if !dynamicTypeSize.isAccessibilitySize {
                        FormationPitchView(lines: lines)
                    }
                } else {
                    let noticeKey: LocalizedStringKey = lineup.hasCompleteStartingEleven
                        ? "match.lineups.formationUnavailable"
                        : "match.lineups.partialTeam"
                    Label {
                        Text(noticeKey)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                }

                lineupList(title: "match.lineups.starting", players: lineup.starters)
                if !lineup.substitutes.isEmpty {
                    Divider()
                    lineupList(title: "match.lineups.substitutes", players: lineup.substitutes)
                }
            }
        }
        .sportsCard()
        .accessibilityIdentifier("matchCenter.lineups.team.\(team.id)")
    }

    private func lineupList(
        title: LocalizedStringKey,
        players: [LineupPlayer]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.muted)
                .accessibilityAddTraits(.isHeader)
            ForEach(players) { player in
                LineupPlayerRow(player: player)
            }
        }
    }

    private func statistics(_ details: MatchDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "match.statistics")

            if details.statistics.isEmpty {
                ContentUnavailableView(
                    "match.statistics.empty.title",
                    systemImage: "chart.bar.xaxis",
                    description: Text(emptyStatisticsBodyKey(for: details.fixture.state))
                )
                .accessibilityIdentifier("matchCenter.statistics.empty")
            } else {
                StatisticsTeamHeader(
                    homeTeam: details.fixture.homeTeam,
                    awayTeam: details.fixture.awayTeam,
                    language: appModel.language
                )
                ForEach(details.statistics) { statistic in
                    StatisticRow(
                        statistic: statistic,
                        homeTeamName: details.fixture.homeTeam.displayName(in: appModel.language),
                        awayTeamName: details.fixture.awayTeam.displayName(in: appModel.language),
                        locale: appModel.language.locale
                    )
                }
            }
        }
        .accessibilityIdentifier("matchCenter.statistics.content")
    }

    private func emptyLineupBodyKey(for state: FixtureState) -> LocalizedStringKey {
        state == .upcoming
            ? "match.lineups.empty.upcoming"
            : "match.lineups.empty.unavailable"
    }

    private func emptyStatisticsBodyKey(for state: FixtureState) -> LocalizedStringKey {
        state == .upcoming
            ? "match.statistics.empty.upcoming"
            : "match.statistics.empty.unavailable"
    }

    @ViewBuilder
    private func standingsContent(_ fixture: Fixture) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "match.standings")
            switch standingsState {
            case .idle, .loading:
                LoadStateView(state: .loading)
            case .failed:
                LoadStateView(state: .error) {
                    Task { await loadStandings(for: fixture, force: true) }
                }
                .accessibilityFocused($standingsErrorFocused)
            case let .loaded(context, freshness):
                if let freshness {
                    PublicContentStatusView(
                        freshness: freshness,
                        identifier: "match-standings"
                    )
                }
                Label {
                    Text(context.season.displayName(in: appModel.language))
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                Label(
                    "match.context.fixtureTeam",
                    systemImage: "smallcircle.filled.circle"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

                if context.groups.isEmpty {
                    ContentUnavailableView(
                        "match.standings.emptyTitle",
                        systemImage: "tablecells",
                        description: Text("match.standings.emptyBody")
                    )
                    .accessibilityIdentifier("matchCenter.standings.empty")
                } else {
                    StandingsTableView(
                        groups: context.groups,
                        highlightedTeamIDs: Set([
                            fixture.homeTeam.id,
                            fixture.awayTeam.id
                        ])
                    )
                    .accessibilityIdentifier("matchCenter.standings.loaded")
                }
                contextSourceFooter(
                    sourceName: context.sourceName,
                    updatedAt: context.updatedAt
                )
            }
        }
    }

    @ViewBuilder
    private func headToHeadContent(_ fixture: Fixture) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "match.headToHead")
            switch headToHeadState {
            case .idle, .loading:
                LoadStateView(state: .loading)
            case .failed:
                LoadStateView(state: .error) {
                    Task { await loadHeadToHead(for: fixture, force: true) }
                }
                .accessibilityFocused($headToHeadErrorFocused)
            case let .loaded(context, freshness):
                if let freshness {
                    PublicContentStatusView(
                        freshness: freshness,
                        identifier: "match-head-to-head"
                    )
                }
                Label("match.h2h.scope", systemImage: "square.stack.3d.up")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)

                if context.meetings.isEmpty {
                    ContentUnavailableView(
                        "match.h2h.emptyTitle",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("match.h2h.emptyBody")
                    )
                    .accessibilityIdentifier("matchCenter.headToHead.empty")
                } else {
                    headToHeadSummary(context)
                    VStack(spacing: 12) {
                        ForEach(context.meetings) { meeting in
                            headToHeadMeeting(meeting)
                        }
                    }
                    .accessibilityIdentifier("matchCenter.headToHead.loaded")
                }
                contextSourceFooter(
                    sourceName: context.sourceName,
                    updatedAt: context.updatedAt
                )
            }
        }
    }

    private func headToHeadSummary(_ context: FixtureHeadToHeadContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    format: String(
                        localized: "match.h2h.lastMeetings",
                        locale: appModel.language.locale
                    ),
                    context.meetings.count
                )
            )
            .font(.headline)
            headToHeadRecordRow(
                team: context.homeTeam,
                record: context.record(for: context.homeTeam.id)
            )
            Divider()
            headToHeadRecordRow(
                team: context.awayTeam,
                record: context.record(for: context.awayTeam.id)
            )
        }
        .sportsCard()
    }

    private func headToHeadRecordRow(
        team: Team,
        record: HeadToHeadRecord
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        TeamBadge(team: team, size: 34)
                        Text(team.displayName(in: appModel.language))
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(headToHeadRecordText(record))
                        .font(.caption.monospacedDigit().weight(.bold))
                }
            } else {
                HStack(spacing: 10) {
                    TeamBadge(team: team, size: 34)
                    Text(team.displayName(in: appModel.language))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(headToHeadRecordText(record))
                        .font(.caption.monospacedDigit().weight(.bold))
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(team.displayName(in: appModel.language)))
        .accessibilityValue(Text(headToHeadRecordAccessibilityText(record)))
    }

    private func headToHeadMeeting(_ meeting: Fixture) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(meeting.competition.displayName(in: appModel.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                Spacer(minLength: 8)
                Text(meeting.kickoff, format: .dateTime.day().month().year())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.muted)
            }
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(meeting.homeTeam.displayName(in: appModel.language))
                            .font(.subheadline.weight(.semibold))
                        Text(meeting.scoreText ?? "–")
                            .font(.headline.monospacedDigit().weight(.black))
                        Text(meeting.awayTeam.displayName(in: appModel.language))
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    HStack(spacing: 10) {
                        Text(meeting.homeTeam.displayName(in: appModel.language))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(meeting.scoreText ?? "–")
                            .font(.headline.monospacedDigit().weight(.black))
                        Text(meeting.awayTeam.displayName(in: appModel.language))
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            Label("match.finished", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
    }

    private func headToHeadRecordText(_ record: HeadToHeadRecord) -> String {
        String(
            format: String(
                localized: "match.h2h.record",
                locale: appModel.language.locale
            ),
            record.wins,
            record.draws,
            record.losses
        )
    }

    private func headToHeadRecordAccessibilityText(
        _ record: HeadToHeadRecord
    ) -> String {
        String(
            format: String(
                localized: "match.h2h.recordAccessibility",
                locale: appModel.language.locale
            ),
            record.wins,
            record.draws,
            record.losses
        )
    }

    private func contextSourceFooter(
        sourceName: String,
        updatedAt: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("match.source")
                .font(.caption.weight(.semibold))
            Text(sourceName)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            Text(updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func sourceFooter(_ details: MatchDetails) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("match.source")
                .font(.caption.weight(.semibold))
            Text(details.sourceName)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            Text(details.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    @MainActor
    private func load(announceFreshness: Bool = false) async -> Bool {
        let requestID = UUID()
        loadRequestID = requestID
        failed = false
        var loaded = false
        do {
            let loadedDetails = try await appModel.dataProvider.fixtureDetails(id: fixtureID)
            guard loadRequestID == requestID, !Task.isCancelled else { return false }
            if var current = timeline {
                _ = try current.replace(with: loadedDetails)
                timeline = current
            } else {
                timeline = try MatchLiveTimeline(snapshot: loadedDetails)
            }
            loaded = true
        } catch is CancellationError {
            return false
        } catch {
            guard loadRequestID == requestID, !Task.isCancelled else { return false }
            failed = true
        }
        let updated = await appModel.publicContentFreshness(
            for: .fixture(id: fixtureID)
        )
        guard loadRequestID == requestID, !Task.isCancelled else { return false }
        freshness = updated
        if loaded {
            await synchronizeLiveActivityIfNeeded()
        }
        if announceFreshness || updated?.requiresAttention == true {
            freshnessFocused = false
            await Task.yield()
            guard loadRequestID == requestID, !Task.isCancelled else { return false }
            freshnessFocused = updated != nil
        }
        return loaded
    }

    @MainActor
    private func manualRefresh() async {
        async let content: Void = loadFixtureContent(force: true)
        let loaded = await load(announceFreshness: true)
        _ = await content
        if loaded {
            await refreshSelectedContext()
        }
        let nextGeneration = liveSessionGeneration + 1
        skipSnapshotForGeneration = nextGeneration
        liveSessionGeneration = nextGeneration
    }

    @MainActor
    private func restartLiveSession() {
        skipSnapshotForGeneration = nil
        liveSessionGeneration += 1
    }

    @MainActor
    private func loadSelectedContextIfNeeded() async {
        guard let fixture = details?.fixture else { return }
        switch selectedTab {
        case .standings:
            await loadStandings(for: fixture)
        case .headToHead:
            await loadHeadToHead(for: fixture)
        case .summary, .timeline, .lineups, .statistics:
            return
        }
    }

    @MainActor
    private func refreshSelectedContext() async {
        guard let fixture = details?.fixture else { return }
        switch selectedTab {
        case .standings:
            await loadStandings(for: fixture, force: true)
        case .headToHead:
            await loadHeadToHead(for: fixture, force: true)
        case .summary, .timeline, .lineups, .statistics:
            return
        }
    }

    @MainActor
    private func loadFixtureContent(force: Bool = false) async {
        if case .loading = fixtureContentState { return }
        if !force, case .loaded = fixtureContentState { return }
        let previousState = fixtureContentState
        let requestID = UUID()
        fixtureContentRequestID = requestID
        fixtureContentState = .loading
        do {
            let content = try await appModel.dataProvider.fixtureContent(id: fixtureID)
            guard fixtureContentRequestID == requestID, !Task.isCancelled else { return }
            let freshness = await appModel.publicContentFreshness(
                for: .fixtureContent(id: fixtureID)
            )
            guard fixtureContentRequestID == requestID, !Task.isCancelled else { return }
            fixtureContentState = .loaded(content, freshness)
        } catch is CancellationError {
            guard fixtureContentRequestID == requestID else { return }
            fixtureContentState = previousState
        } catch {
            guard fixtureContentRequestID == requestID, !Task.isCancelled else { return }
            fixtureContentState = .failed
            guard selectedTab == .summary else { return }
            fixtureContentErrorFocused = false
            await Task.yield()
            guard fixtureContentRequestID == requestID, !Task.isCancelled else { return }
            fixtureContentErrorFocused = true
        }
    }

    @MainActor
    private func loadStandings(
        for fixture: Fixture,
        force: Bool = false
    ) async {
        if case .loading = standingsState { return }
        if !force, case .loaded = standingsState { return }
        let previousState = standingsState
        let requestID = UUID()
        standingsRequestID = requestID
        standingsState = .loading
        do {
            let context = try await appModel.dataProvider.fixtureStandings(for: fixture)
            guard standingsRequestID == requestID, !Task.isCancelled else { return }
            let freshness = await appModel.publicContentFreshness(
                for: .fixtureStandings(id: fixture.id)
            )
            guard standingsRequestID == requestID, !Task.isCancelled else { return }
            standingsState = .loaded(context, freshness)
        } catch is CancellationError {
            guard standingsRequestID == requestID else { return }
            standingsState = previousState
        } catch {
            guard standingsRequestID == requestID, !Task.isCancelled else { return }
            standingsState = .failed
            guard selectedTab == .standings else { return }
            standingsErrorFocused = false
            await Task.yield()
            guard standingsRequestID == requestID, !Task.isCancelled else { return }
            standingsErrorFocused = true
        }
    }

    @MainActor
    private func loadHeadToHead(
        for fixture: Fixture,
        force: Bool = false
    ) async {
        if case .loading = headToHeadState { return }
        if !force, case .loaded = headToHeadState { return }
        let previousState = headToHeadState
        let requestID = UUID()
        headToHeadRequestID = requestID
        headToHeadState = .loading
        do {
            let context = try await appModel.dataProvider.fixtureHeadToHead(
                for: fixture,
                limit: 10
            )
            guard headToHeadRequestID == requestID, !Task.isCancelled else { return }
            let freshness = await appModel.publicContentFreshness(
                for: .fixtureHeadToHead(id: fixture.id)
            )
            guard headToHeadRequestID == requestID, !Task.isCancelled else { return }
            headToHeadState = .loaded(context, freshness)
        } catch is CancellationError {
            guard headToHeadRequestID == requestID else { return }
            headToHeadState = previousState
        } catch {
            guard headToHeadRequestID == requestID, !Task.isCancelled else { return }
            headToHeadState = .failed
            guard selectedTab == .headToHead else { return }
            headToHeadErrorFocused = false
            await Task.yield()
            guard headToHeadRequestID == requestID, !Task.isCancelled else { return }
            headToHeadErrorFocused = true
        }
    }

    @MainActor
    private func runLiveSession(generation: Int) async {
        guard scenePhase == .active else {
            if timeline != nil {
                await setLivePhase(.paused)
            }
            return
        }

        if skipSnapshotForGeneration == generation {
            skipSnapshotForGeneration = nil
        } else {
            _ = await load()
        }
        guard !Task.isCancelled else { return }
        guard let fixture = timeline?.details.fixture else {
            await setLivePhase(.unavailable)
            return
        }
        guard MatchLivePollingPolicy.allowsIncrementalUpdates(
            after: freshness?.source
        ) else {
            // Never merge a recovered real-world batch into a fictional
            // full-snapshot fallback. Retry must first obtain a real snapshot.
            await setLivePhase(.unavailable)
            return
        }
        if let terminal = terminalPhase(for: fixture.state) {
            await setLivePhase(terminal)
            return
        }
        await setLivePhase(initialLivePhase(for: fixture))
        await pollForLiveUpdates()
    }

    @MainActor
    private func pollForLiveUpdates() async {
        var retryAttempt = 0

        while !Task.isCancelled, scenePhase == .active {
            guard let currentDetails = timeline?.details else { return }
            guard MatchLivePollingPolicy.interval(
                for: currentDetails.fixture,
                now: Date()
            ) != nil else {
                await setLivePhase(
                    terminalPhase(for: currentDetails.fixture.state) ?? .stopped
                )
                return
            }

            do {
                let previousScore = currentDetails.fixture.scoreText
                let batch = try await appModel.dataProvider.fixtureEventUpdates(
                    id: fixtureID,
                    afterRevision: currentDetails.fixture.revision
                )
                guard !Task.isCancelled else { return }
                guard var updatedTimeline = timeline else { return }
                let changes = try updatedTimeline.apply(batch)
                timeline = updatedTimeline
                failed = false
                retryAttempt = 0
                await updateFreshnessAfterLiveAttempt()
                let updatedDetails = updatedTimeline.details
                await synchronizeLiveActivityIfNeeded(updatedDetails)
                announceLiveChanges(
                    changes,
                    previousScore: previousScore,
                    details: updatedDetails
                )

                if let terminal = terminalPhase(for: updatedDetails.fixture.state) {
                    await setLivePhase(terminal)
                    return
                }
                await setLivePhase(
                    successPhase(for: updatedDetails.fixture, at: batch.updatedAt)
                )
                guard let nextInterval = MatchLivePollingPolicy.interval(
                    for: updatedDetails.fixture,
                    now: Date()
                ) else {
                    await setLivePhase(
                        terminalPhase(for: updatedDetails.fixture.state) ?? .stopped
                    )
                    return
                }
                guard await sleep(seconds: nextInterval) else { return }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await updateFreshnessAfterLiveAttempt()
                let dataError = SportsDataError.normalized(error)
                guard dataError.isRecoverableForFallback else {
                    await setLivePhase(.unavailable)
                    return
                }
                retryAttempt += 1
                await setLivePhase(.retrying(attempt: retryAttempt))
                let delay = MatchLivePollingPolicy.retryDelay(forAttempt: retryAttempt)
                guard await sleep(seconds: delay) else { return }
            }
        }
    }

    @MainActor
    private func updateFreshnessAfterLiveAttempt() async {
        let updated = await appModel.publicContentFreshness(
            for: .fixture(id: fixtureID)
        )
        guard !Task.isCancelled else { return }
        freshness = updated
    }

    @MainActor
    private func setLivePhase(_ phase: MatchLiveUpdatePhase) async {
        let previous = livePhase
        guard previous != phase else { return }
        livePhase = phase
        let shouldFocus = phase == .unavailable
            || (phase.requiresAttention && !previous.requiresAttention)
        guard shouldFocus else { return }
        liveStatusFocused = false
        await Task.yield()
        guard !Task.isCancelled else { return }
        liveStatusFocused = true
    }

    private func initialLivePhase(for fixture: Fixture) -> MatchLiveUpdatePhase {
        fixture.state == .upcoming
            ? .waitingForKickoff(lastCheckedAt: nil)
            : .connecting
    }

    private func successPhase(
        for fixture: Fixture,
        at updatedAt: Date
    ) -> MatchLiveUpdatePhase {
        fixture.state == .upcoming
            ? .waitingForKickoff(lastCheckedAt: updatedAt)
            : .connected(lastUpdatedAt: updatedAt)
    }

    private func terminalPhase(for state: FixtureState) -> MatchLiveUpdatePhase? {
        switch state {
        case .finished:
            .ended
        case .postponed, .cancelled:
            .stopped
        case .upcoming, .live, .halfTime:
            nil
        }
    }

    private func sleep(seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    @MainActor
    private func announceLiveChanges(
        _ changes: [FixtureEventChange],
        previousScore: String?,
        details: MatchDetails
    ) {
        guard UIAccessibility.isVoiceOverRunning else { return }

        let hasCorrection = changes.contains {
            if case .corrected = $0 { return true }
            if case .deleted = $0 { return true }
            return false
        }
        let message: String?
        if hasCorrection {
            message = String(
                localized: "match.live.timelineCorrectedAnnouncement",
                locale: appModel.language.locale
            )
        } else if let event = changes.compactMap({ change -> FixtureEvent? in
            guard case let .inserted(event) = change else { return nil }
            return [.goal, .ownGoal, .penalty, .redCard, .halfTime, .fullTime]
                .contains(event.kind) ? event : nil
        }).last {
            message = [
                event.title(in: appModel.language),
                details.fixture.scoreText
            ]
            .compactMap { $0 }
            .joined(separator: ". ")
        } else if previousScore != details.fixture.scoreText {
            message = [
                String(
                    localized: "match.live.scoreUpdatedAnnouncement",
                    locale: appModel.language.locale
                ),
                details.fixture.scoreText
            ]
            .compactMap { $0 }
            .joined(separator: ". ")
        } else {
            message = nil
        }

        if let message, !message.isEmpty {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

private enum MatchContextLoadState<Value> {
    case idle
    case loading
    case loaded(Value, PublicContentFreshness?)
    case failed
}

private struct FixtureContentMomentCard: View {
    @EnvironmentObject private var appModel: AppModel
    let moment: FixtureContentMoment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [AppTheme.ink, AppTheme.accent.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(alignment: .bottom) {
                    if let minute = moment.minute {
                        Text("\(minute)′")
                            .font(.headline.monospacedDigit().weight(.black))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(AppTheme.warm)
                            .clipShape(Capsule())
                    } else {
                        StatusPill(
                            text: LocalizedStringKey(moment.video.type.localizationKey),
                            color: AppTheme.warm
                        )
                    }
                    Spacer(minLength: 8)
                    Text(moment.video.durationText)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.72))
                        .clipShape(Capsule())
                }
                .padding(12)
            }
            .frame(minHeight: 118)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)

            Text(moment.title(in: appModel.language))
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.leading)

            Text(moment.video.title(in: appModel.language))
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            if !moment.video.isPlayable {
                Label(
                    LocalizedStringKey(
                        (moment.video.availabilityReason ?? .unavailable).localizationKey
                    ),
                    systemImage: "lock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(
            Text(
                moment.video.isPlayable
                    ? LocalizedStringKey("")
                    : LocalizedStringKey(
                        (moment.video.availabilityReason ?? .unavailable).localizationKey
                    )
            )
        )
        .accessibilityHint(Text("accessibility.opensVideo"))
    }

    private var accessibilityLabel: String {
        let minuteText = moment.minute.map { minute in
            String(
                format: String(
                    localized: "match.content.minuteAccessibility",
                    locale: appModel.language.locale
                ),
                minute
            )
        }
        return [
            minuteText,
            moment.title(in: appModel.language),
            moment.video.title(in: appModel.language)
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }
}

private struct EventRow: View {
    @EnvironmentObject private var appModel: AppModel
    let event: FixtureEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(minuteText)
                .font(.subheadline.monospacedDigit().weight(.black))
                .frame(width: 44)
                .frame(minHeight: 44)

            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title(in: appModel.language))
                    .font(.subheadline.weight(.bold))
                Text(event.detail(in: appModel.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
    }

    private var minuteText: String {
        if let addedTime = event.addedTime, addedTime > 0 {
            return "\(event.minute)+\(addedTime)′"
        }
        return "\(event.minute)′"
    }

    private var icon: String {
        switch event.kind {
        case .kickoff: "sportscourt"
        case .goal, .ownGoal, .penalty: "soccerball"
        case .yellowCard: "rectangle.fill"
        case .redCard: "rectangle.fill"
        case .substitution: "arrow.left.arrow.right"
        case .halfTime: "pause.circle.fill"
        case .fullTime: "checkmark.circle.fill"
        case .varReview: "video.fill"
        }
    }

    private var iconColor: Color {
        switch event.kind {
        case .goal, .penalty: AppTheme.accent
        case .ownGoal, .redCard: AppTheme.live
        case .yellowCard: AppTheme.warm
        default: AppTheme.muted
        }
    }
}

private struct StatisticRow: View {
    let statistic: MatchStatistic
    let homeTeamName: String
    let awayTeamName: String
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var total: Double {
        max(statistic.homeValue + statistic.awayValue, 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                Text(LocalizedStringKey(statistic.titleKey))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                HStack(alignment: .top, spacing: 16) {
                    accessibleValue(team: homeTeamName, value: statistic.homeValue)
                    Spacer(minLength: 8)
                    accessibleValue(team: awayTeamName, value: statistic.awayValue)
                }
            } else {
                HStack {
                    Text(formatted(statistic.homeValue))
                        .font(.subheadline.monospacedDigit().weight(.bold))
                    Spacer()
                    Text(LocalizedStringKey(statistic.titleKey))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text(formatted(statistic.awayValue))
                        .font(.subheadline.monospacedDigit().weight(.bold))
                }
            }

            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width - 4, 0)
                HStack(spacing: 4) {
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: availableWidth * CGFloat(statistic.homeValue / total))
                    Capsule()
                        .fill(AppTheme.warm)
                        .frame(width: availableWidth * CGFloat(statistic.awayValue / total))
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .sportsCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(statistic.titleKey)))
        .accessibilityValue(
            Text(verbatim: "\(homeTeamName): \(formatted(statistic.homeValue)); \(awayTeamName): \(formatted(statistic.awayValue))")
        )
        .accessibilityIdentifier("matchCenter.statistic.\(statistic.id)")
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 1
        if statistic.unit == "%" {
            formatter.numberStyle = .percent
            return formatter.string(from: NSNumber(value: value / 100)) ?? "\(value)%"
        }
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func accessibleValue(team: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(team)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            Text(formatted(value))
                .font(.headline.monospacedDigit())
        }
    }
}

private struct TeamLineupHeader: View {
    let team: Team
    let formation: String?
    let language: AppLanguage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    teamIdentity
                    formationBadge
                }
            } else {
                HStack {
                    teamIdentity
                    Spacer(minLength: 8)
                    formationBadge
                }
            }
        }
    }

    private var teamIdentity: some View {
        HStack(spacing: 8) {
            TeamBadge(team: team, size: 34)
            Text(team.displayName(in: language))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var formationBadge: some View {
        if let formation {
            Label {
                Text(formation)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "rectangle.split.3x3")
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(AppTheme.accent.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel(Text("match.lineups.formation"))
            .accessibilityValue(Text(verbatim: formation))
        }
    }
}

private struct StatisticsTeamHeader: View {
    let homeTeam: Team
    let awayTeam: Team
    let language: AppLanguage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    team(homeTeam)
                    team(awayTeam)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    team(homeTeam)
                    Spacer(minLength: 12)
                    team(awayTeam)
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
    }

    private func team(_ team: Team) -> some View {
        HStack(spacing: 8) {
            TeamBadge(team: team, size: 28)
            Text(team.displayName(in: language))
                .font(.caption.weight(.bold))
                .lineLimit(2)
        }
    }
}

private struct LineupPlayerRow: View {
    let player: LineupPlayer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            Text(player.number, format: .number)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .frame(width: 30, height: 30)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(Circle())
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.name)
                        .font(.subheadline.weight(.semibold))
                    Text(LocalizedStringKey(player.positionKey))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(LocalizedStringKey(player.positionKey))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("matchCenter.lineup.player.\(player.id)")
    }
}

private struct FormationPitchView: View {
    let lines: [[LineupPlayer]]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.32, blue: 0.23))
                PitchMarkings()
                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
                    .padding(10)

                ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, line in
                    ForEach(line) { player in
                        let playerIndex = player.formationPosition?.order ?? 0
                        let labelWidth = min(
                            64,
                            max(40, proxy.size.width / CGFloat(line.count) - 6)
                        )
                        pitchPlayer(player, labelWidth: labelWidth)
                            .position(
                                x: proxy.size.width * CGFloat(playerIndex + 1) / CGFloat(line.count + 1),
                                y: verticalPosition(
                                    lineIndex: lineIndex,
                                    height: proxy.size.height
                                )
                            )
                    }
                }
            }
        }
        .frame(height: 420)
        .accessibilityHidden(true)
    }

    private func pitchPlayer(_ player: LineupPlayer, labelWidth: CGFloat) -> some View {
        VStack(spacing: 3) {
            Text(player.number, format: .number)
                .font(.caption.monospacedDigit().weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 32, height: 32)
                .background(.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2))
            Text(player.name)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: labelWidth)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
        }
    }

    private func verticalPosition(lineIndex: Int, height: CGFloat) -> CGFloat {
        let denominator = max(lines.count - 1, 1)
        let progress = CGFloat(lineIndex) / CGFloat(denominator)
        return height * (0.88 - progress * 0.76)
    }
}

private struct PitchMarkings: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 12, height: 12))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        let circleSize = min(rect.width * 0.32, rect.height * 0.18)
        path.addEllipse(
            in: CGRect(
                x: rect.midX - circleSize / 2,
                y: rect.midY - circleSize / 2,
                width: circleSize,
                height: circleSize
            )
        )
        let boxWidth = rect.width * 0.58
        let boxHeight = rect.height * 0.14
        path.addRect(
            CGRect(
                x: rect.midX - boxWidth / 2,
                y: rect.minY,
                width: boxWidth,
                height: boxHeight
            )
        )
        path.addRect(
            CGRect(
                x: rect.midX - boxWidth / 2,
                y: rect.maxY - boxHeight,
                width: boxWidth,
                height: boxHeight
            )
        )
        return path
    }
}
