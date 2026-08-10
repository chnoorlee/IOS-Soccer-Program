import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var teamState: CatalogLoadState<[Team]> = .loading
    @State private var playerState: CatalogLoadState<[PlayerProfile]> = .loading
    @State private var competitionState: CatalogLoadState<[Competition]> = .loading
    @State private var teamRequestID: UUID?
    @State private var playerRequestID: UUID?
    @State private var competitionRequestID: UUID?
    @State private var pendingErrorFocus: CatalogSection?
    @AccessibilityFocusState private var focusedError: CatalogSection?

    private var interestColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private var languageColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                hero
                languageSection

                if appModel.followError != nil {
                    followErrorCard
                }

                teamSection
                playerSection
                competitionSection
                continueSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            skipBar
        }
        .accessibilityIdentifier("onboarding.screen")
        .task { await loadContent() }
        .onChange(of: appModel.followError) { _, error in
            if error != nil {
                pendingErrorFocus = nil
                focusedError = nil
                focusError(.follows)
            } else if focusedError == .follows {
                focusedError = nil
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.accent.gradient)
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .frame(width: 78, height: 78)

            Text("onboarding.title")
                .font(.largeTitle.weight(.black))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.title")

            Text("onboarding.subtitle")
                .font(.title3)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var skipBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button("onboarding.skip") {
                appModel.skipOnboarding()
            }
            .font(.headline)
            .frame(minWidth: 44, minHeight: 44)
            .disabled(appModel.isFollowActivityInProgress)
            .accessibilityHint(Text("onboarding.skipHint"))
            .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .background(.thinMaterial)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("onboarding.language")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: languageColumns, spacing: 12) {
                ForEach(AppLanguage.allCases) { language in
                    let isSelected = appModel.language == language
                    Button {
                        appModel.language = language
                    } label: {
                        HStack {
                            Text(language.nativeName)
                                .font(.headline)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .padding(.horizontal, 14)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background(isSelected ? AppTheme.accent : AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityValue(
                        Text(
                            LocalizedStringKey(
                                isSelected
                                    ? "accessibility.interestSelected"
                                    : "accessibility.interestNotSelected"
                            )
                        )
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("language.\(language.rawValue)")
                }
            }
        }
    }

    private var teamSection: some View {
        catalogSectionHeader(
            title: "onboarding.chooseTeams",
            hint: "onboarding.teamHint",
            identifier: "onboarding.section.teams"
        ) {
            switch teamState {
            case .loading:
                catalogLoading(identifier: "onboarding.teams.loading")
            case let .loaded(teams) where teams.isEmpty:
                catalogEmpty(identifier: "onboarding.teams.empty")
            case let .loaded(teams):
                LazyVGrid(columns: interestColumns, spacing: 10) {
                    ForEach(teams) { team in
                        teamButton(team)
                    }
                }
            case .failed:
                catalogError(
                    section: .teams,
                    title: "onboarding.teamsLoadFailed"
                ) {
                    Task { await loadTeams() }
                }
            }
        }
    }

    private var playerSection: some View {
        catalogSectionHeader(
            title: "onboarding.choosePlayers",
            hint: "onboarding.playerHint",
            identifier: "onboarding.section.players"
        ) {
            switch playerState {
            case .loading:
                catalogLoading(identifier: "onboarding.players.loading")
            case let .loaded(players) where players.isEmpty:
                catalogEmpty(identifier: "onboarding.players.empty")
            case let .loaded(players):
                LazyVGrid(columns: interestColumns, spacing: 10) {
                    ForEach(players) { player in
                        playerButton(player)
                    }
                }
            case .failed:
                catalogError(
                    section: .players,
                    title: "onboarding.playersLoadFailed"
                ) {
                    Task { await loadPlayers() }
                }
            }
        }
    }

    private var competitionSection: some View {
        catalogSectionHeader(
            title: "onboarding.chooseCompetitions",
            hint: "onboarding.competitionHint",
            identifier: "onboarding.section.competitions"
        ) {
            switch competitionState {
            case .loading:
                catalogLoading(identifier: "onboarding.competitions.loading")
            case let .loaded(competitions) where competitions.isEmpty:
                catalogEmpty(identifier: "onboarding.competitions.empty")
            case let .loaded(competitions):
                LazyVGrid(columns: interestColumns, spacing: 10) {
                    ForEach(competitions) { competition in
                        competitionButton(competition)
                    }
                }
            case .failed:
                catalogError(
                    section: .competitions,
                    title: "onboarding.competitionsLoadFailed"
                ) {
                    Task { await loadCompetitions() }
                }
            }
        }
    }

    private func teamButton(_ team: Team) -> some View {
        let isSelected = appModel.isFollowing(type: .team, entityID: team.id)
        let isBusy = appModel.isFollowMutationInProgress(type: .team, entityID: team.id)

        return Button {
            appModel.toggleFollow(
                type: .team,
                entityID: team.id,
                entity: .team(team)
            )
        } label: {
            InterestSelectionLabel(
                title: team.displayName(in: appModel.language),
                isSelected: isSelected,
                isBusy: isBusy
            ) {
                TeamBadge(team: team, size: 58)
            }
        }
        .disabled(isBusy || appModel.isSynchronizingFollows)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            interestAccessibilityLabel(
                team.displayName(in: appModel.language),
                type: "following.type.team"
            )
        )
        .accessibilityValue(selectionValue(isSelected: isSelected, isBusy: isBusy))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("team.\(team.id)")
    }

    private func playerButton(_ player: PlayerProfile) -> some View {
        let isSelected = appModel.isFollowing(type: .player, entityID: player.id)
        let isBusy = appModel.isFollowMutationInProgress(type: .player, entityID: player.id)

        return Button {
            appModel.toggleFollow(
                type: .player,
                entityID: player.id,
                entity: .player(player)
            )
        } label: {
            InterestSelectionLabel(
                title: player.name,
                isSelected: isSelected,
                isBusy: isBusy
            ) {
                catalogSymbol("person.fill")
            }
        }
        .disabled(isBusy || appModel.isSynchronizingFollows)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            interestAccessibilityLabel(player.name, type: "following.type.player")
        )
        .accessibilityValue(selectionValue(isSelected: isSelected, isBusy: isBusy))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.player.\(player.id)")
    }

    private func competitionButton(_ competition: Competition) -> some View {
        let isSelected = appModel.isFollowing(type: .competition, entityID: competition.id)
        let isBusy = appModel.isFollowMutationInProgress(
            type: .competition,
            entityID: competition.id
        )

        return Button {
            appModel.toggleFollow(
                type: .competition,
                entityID: competition.id,
                entity: .competition(competition)
            )
        } label: {
            InterestSelectionLabel(
                title: competition.displayName(in: appModel.language),
                isSelected: isSelected,
                isBusy: isBusy
            ) {
                catalogSymbol("trophy.fill")
            }
        }
        .disabled(isBusy || appModel.isSynchronizingFollows)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            interestAccessibilityLabel(
                competition.displayName(in: appModel.language),
                type: "following.type.competition"
            )
        )
        .accessibilityValue(selectionValue(isSelected: isSelected, isBusy: isBusy))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.competition.\(competition.id)")
    }

    private func catalogSymbol(_ systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.14))
            Image(systemName: systemName)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.accent)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }

    private var continueSection: some View {
        VStack(spacing: 8) {
            if !appModel.hasFollowedInterests {
                Text("onboarding.selectionRequired")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }

            Button("action.continue") {
                appModel.completeOnboarding()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!appModel.hasFollowedInterests || appModel.isFollowActivityInProgress)
            .opacity(
                !appModel.hasFollowedInterests || appModel.isFollowActivityInProgress
                    ? 0.48
                    : 1
            )
            .accessibilityIdentifier("onboarding.continue")
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
                    Task { await appModel.synchronizeFollows() }
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
        .accessibilityFocused($focusedError, equals: .follows)
        .accessibilityIdentifier("onboarding.followError")
    }

    private func catalogSectionHeader<Content: View>(
        title: LocalizedStringKey,
        hint: LocalizedStringKey,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            content()
        }
    }

    private func catalogLoading(identifier: String) -> some View {
        ProgressView("common.loading")
            .frame(maxWidth: .infinity, minHeight: 116)
            .accessibilityIdentifier(identifier)
    }

    private func catalogEmpty(identifier: String) -> some View {
        Label("common.empty", systemImage: "tray")
            .font(.headline)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 116)
            .accessibilityIdentifier(identifier)
    }

    private func catalogError(
        section: CatalogSection,
        title: LocalizedStringKey,
        retry: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.warm)
            Text("onboarding.catalogErrorBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
            Button("action.retry", action: retry)
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, minHeight: 116)
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityFocused($focusedError, equals: section)
        .accessibilityIdentifier("onboarding.\(section.rawValue).error")
    }

    private func selectionValue(isSelected: Bool, isBusy: Bool) -> Text {
        if isBusy {
            return Text("accessibility.updating")
        }
        return Text(
            LocalizedStringKey(
                isSelected
                    ? "accessibility.interestSelected"
                    : "accessibility.interestNotSelected"
            )
        )
    }

    private func interestAccessibilityLabel(
        _ name: String,
        type: LocalizedStringKey
    ) -> Text {
        Text(name) + Text(", ") + Text(type)
    }

    @MainActor
    private func loadContent() async {
        await appModel.synchronizeFollows()
        async let teams: Void = loadTeams()
        async let players: Void = loadPlayers()
        async let competitions: Void = loadCompetitions()
        _ = await (teams, players, competitions)
    }

    @MainActor
    private func loadTeams() async {
        let requestID = UUID()
        let provider = appModel.dataProvider
        prepareErrorFocusForCatalogLoad()
        teamRequestID = requestID
        teamState = .loading
        let result = await catalogRequest { try await provider.teams() }
        guard teamRequestID == requestID else { return }
        switch result {
        case let .success(teams):
            teamState = .loaded(teams)
        case .failed:
            teamState = .failed
            focusError(.teams)
        case .cancelled:
            break
        }
    }

    @MainActor
    private func loadPlayers() async {
        let requestID = UUID()
        let provider = appModel.dataProvider
        prepareErrorFocusForCatalogLoad()
        playerRequestID = requestID
        playerState = .loading
        let result = await catalogRequest { try await provider.players() }
        guard playerRequestID == requestID else { return }
        switch result {
        case let .success(players):
            playerState = .loaded(players)
        case .failed:
            playerState = .failed
            focusError(.players)
        case .cancelled:
            break
        }
    }

    @MainActor
    private func loadCompetitions() async {
        let requestID = UUID()
        let provider = appModel.dataProvider
        prepareErrorFocusForCatalogLoad()
        competitionRequestID = requestID
        competitionState = .loading
        let result = await catalogRequest { try await provider.competitions() }
        guard competitionRequestID == requestID else { return }
        switch result {
        case let .success(competitions):
            competitionState = .loaded(competitions)
        case .failed:
            competitionState = .failed
            focusError(.competitions)
        case .cancelled:
            break
        }
    }

    @MainActor
    private func focusError(_ section: CatalogSection) {
        guard pendingErrorFocus == nil,
              focusedError == nil || focusedError == section else {
            return
        }
        pendingErrorFocus = section
        Task { @MainActor in
            await Task.yield()
            guard pendingErrorFocus == section else { return }
            pendingErrorFocus = nil
            focusedError = section
        }
    }

    @MainActor
    private func prepareErrorFocusForCatalogLoad() {
        pendingErrorFocus = nil
        focusedError = nil
    }
}

private enum CatalogSection: String, Hashable, Sendable {
    case teams
    case players
    case competitions
    case follows
}

private enum CatalogLoadState<Value: Sendable>: Sendable {
    case loading
    case loaded(Value)
    case failed
}

private enum CatalogRequestResult<Value: Sendable>: Sendable {
    case success(Value)
    case failed
    case cancelled
}

private func catalogRequest<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
) async -> CatalogRequestResult<Value> {
    do {
        return .success(try await operation())
    } catch is CancellationError {
        return .cancelled
    } catch {
        return .failed
    }
}

private struct InterestSelectionLabel<Mark: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let isSelected: Bool
    let isBusy: Bool
    let mark: Mark

    init(
        title: String,
        isSelected: Bool,
        isBusy: Bool,
        @ViewBuilder mark: () -> Mark
    ) {
        self.title = title
        self.isSelected = isSelected
        self.isBusy = isBusy
        self.mark = mark()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 14) {
                    mark
                    titleText
                    Spacer(minLength: 8)
                    status
                }
                .frame(minHeight: 76)
            } else {
                VStack(spacing: 8) {
                    mark
                    titleText
                    status
                }
                .frame(minHeight: 136)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .foregroundStyle(.primary)
        .background(isSelected ? AppTheme.accent.opacity(0.12) : AppTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? AppTheme.accent : .clear, lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
                    .accessibilityHidden(true)
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
            .minimumScaleFactor(0.84)
    }

    private var status: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.muted)
            .accessibilityHidden(true)
    }
}
