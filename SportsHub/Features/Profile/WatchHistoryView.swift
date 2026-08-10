import SwiftUI

struct WatchHistoryView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var items: [WatchHistoryItem]?
    @State private var loadFailed = false
    @State private var isClearing = false
    @State private var clearFailed = false
    @State private var showsClearConfirmation = false
    @State private var itemPendingRemoval: WatchHistoryItem?
    @State private var failedRemoval: WatchHistoryItem?
    @State private var removingVideoIDs: Set<String> = []
    @State private var loadRequestID: UUID?
    @State private var identityGeneration = 0
    @AccessibilityFocusState private var emptyStateFocused: Bool
    @AccessibilityFocusState private var focusedHistoryItemID: String?

    private var isMutatingHistory: Bool {
        isClearing || !removingVideoIDs.isEmpty
    }

    var body: some View {
        Group {
            if let items {
                if items.isEmpty {
                    ContentUnavailableView(
                        "history.emptyTitle",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("history.emptyBody")
                    )
                    .accessibilityFocused($emptyStateFocused)
                    .accessibilityIdentifier("history.empty")
                } else {
                    List(items) { item in
                        historyRow(item)
                    }
                    .listStyle(.plain)
                }
            } else if loadFailed {
                LoadStateView(state: .error) {
                    Task { await load() }
                }
            } else {
                LoadStateView(state: .loading)
            }
        }
        .navigationTitle("history.title")
        .accessibilityIdentifier("history.screen")
        .toolbar {
            if let items, !items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("history.clearButton", role: .destructive) {
                        showsClearConfirmation = true
                    }
                    .disabled(isMutatingHistory)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("history.clear")
                }
            }
        }
        .confirmationDialog(
            "history.clearTitle",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("history.clearConfirm", role: .destructive) {
                Task { await clearHistory() }
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("history.clearBody")
        }
        .confirmationDialog(
            "history.removeTitle",
            isPresented: Binding(
                get: { itemPendingRemoval != nil },
                set: { isPresented in
                    if !isPresented { itemPendingRemoval = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            if let item = itemPendingRemoval {
                Button("history.removeConfirm", role: .destructive) {
                    itemPendingRemoval = nil
                    Task { await removeHistoryItem(item) }
                }
                .accessibilityIdentifier("history.remove.confirm.\(item.video.id)")
            }
            Button("action.cancel", role: .cancel) {
                itemPendingRemoval = nil
            }
        } message: {
            if let item = itemPendingRemoval {
                Text(
                    "history.removeBody \(item.video.title(in: appModel.language))"
                )
            }
        }
        .alert("history.clearFailed", isPresented: $clearFailed) {
            Button("action.dismiss", role: .cancel) {}
        } message: {
            Text("history.clearFailedBody")
        }
        .alert(
            "history.removeFailed",
            isPresented: Binding(
                get: { failedRemoval != nil },
                set: { isPresented in
                    if !isPresented { failedRemoval = nil }
                }
            )
        ) {
            if let item = failedRemoval {
                Button("action.retry") {
                    failedRemoval = nil
                    Task { await removeHistoryItem(item) }
                }
            }
            Button("action.dismiss", role: .cancel) {
                failedRemoval = nil
            }
        } message: {
            if let item = failedRemoval {
                Text(
                    "history.removeFailedBody \(item.video.title(in: appModel.language))"
                )
            }
        }
        .overlay {
            if isClearing {
                ProgressView("history.clearing")
                    .padding(18)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("history.clearing")
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .watchProgressDidChange)) { _ in
            Task { await load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationStateDidChange)) { _ in
            identityGeneration &+= 1
            loadRequestID = nil
            items = nil
            loadFailed = false
            itemPendingRemoval = nil
            failedRemoval = nil
            emptyStateFocused = false
            focusedHistoryItemID = nil
            Task { await load() }
        }
    }

    private func historyRow(_ item: WatchHistoryItem) -> some View {
        HStack(spacing: 8) {
            NavigationLink {
                VideoDetailView(video: item.video)
            } label: {
                HStack(spacing: 14) {
                    Image(
                        systemName: item.progress.completed
                            ? "checkmark.circle.fill"
                            : "play.circle.fill"
                    )
                    .font(.title2)
                    .foregroundStyle(item.progress.completed ? .green : AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.video.title(in: appModel.language))
                            .font(.headline)
                            .multilineTextAlignment(.leading)

                        if item.progress.completed {
                            Text("history.completed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        } else {
                            Text("video.progressPercent \(item.percentageCompleted)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }

                        Text(item.progress.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("accessibility.opensVideo"))
            .accessibilityFocused($focusedHistoryItemID, equals: item.id)
            .accessibilityIdentifier("history.item.\(item.video.id)")

            Button(role: .destructive) {
                itemPendingRemoval = item
            } label: {
                if removingVideoIDs.contains(item.video.id) {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
            }
            .disabled(isMutatingHistory)
            .accessibilityLabel(
                removingVideoIDs.contains(item.video.id)
                    ? Text("history.removingItem \(item.video.title(in: appModel.language))")
                    : Text("history.removeItem \(item.video.title(in: appModel.language))")
            )
            .accessibilityHint(Text("history.removeHint"))
            .accessibilityIdentifier("history.remove.\(item.video.id)")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                itemPendingRemoval = item
            } label: {
                Label("history.removeConfirm", systemImage: "trash")
            }
            .disabled(isMutatingHistory)
        }
    }

    @MainActor
    private func load() async {
        guard !isMutatingHistory else { return }
        let requestID = UUID()
        let accountID = appModel.authentication.status.user?.id
        let generation = identityGeneration
        loadRequestID = requestID
        loadFailed = false
        do {
            let loadedItems = try await appModel.dataProvider.watchHistory()
            guard loadRequestID == requestID,
                  identityGeneration == generation,
                  appModel.authentication.status.user?.id == accountID else {
                return
            }
            items = loadedItems
        } catch {
            guard loadRequestID == requestID,
                  identityGeneration == generation,
                  appModel.authentication.status.user?.id == accountID else {
                return
            }
            if items == nil {
                loadFailed = true
            }
        }
    }

    @MainActor
    private func clearHistory() async {
        guard !isMutatingHistory else { return }
        let accountID = appModel.authentication.status.user?.id
        let generation = identityGeneration
        loadRequestID = nil
        isClearing = true
        clearFailed = false
        do {
            try await appModel.dataProvider.clearWatchHistory()
            isClearing = false
            guard identityGeneration == generation,
                  appModel.authentication.status.user?.id == accountID else {
                items = nil
                await load()
                return
            }
            items = []
            loadFailed = false
            emptyStateFocused = true
            NotificationCenter.default.post(name: .watchProgressDidChange, object: nil)
        } catch {
            isClearing = false
            guard identityGeneration == generation,
                  appModel.authentication.status.user?.id == accountID else {
                items = nil
                await load()
                return
            }
            loadFailed = items == nil
            clearFailed = true
        }
    }

    @MainActor
    private func removeHistoryItem(_ item: WatchHistoryItem) async {
        let videoID = item.video.id
        let accountID = appModel.authentication.status.user?.id
        let generation = identityGeneration
        guard !isMutatingHistory,
              let currentItems = items,
              let removalIndex = currentItems.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        let focusTargetID: String? = if removalIndex + 1 < currentItems.count {
            currentItems[removalIndex + 1].id
        } else if removalIndex > 0 {
            currentItems[removalIndex - 1].id
        } else {
            nil
        }

        loadRequestID = nil
        removingVideoIDs.insert(videoID)
        do {
            try await appModel.dataProvider.removeWatchHistoryItem(videoID: videoID)
            removingVideoIDs.remove(videoID)
            guard identityGeneration == generation,
                  appModel.authentication.status.user?.id == accountID else {
                items = nil
                failedRemoval = nil
                await load()
                return
            }
            items?.removeAll { $0.id == item.id }
            loadFailed = false
            failedRemoval = nil
            NotificationCenter.default.post(name: .watchProgressDidChange, object: nil)
            await Task.yield()
            if items?.isEmpty == true {
                focusedHistoryItemID = nil
                emptyStateFocused = true
            } else {
                emptyStateFocused = false
                focusedHistoryItemID = focusTargetID
            }
        } catch {
            removingVideoIDs.remove(videoID)
            guard identityGeneration == generation,
                  appModel.authentication.status.user?.id == accountID else {
                items = nil
                failedRemoval = nil
                await load()
                return
            }
            loadFailed = items == nil
            failedRemoval = item
        }
    }
}
