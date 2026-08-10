import Foundation
import SwiftUI

struct PlayerDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let playerID: String
    let previewName: String?

    @State private var details: PlayerDetails?
    @State private var transfers: [PlayerTransfer]?
    @State private var playerContent: PlayerContent?
    @State private var contentFreshness: PublicContentFreshness?
    @State private var loadFailed = false
    @State private var transfersFailed = false
    @State private var contentFailed = false
    @State private var coreRequestID = UUID()
    @State private var transferRequestID = UUID()
    @State private var contentRequestID = UUID()
    @AccessibilityFocusState private var contentErrorFocused: Bool

    init(player: PlayerProfile) {
        playerID = player.id
        previewName = player.name
    }

    init(playerID: String, previewName: String? = nil) {
        self.playerID = playerID
        self.previewName = previewName
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
        .navigationTitle(previewName ?? String(localized: "player.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let name = details?.player.name ?? previewName {
                    SportsShareButton(
                        route: .player(playerID),
                        fallbackText: name,
                        accessibilityHint: "accessibility.sharesPlayer"
                    )
                }
            }
        }
        .task(id: playerID) { await load() }
    }

    private func content(_ details: PlayerDetails) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                playerHeader(details.player)
                currentTeamSection(details.currentTeam)
                statisticsSection(details.statistics)
                editorialContentSection
                transfersSection
            }
            .padding(16)
        }
        .refreshable { await load() }
        .accessibilityIdentifier("player.detail")
    }

    private var editorialContentSection: some View {
        EntityEditorialContentSection(
            scope: .player,
            articles: playerContent?.articles,
            videos: playerContent?.videos,
            freshness: contentFreshness,
            loadFailed: contentFailed,
            isLoading: playerContent == nil && !contentFailed
        ) {
            Task { await loadPlayerContent() }
        }
        .accessibilityFocused($contentErrorFocused)
    }

    private func playerHeader(_ player: PlayerProfile) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 82))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
            Text(player.name)
                .font(.largeTitle.weight(.black))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(player.position)
                .font(.headline)
                .foregroundStyle(AppTheme.muted)
            SportsFollowButton(
                type: .player,
                entityID: player.id,
                entity: .player(player),
                accessibilityIdentifier: "player.follow"
            )
            ContextualAlertSettingsButton(
                target: .entity(.player(player)),
                accessibilityIdentifier: "player.alerts"
            )
        }
        .frame(maxWidth: .infinity)
        .sportsCard()
    }

    @ViewBuilder
    private func currentTeamSection(_ team: Team?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "player.currentTeam")
            if let team {
                NavigationLink {
                    TeamDetailView(team: team)
                } label: {
                    HStack(spacing: 12) {
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
                }
                .buttonStyle(.plain)
            } else {
                Text("player.freeAgent")
                    .foregroundStyle(AppTheme.muted)
                    .sportsCard()
            }
        }
    }

    @ViewBuilder
    private func statisticsSection(_ statistics: [NamedStatistic]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "player.statistics")
            if statistics.isEmpty {
                Text("player.noStatistics")
                    .foregroundStyle(AppTheme.muted)
                    .sportsCard()
            } else {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible()),
                        count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                    ),
                    spacing: 12
                ) {
                    ForEach(statistics) { statistic in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(statistic.name)
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                            Text(statistic.value, format: .number.precision(.fractionLength(0...2)))
                                .font(.title2.monospacedDigit().weight(.black))
                        }
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .sportsCard()
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var transfersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "player.transfers")
            if transfersFailed {
                Label("common.refreshFailed", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warm)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .sportsCard()
            } else if transfers == nil {
                LoadStateView(state: .loading)
            } else if let transfers, transfers.isEmpty {
                Text("player.noTransfers")
                    .foregroundStyle(AppTheme.muted)
                    .sportsCard()
            } else if let transfers {
                ForEach(transfers) { transfer in
                    transferRow(transfer)
                }
            }
        }
    }

    private func transferRow(_ transfer: PlayerTransfer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    LocalizedStringKey(transfer.status.localizationKey),
                    systemImage: transfer.status == .completed ? "checkmark.circle.fill" : "clock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(transfer.status == .completed ? AppTheme.accent : AppTheme.warm)
                Spacer(minLength: 0)
                Text(transfer.transferDate, format: .dateTime.day().month().year())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.muted)
            }

            HStack(spacing: 10) {
                transferTeam(transfer.fromTeam, fallbackKey: "transfer.unknownOrigin")
                Image(systemName: "arrow.forward")
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)
                transferTeam(transfer.toTeam, fallbackKey: "transfer.unknownDestination")
            }
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
    }

    private func transferTeam(_ team: Team?, fallbackKey: LocalizedStringKey) -> some View {
        Group {
            if let team {
                Text(team.displayName(in: appModel.language))
            } else {
                Text(fallbackKey)
            }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    @MainActor
    private func load() async {
        async let core: Void = loadCore()
        async let transfers: Void = loadTransfers()
        async let content: Void = loadPlayerContent()
        _ = await (core, transfers, content)
    }

    @MainActor
    private func loadCore() async {
        let requestID = UUID()
        coreRequestID = requestID
        loadFailed = false
        if details?.player.id != playerID {
            details = nil
        }
        do {
            let loaded = try await appModel.dataProvider.playerDetails(id: playerID)
            guard coreRequestID == requestID,
                  loaded.player.id == playerID,
                  !Task.isCancelled else { return }
            details = loaded
        } catch is CancellationError {
            return
        } catch {
            guard coreRequestID == requestID else { return }
            loadFailed = true
        }
    }

    @MainActor
    private func loadTransfers() async {
        let requestID = UUID()
        transferRequestID = requestID
        transfersFailed = false
        transfers = nil
        do {
            let loaded = try await appModel.dataProvider.playerTransfers(id: playerID)
            guard transferRequestID == requestID, !Task.isCancelled else { return }
            transfers = loaded
        } catch is CancellationError {
            return
        } catch {
            guard transferRequestID == requestID else { return }
            transfersFailed = true
        }
    }

    @MainActor
    private func loadPlayerContent() async {
        let requestID = UUID()
        contentRequestID = requestID
        contentFailed = false
        contentErrorFocused = false
        contentFreshness = nil
        if playerContent?.playerID != playerID {
            playerContent = nil
        }
        do {
            let loaded = try await appModel.dataProvider.playerContent(id: playerID)
            guard contentRequestID == requestID,
                  loaded.playerID == playerID,
                  !Task.isCancelled else { return }
            playerContent = loaded
        } catch is CancellationError {
            return
        } catch {
            guard contentRequestID == requestID else { return }
            contentFailed = true
            contentErrorFocused = true
        }
        let freshness = await appModel.publicContentFreshness(
            for: .playerContent(id: playerID)
        )
        guard contentRequestID == requestID, !Task.isCancelled else { return }
        contentFreshness = freshness
    }
}
