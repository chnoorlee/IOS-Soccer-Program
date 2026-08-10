import SwiftUI

struct TransferCenterView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedFilter: TransferCenterFilter = .all
    @State private var loadedFilter: TransferCenterFilter?
    @State private var feed = TransferCenterFeedState()
    @State private var freshness: PublicContentFreshness?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var loadFailed = false
    @State private var loadMoreFailed = false
    @State private var requestID: UUID?
    @AccessibilityFocusState private var errorFocused: Bool
    @AccessibilityFocusState private var freshnessFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                evidenceBoundary
                filterControls

                if let freshness {
                    PublicContentStatusView(freshness: freshness, identifier: "transfers")
                        .accessibilityFocused($freshnessFocused)
                }

                transferContent
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("transfer.center.title")
        .accessibilityIdentifier("transfer.center.screen")
        .refreshable { await loadInitial(announceFreshness: true) }
        .task(id: selectedFilter) { await loadInitial() }
    }

    private var evidenceBoundary: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.warm)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("transfer.center.promiseTitle")
                    .font(.headline)
                Text("transfer.center.promiseBody")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.ink)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("transfer.center.boundary")
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("transfer.filter.title")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(TransferCenterFilter.allCases) { filter in
                        filterButton(filter, expands: true)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TransferCenterFilter.allCases) { filter in
                            filterButton(filter, expands: false)
                        }
                    }
                }
                .accessibilityIdentifier("transfer.filters.scroll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("transfer.filters")
    }

    private func filterButton(
        _ filter: TransferCenterFilter,
        expands: Bool
    ) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = filter
        } label: {
            Label(
                LocalizedStringKey(filter.localizationKey),
                systemImage: isSelected ? "checkmark.circle.fill" : filterSystemImage(filter)
            )
            .font(.subheadline.weight(.semibold))
            .frame(
                minWidth: 44,
                maxWidth: expands ? .infinity : nil,
                minHeight: 44,
                alignment: .leading
            )
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : filterColor(filter))
            .background(isSelected ? AppTheme.ink : AppTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("transfer.filter.hint"))
        .accessibilityIdentifier("transfer.filter.\(filter.rawValue)")
    }

    @ViewBuilder
    private var transferContent: some View {
        if isLoading && feed.transfers.isEmpty {
            LoadStateView(state: .loading)
                .accessibilityIdentifier("transfer.center.loading")
        } else if loadFailed && feed.transfers.isEmpty {
            LoadStateView(state: .error) {
                Task { await loadInitial(announceFreshness: true) }
            }
            .accessibilityFocused($errorFocused)
            .accessibilityIdentifier("transfer.center.error")
        } else if feed.transfers.isEmpty {
            ContentUnavailableView(
                "transfer.empty.title",
                systemImage: "arrow.left.arrow.right",
                description: Text("transfer.empty.body")
            )
            .accessibilityIdentifier("transfer.center.empty")
        } else {
            if loadFailed {
                inlineFailure(message: "transfer.refreshFailed") {
                    Task { await loadInitial(announceFreshness: true) }
                }
            }

            ForEach(feed.transfers) { transfer in
                NavigationLink {
                    PlayerDetailView(
                        playerID: transfer.player.id,
                        previewName: transfer.player.name
                    )
                } label: {
                    TransferRouteCard(transfer: transfer)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transfer.card.\(transfer.id)")
            }

            if feed.hasMore {
                if loadMoreFailed {
                    inlineFailure(message: "transfer.moreFailed") {
                        Task { await loadMore() }
                    }
                } else {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        if isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .accessibilityLabel(Text("common.loading"))
                        } else {
                            Label("transfer.loadMore", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingMore)
                    .accessibilityIdentifier("transfer.loadMore")
                }
            }
        }
    }

    private func inlineFailure(
        message: LocalizedStringKey,
        retry: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            Spacer(minLength: 0)
            Button("transfer.retry", action: retry)
                .font(.caption.weight(.bold))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(AppTheme.warm.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func filterColor(_ filter: TransferCenterFilter) -> Color {
        switch filter {
        case .all: AppTheme.ink
        case .completed: AppTheme.accent
        case .agreed: AppTheme.warm
        case .rumored: .purple
        }
    }

    private func filterSystemImage(_ filter: TransferCenterFilter) -> String {
        switch filter {
        case .all: "square.grid.2x2.fill"
        case .completed: "checkmark.seal.fill"
        case .agreed: "handshake.fill"
        case .rumored: "questionmark.bubble.fill"
        }
    }

    @MainActor
    private func loadInitial(announceFreshness: Bool = false) async {
        let activeFilter = selectedFilter
        let activeStatus = activeFilter.status
        let activeRequestID = UUID()
        requestID = activeRequestID
        if loadedFilter != activeFilter {
            feed = TransferCenterFeedState()
            freshness = nil
        }
        isLoading = true
        isLoadingMore = false
        loadFailed = false
        loadMoreFailed = false
        errorFocused = false

        do {
            let page = try await appModel.dataProvider.transferUpdates(
                cursor: nil,
                limit: TransferCenterContract.pageSize,
                status: activeStatus
            )
            guard requestID == activeRequestID,
                  selectedFilter == activeFilter,
                  !Task.isCancelled else { return }
            var replacement = TransferCenterFeedState()
            try replacement.replace(with: page, expectedStatus: activeStatus)
            feed = replacement
            loadedFilter = activeFilter
            freshness = await appModel.publicContentFreshness(for: .transfers(status: activeStatus))
            guard requestID == activeRequestID,
                  selectedFilter == activeFilter,
                  !Task.isCancelled else { return }
            isLoading = false
            if announceFreshness || freshness?.requiresAttention == true {
                freshnessFocused = false
                await Task.yield()
                freshnessFocused = freshness != nil
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestID == activeRequestID,
                  selectedFilter == activeFilter else { return }
            freshness = await appModel.publicContentFreshness(for: .transfers(status: activeStatus))
            isLoading = false
            loadFailed = true
            if feed.transfers.isEmpty {
                errorFocused = true
            }
        }
    }

    @MainActor
    private func loadMore() async {
        guard !isLoadingMore,
              let cursor = feed.nextCursor else { return }
        let activeFilter = selectedFilter
        let activeStatus = activeFilter.status
        let activeRequestID = requestID
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await appModel.dataProvider.transferUpdates(
                cursor: cursor,
                limit: TransferCenterContract.pageSize,
                status: activeStatus
            )
            guard requestID == activeRequestID,
                  selectedFilter == activeFilter,
                  !Task.isCancelled else { return }
            var updated = feed
            try updated.append(
                page,
                requestedCursor: cursor,
                expectedStatus: activeStatus
            )
            feed = updated
            freshness = await appModel.publicContentFreshness(for: .transfers(status: activeStatus))
            guard requestID == activeRequestID,
                  selectedFilter == activeFilter,
                  !Task.isCancelled else { return }
            isLoadingMore = false
        } catch is CancellationError {
            return
        } catch {
            guard requestID == activeRequestID,
                  selectedFilter == activeFilter else { return }
            freshness = await appModel.publicContentFreshness(for: .transfers(status: activeStatus))
            isLoadingMore = false
            loadMoreFailed = true
        }
    }
}

private struct TransferRouteCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let transfer: PlayerTransfer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader
            transferRoute

            Text(transfer.transferDate, format: .dateTime.day().month(.wide).year())
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
        .accessibilityHint(Text("transfer.card.hint"))
    }

    @ViewBuilder
    private var cardHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                playerIdentity
                StatusPill(
                    text: LocalizedStringKey(transfer.status.localizationKey),
                    color: statusColor
                )
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                playerIdentity
                Spacer(minLength: 0)
                StatusPill(
                    text: LocalizedStringKey(transfer.status.localizationKey),
                    color: statusColor
                )
            }
        }
    }

    private var playerIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(transfer.player.name)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(transfer.player.position)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var transferRoute: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                expandedRouteTeam(
                    transfer.fromTeam,
                    fallbackKey: "transfer.unknownOrigin"
                )
                Image(systemName: "arrow.down")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.leading, 14)
                    .accessibilityHidden(true)
                expandedRouteTeam(
                    transfer.toTeam,
                    fallbackKey: "transfer.unknownDestination"
                )
            }
        } else {
            HStack(spacing: 10) {
                compactRouteTeam(
                    transfer.fromTeam,
                    fallbackKey: "transfer.unknownOrigin"
                )

                VStack(spacing: 4) {
                    Image(systemName: "arrow.forward")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(statusColor)
                    Rectangle()
                        .fill(statusColor.opacity(0.24))
                        .frame(height: 2)
                }
                .frame(maxWidth: 54)
                .accessibilityHidden(true)

                compactRouteTeam(
                    transfer.toTeam,
                    fallbackKey: "transfer.unknownDestination"
                )
            }
        }
    }

    private func compactRouteTeam(
        _ team: Team?,
        fallbackKey: LocalizedStringKey
    ) -> some View {
        VStack(spacing: 7) {
            if let team {
                TeamBadge(team: team, size: 42)
                Text(team.displayName(in: appModel.language))
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 38))
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)
                Text(fallbackKey)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 68)
    }

    private func expandedRouteTeam(
        _ team: Team?,
        fallbackKey: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 10) {
            if let team {
                TeamBadge(team: team, size: 42)
                Text(team.displayName(in: appModel.language))
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 38))
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)
                Text(fallbackKey)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var statusColor: Color {
        switch transfer.status {
        case .completed: AppTheme.accent
        case .agreed: AppTheme.warm
        case .rumored: .purple
        }
    }

    private var accessibilitySummary: String {
        let locale = appModel.language.locale
        let status = String(localized: statusLocalizationValue, locale: locale)
        let origin = transfer.fromTeam?.displayName(in: appModel.language)
            ?? String(localized: "transfer.unknownOrigin", locale: locale)
        let destination = transfer.toTeam?.displayName(in: appModel.language)
            ?? String(localized: "transfer.unknownDestination", locale: locale)
        let date = transfer.transferDate.formatted(
            Date.FormatStyle(date: .long, time: .omitted).locale(locale)
        )
        let format = String(localized: "transfer.card.accessibility", locale: locale)
        return String(
            format: format,
            transfer.player.name,
            status,
            origin,
            destination,
            date
        )
    }

    private var statusLocalizationValue: String.LocalizationValue {
        switch transfer.status {
        case .rumored: "transfer.status.rumored"
        case .agreed: "transfer.status.agreed"
        case .completed: "transfer.status.completed"
        }
    }
}
