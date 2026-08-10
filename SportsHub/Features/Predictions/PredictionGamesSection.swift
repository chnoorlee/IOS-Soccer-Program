import SwiftUI

struct PredictionGamesSection: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let refreshID: UUID

    @State private var state: PredictionGameListState = .loading
    @State private var requestID: UUID?
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "predictions.homeTitle")
            switch state {
            case .loading:
                ProgressView("predictions.loading")
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .sportsCard()
                    .accessibilityIdentifier("predictions.loading")
            case .failed:
                predictionError
            case let .loaded(games, freshness):
                if let freshness {
                    PublicContentStatusView(
                        freshness: freshness,
                        identifier: "prediction-games"
                    )
                }
                if games.isEmpty {
                    ContentUnavailableView(
                        "predictions.emptyTitle",
                        systemImage: "list.number",
                        description: Text("predictions.emptyBody")
                    )
                    .accessibilityIdentifier("predictions.empty")
                } else {
                    gameCollection(games)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.predictions")
        .task(id: refreshID) {
            await load(focusFailure: false)
        }
    }

    @ViewBuilder
    private func gameCollection(_ games: [PredictionGame]) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                ForEach(games) { game in
                    gameLink(game, compact: false)
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(games) { game in
                        gameLink(game, compact: true)
                            .frame(width: 276)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func gameLink(_ game: PredictionGame, compact: Bool) -> some View {
        NavigationLink {
            PredictionGameView(game: game)
        } label: {
            PredictionGameCard(game: game, compact: compact)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("predictions.game.\(game.id)")
    }

    private var predictionError: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("predictions.loadFailedTitle", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.warm)
            Text("predictions.loadFailedBody")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            Button("action.retry") {
                Task { await load(focusFailure: true) }
            }
            .buttonStyle(.borderedProminent)
            .frame(minWidth: 44, minHeight: 44)
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityFocused($errorFocused)
        .accessibilityIdentifier("predictions.error")
    }

    @MainActor
    private func load(focusFailure: Bool) async {
        let currentRequestID = UUID()
        requestID = currentRequestID
        state = .loading
        do {
            let games = try await appModel.dataProvider.predictionGames()
            guard requestID == currentRequestID, !Task.isCancelled else { return }
            let freshness = await appModel.publicContentFreshness(for: .predictionGames)
            guard requestID == currentRequestID, !Task.isCancelled else { return }
            state = .loaded(games, freshness)
        } catch {
            guard requestID == currentRequestID, !Task.isCancelled else { return }
            state = .failed
            if focusFailure {
                errorFocused = false
                await Task.yield()
                guard requestID == currentRequestID, !Task.isCancelled else { return }
                errorFocused = true
            }
        }
    }
}

private enum PredictionGameListState {
    case loading
    case loaded([PredictionGame], PublicContentFreshness?)
    case failed
}

private struct PredictionGameCard: View {
    @EnvironmentObject private var appModel: AppModel
    let game: PredictionGame
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "list.number")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    StatusPill(
                        text: LocalizedStringKey(effectiveState.localizationKey),
                        color: stateColor
                    )
                    Text(game.title(in: appModel.language))
                        .font(.headline.weight(.bold))
                        .multilineTextAlignment(.leading)
                        .lineLimit(compact ? 2 : nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(game.summary(in: appModel.language))
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.leading)
                .lineLimit(compact ? 3 : nil)

            Label {
                Text(game.lockAt, style: .date)
                + Text(verbatim: " · ")
                + Text(game.lockAt, style: .time)
            } icon: {
                Image(systemName: "lock.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.warm)

            Label("predictions.nonWager", systemImage: "checkmark.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 226 : nil, alignment: .topLeading)
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("predictions.openHint"))
    }

    private var stateColor: Color {
        switch effectiveState {
        case .open: AppTheme.accent
        case .locked: AppTheme.warm
        case .settled: .green
        case .cancelled: AppTheme.live
        }
    }

    private var effectiveState: PredictionGameState {
        game.effectiveState(at: Date())
    }
}
