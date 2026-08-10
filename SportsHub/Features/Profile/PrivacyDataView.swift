import SwiftUI

struct PrivacyDataView: View {
    private enum FocusTarget: Hashable {
        case guestSummary
        case guestEmpty
        case guestCompletion
        case guestFailure
        case cacheSummary
        case cacheEmpty
        case cacheCompletion
        case cacheFailure
    }

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var authentication: AuthenticationManager

    @State private var showsClearConfirmation = false
    @State private var isLoadingSummary = true
    @State private var summaryLoadFailed = false
    @State private var isClearing = false
    @State private var clearFailed = false
    @State private var clearSucceeded = false
    @State private var showsCacheClearConfirmation = false
    @State private var isLoadingCache = true
    @State private var cacheLoadFailed = false
    @State private var isClearingCache = false
    @State private var cacheClearFailed = false
    @State private var cacheClearSucceeded = false
    @AccessibilityFocusState private var focusedTarget: FocusTarget?

    private var summary: GuestPersonalizationSummary {
        authentication.guestSummary
    }

    private var clearIsDisabled: Bool {
        isClearing
            || isLoadingSummary
            || summaryLoadFailed
            || authentication.isBusy
            || appModel.isFollowActivityInProgress
            || summary.isEmpty
    }

    private var cacheSummary: SportsDataCacheSummary {
        appModel.publicCacheSummary
    }

    private var cacheClearIsDisabled: Bool {
        isClearingCache
            || isLoadingCache
            || cacheLoadFailed
            || appModel.isPublicCacheBusy
            || cacheSummary.isEmpty
    }

    var body: some View {
        List {
            Section("privacy.deviceDataTitle") {
                if isLoadingSummary {
                    ProgressView("privacy.loading")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("privacy.loading")
                } else if summaryLoadFailed {
                    summaryLoadFailure
                } else {
                    deviceDataStatus
                }

                if clearSucceeded {
                    Label("privacy.clearComplete", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityFocused($focusedTarget, equals: .guestCompletion)
                        .accessibilityIdentifier("privacy.clear.complete")
                }

                if clearFailed {
                    clearFailure
                }

                if !summaryLoadFailed, !summary.isEmpty {
                    Button("privacy.clearAction", role: .destructive) {
                        showsClearConfirmation = true
                    }
                    .disabled(clearIsDisabled)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityHint(Text("privacy.clearHint"))
                    .accessibilityIdentifier("privacy.clear")
                }

                if isClearing {
                    ProgressView("privacy.clearing")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("privacy.clearing")
                }
            }

            Section("privacy.clearScopeTitle") {
                scopeRow("privacy.scopeHistory", systemImage: "clock.arrow.circlepath")
                scopeRow("privacy.scopeSaved", systemImage: "bookmark.fill")
                scopeRow("privacy.scopeSavedArticles", systemImage: "newspaper.fill")
                scopeRow("privacy.scopeFollows", systemImage: "star.fill")
                Label {
                    Text("privacy.scopeSnapshots \(summary.videoSnapshotCount)")
                } icon: {
                    Image(systemName: "doc.text.image")
                }
                .font(.subheadline)
            }

            Section("privacy.boundaryTitle") {
                Text(boundaryLocalizationKey)
                .font(.subheadline)

                Text("privacy.keptBody")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }

            Section("privacy.cacheTitle") {
                if isLoadingCache {
                    ProgressView("privacy.cacheLoading")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("privacy.cache.loading")
                } else if cacheLoadFailed {
                    cacheLoadFailure
                } else {
                    cacheStatus
                }

                Text("privacy.cachePurpose")
                    .font(.subheadline)

                Text("privacy.cacheKeptBody")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)

                if cacheClearSucceeded {
                    Label("privacy.cacheClearComplete", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityFocused($focusedTarget, equals: .cacheCompletion)
                        .accessibilityIdentifier("privacy.cache.clear.complete")
                }

                if cacheClearFailed {
                    cacheClearFailure
                }

                if !cacheLoadFailed, !cacheSummary.isEmpty {
                    Button("privacy.cacheClearAction", role: .destructive) {
                        showsCacheClearConfirmation = true
                    }
                    .disabled(cacheClearIsDisabled)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityHint(Text("privacy.cacheClearHint"))
                    .accessibilityIdentifier("privacy.cache.clear")
                }

                if isClearingCache {
                    ProgressView("privacy.cacheClearing")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("privacy.cache.clearing")
                }
            }

            Section("privacy.securityTitle") {
                Text("profile.privacyBody")
                    .font(.subheadline)
            }

            Section("privacy.policyTitle") {
                Label("privacy.policyPending", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.warm)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("privacy.policy.pending")
            }
        }
        .navigationTitle("profile.privacy")
        .accessibilityIdentifier("privacy.screen")
        .confirmationDialog(
            "privacy.clearConfirmTitle",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("privacy.clearConfirmAction", role: .destructive) {
                requestClear()
            }
            .accessibilityIdentifier("privacy.clear.confirm")
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text(
                "privacy.clearConfirmBody \(summary.progressCount) \(summary.favoriteCount) \(summary.articleFavoriteCount) \(summary.followCount) \(summary.videoSnapshotCount)"
            )
        }
        .confirmationDialog(
            "privacy.cacheClearConfirmTitle",
            isPresented: $showsCacheClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("privacy.cacheClearConfirmAction", role: .destructive) {
                requestCacheClear()
            }
            .accessibilityIdentifier("privacy.cache.clear.confirm")
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("privacy.cacheClearConfirmBody")
        }
        .task {
            await refreshSummary()
            await refreshCacheSummary()
        }
    }

    @ViewBuilder
    private var deviceDataStatus: some View {
        if summary.isEmpty {
            Label("privacy.empty", systemImage: "checkmark.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                .accessibilityFocused($focusedTarget, equals: .guestEmpty)
                .accessibilityIdentifier("privacy.empty")
        } else {
            Label {
                Text(
                    "privacy.deviceSummary \(summary.progressCount) \(summary.favoriteCount) \(summary.articleFavoriteCount) \(summary.followCount) \(summary.videoSnapshotCount)"
                )
            } icon: {
                Image(systemName: "iphone")
                    .foregroundStyle(AppTheme.accent)
            }
            .font(.subheadline.weight(.semibold))
            .accessibilityElement(children: .combine)
            .accessibilityFocused($focusedTarget, equals: .guestSummary)
            .accessibilityIdentifier("privacy.deviceSummary")
        }
    }

    @ViewBuilder
    private var cacheStatus: some View {
        if cacheSummary.isEmpty {
            Label("privacy.cacheEmpty", systemImage: "checkmark.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                .accessibilityFocused($focusedTarget, equals: .cacheEmpty)
                .accessibilityIdentifier("privacy.cache.empty")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("privacy.cacheEntries") {
                    Text(cacheSummary.entryCount, format: .number)
                }
                LabeledContent("privacy.cacheSize") {
                    Text(cacheSummary.byteCount, format: .byteCount(style: .file))
                }
                LabeledContent("privacy.cacheLimit") {
                    Text(cacheSummary.maximumByteCount, format: .byteCount(style: .file))
                }
                if let newestStoredAt = cacheSummary.newestStoredAt {
                    LabeledContent("privacy.cacheLatestUpdate") {
                        Text(
                            newestStoredAt,
                            format: .dateTime.year().month().day().hour().minute()
                        )
                    }
                }
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityFocused($focusedTarget, equals: .cacheSummary)
            .accessibilityIdentifier("privacy.cache.summary")
        }
    }

    private var clearFailure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("privacy.clearFailedTitle", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.live)
                .accessibilityAddTraits(.isHeader)
            if let error = authentication.lastError {
                Text(LocalizedStringKey(error.localizationKey))
                    .font(.footnote)
            } else {
                Text("privacy.clearUnavailable")
                    .font(.footnote)
            }
            Button("action.retry") {
                requestClear()
            }
            .disabled(isClearing || authentication.isBusy || appModel.isFollowActivityInProgress)
            .frame(minHeight: 44)
            .accessibilityIdentifier("privacy.clear.retry")
        }
        .accessibilityFocused($focusedTarget, equals: .guestFailure)
        .accessibilityIdentifier("privacy.clear.failure")
    }

    private var summaryLoadFailure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("privacy.loadFailedTitle", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.live)
                .accessibilityAddTraits(.isHeader)
            Text("auth.error.deviceStorageUnavailable")
                .font(.footnote)
            Button("action.retry") {
                Task { await refreshSummary() }
            }
            .disabled(isLoadingSummary || authentication.isBusy)
            .frame(minHeight: 44)
            .accessibilityIdentifier("privacy.load.retry")
        }
        .accessibilityFocused($focusedTarget, equals: .guestFailure)
        .accessibilityIdentifier("privacy.load.failure")
    }

    private var cacheClearFailure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("privacy.cacheClearFailedTitle", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.live)
                .accessibilityAddTraits(.isHeader)
            Text("privacy.cacheClearUnavailable")
                .font(.footnote)
            Button("action.retry") {
                requestCacheClear()
            }
            .disabled(isClearingCache || appModel.isPublicCacheBusy)
            .frame(minHeight: 44)
            .accessibilityIdentifier("privacy.cache.clear.retry")
        }
        .accessibilityFocused($focusedTarget, equals: .cacheFailure)
        .accessibilityIdentifier("privacy.cache.clear.failure")
    }

    private var cacheLoadFailure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("privacy.cacheLoadFailedTitle", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.live)
                .accessibilityAddTraits(.isHeader)
            Text("auth.error.deviceStorageUnavailable")
                .font(.footnote)
            Button("action.retry") {
                Task { await refreshCacheSummary(announceResult: true) }
            }
            .disabled(isLoadingCache || appModel.isPublicCacheBusy)
            .frame(minHeight: 44)
            .accessibilityIdentifier("privacy.cache.load.retry")
        }
        .accessibilityFocused($focusedTarget, equals: .cacheFailure)
        .accessibilityIdentifier("privacy.cache.load.failure")
    }

    private var boundaryLocalizationKey: LocalizedStringKey {
        switch authentication.status {
        case .loading:
            "privacy.loadingBoundary"
        case .authenticated:
            "privacy.accountBoundary"
        case .signedOut, .unavailable:
            "privacy.guestBoundary"
        }
    }

    private func scopeRow(_ titleKey: LocalizedStringKey, systemImage: String) -> some View {
        Label(titleKey, systemImage: systemImage)
            .font(.subheadline)
    }

    private func requestClear() {
        guard !isClearing,
              !authentication.isBusy,
              !appModel.isFollowActivityInProgress,
              !summary.isEmpty else {
            return
        }
        isClearing = true
        clearFailed = false
        clearSucceeded = false

        Task {
            let cleared = await appModel.clearDeviceGuestPersonalization()
            isClearing = false
            if cleared {
                clearSucceeded = true
                focusedTarget = .guestCompletion
            } else {
                clearFailed = true
                focusedTarget = .guestFailure
            }
        }
    }

    private func requestCacheClear() {
        guard !isClearingCache,
              !appModel.isPublicCacheBusy,
              !cacheSummary.isEmpty else {
            return
        }
        isClearingCache = true
        cacheClearFailed = false
        cacheClearSucceeded = false

        Task {
            let cleared = await appModel.clearPublicCache()
            isClearingCache = false
            if cleared {
                cacheClearSucceeded = true
                focusedTarget = .cacheCompletion
            } else {
                cacheClearFailed = true
                focusedTarget = .cacheFailure
            }
        }
    }

    private func refreshSummary() async {
        isLoadingSummary = true
        summaryLoadFailed = false
        let loaded = await authentication.refreshGuestSummary()
        isLoadingSummary = false
        summaryLoadFailed = !loaded
        await Task.yield()
        if loaded {
            focusedTarget = summary.isEmpty ? .guestEmpty : .guestSummary
        } else {
            focusedTarget = .guestFailure
        }
    }

    private func refreshCacheSummary(announceResult: Bool = false) async {
        isLoadingCache = true
        cacheLoadFailed = false
        cacheClearFailed = false
        let loaded = await appModel.refreshPublicCacheSummary()
        isLoadingCache = false
        cacheLoadFailed = !loaded
        await Task.yield()
        if !loaded || announceResult {
            focusedTarget = loaded
                ? (cacheSummary.isEmpty ? .cacheEmpty : .cacheSummary)
                : .cacheFailure
        }
    }

}
