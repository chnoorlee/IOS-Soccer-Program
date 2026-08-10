import SwiftUI

struct PredictionGameView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var authentication: AuthenticationManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    let game: PredictionGame

    @State private var draft: PredictionDraft?
    @State private var savedEntry: PredictionEntry?
    @State private var entryState: PredictionEntryLoadState = .notRequired
    @State private var entryRequestID: UUID?
    @State private var saveRequestID: UUID?
    @State private var isSaving = false
    @State private var saveFailed = false
    @State private var lockRejected = false
    @State private var savedConfirmation = false
    @State private var currentDate = Date()
    @AccessibilityFocusState private var entryErrorFocused: Bool
    @AccessibilityFocusState private var saveStatusFocused: Bool

    init(game: PredictionGame) {
        self.game = game
        _draft = State(initialValue: try? PredictionDraft(game: game))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                gameHeader
                instructions
                if let draft {
                    ForEach(game.groups) { group in
                        groupCard(group, draft: draft)
                    }
                }
                accountAndSaveSection
                rulesSection
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .navigationTitle("predictions.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("predictions.detail")
        .task(id: authentication.status.user?.id) {
            await loadEntry(focusFailure: false)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            currentDate = Date()
        }
    }

    private var gameHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "list.number")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    StatusPill(
                        text: LocalizedStringKey(effectiveState.localizationKey),
                        color: stateColor
                    )
                    Text(game.title(in: appModel.language))
                        .font(.title2.weight(.black))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(game.summary(in: appModel.language))
                .font(.body)
                .multilineTextAlignment(.leading)

            Label {
                Text("predictions.lockLabel")
                + Text(verbatim: " ")
                + Text(game.lockAt, style: .date)
                + Text(verbatim: " · ")
                + Text(game.lockAt, style: .time)
            } icon: {
                Image(systemName: "lock.fill")
            }
            .font(.subheadline.weight(.bold))

            Label("predictions.nonWagerLong", systemImage: "checkmark.shield.fill")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppTheme.ink, AppTheme.accent.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("predictions.header")
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("predictions.instructionsTitle", systemImage: "arrow.up.arrow.down")
                .font(.headline)
            Text(
                isEditable
                    ? LocalizedStringKey("predictions.instructionsBody")
                    : readOnlyMessageKey
            )
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("predictions.instructions")
    }

    private func groupCard(
        _ group: PredictionGroup,
        draft currentDraft: PredictionDraft
    ) -> some View {
        let orderedIDs = currentDraft.teamIDs(in: group.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.displayName(in: appModel.language))
                    .font(.title3.weight(.black))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(
                    localizedFormat(
                        "predictions.qualifyingCount",
                        group.qualifyingPositions
                    )
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            }

            ForEach(Array(orderedIDs.enumerated()), id: \.element) { index, teamID in
                if let team = group.teams.first(where: { $0.id == teamID }) {
                    rankingRow(
                        team,
                        position: index + 1,
                        group: group,
                        draft: currentDraft
                    )
                    if index < orderedIDs.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("predictions.group.\(group.id)")
    }

    @ViewBuilder
    private func rankingRow(
        _ team: Team,
        position: Int,
        group: PredictionGroup,
        draft currentDraft: PredictionDraft
    ) -> some View {
        let info = HStack(spacing: 12) {
            Text(verbatim: "\(position)")
                .font(.headline.monospacedDigit().weight(.black))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(position <= group.qualifyingPositions ? AppTheme.accent : AppTheme.ink)
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text(verbatim: team.monogram)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color(hex: team.colorHex))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(team.displayName(in: appModel.language))
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                if position <= group.qualifyingPositions {
                    Label("predictions.qualifies", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Text("predictions.notQualifying")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                Text(verbatim:
                    positionAccessibilityLabel(
                        teamName: team.displayName(in: appModel.language),
                        position: position,
                        qualifies: position <= group.qualifyingPositions
                    )
                )
            )
        }

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                info
                moveControls(team, position: position, group: group, draft: currentDraft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(spacing: 12) {
                info
                moveControls(team, position: position, group: group, draft: currentDraft)
            }
        }
    }

    private func moveControls(
        _ team: Team,
        position: Int,
        group: PredictionGroup,
        draft currentDraft: PredictionDraft
    ) -> some View {
        HStack(spacing: 8) {
            moveButton(
                team,
                position: position,
                group: group,
                draft: currentDraft,
                direction: .up
            )
            moveButton(
                team,
                position: position,
                group: group,
                draft: currentDraft,
                direction: .down
            )
        }
    }

    private func moveButton(
        _ team: Team,
        position: Int,
        group: PredictionGroup,
        draft currentDraft: PredictionDraft,
        direction: PredictionMoveDirection
    ) -> some View {
        let canMove = canEditDraft && currentDraft.canMove(
            teamID: team.id,
            in: group.id,
            direction: direction
        )
        let destination = direction == .up ? position - 1 : position + 1
        return Button {
            move(teamID: team.id, groupID: group.id, direction: direction)
        } label: {
            Image(systemName: direction == .up ? "chevron.up" : "chevron.down")
                .font(.headline.weight(.black))
                .frame(width: 44, height: 44)
                .foregroundStyle(canMove ? Color.white : AppTheme.muted)
                .background(canMove ? AppTheme.ink : AppTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canMove)
        .accessibilityLabel(
            Text(verbatim:
                moveAccessibilityLabel(
                    teamName: team.displayName(in: appModel.language),
                    direction: direction,
                    destination: destination
                )
            )
        )
        .accessibilityHint(Text("predictions.moveHint"))
        .accessibilityIdentifier(
            "predictions.move.\(direction == .up ? "up" : "down").\(group.id).\(team.id)"
        )
    }

    @ViewBuilder
    private var accountAndSaveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "predictions.entryTitle")

            switch authentication.status {
            case .loading:
                ProgressView("profile.accountLoading")
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            case .unavailable:
                Label("predictions.accountUnavailable", systemImage: "person.crop.circle.badge.xmark")
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityIdentifier("predictions.account.unavailable")
            case .signedOut:
                Text("predictions.signInBody")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                AppleSignInControl(
                    isEnabled: !authentication.isBusy,
                    onCredential: { credential in
                        await authentication.signIn(with: credential)
                    },
                    onFailure: { error in
                        authentication.reportSignInFailure(error)
                    },
                    identifier: "predictions.signInWithApple"
                )
            case .authenticated:
                authenticatedEntryControls
            }

            if let error = authentication.lastError {
                Label(
                    LocalizedStringKey(error.localizationKey),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            }
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("predictions.entry")
    }

    @ViewBuilder
    private var authenticatedEntryControls: some View {
        switch entryState {
        case .notRequired, .loading:
            ProgressView("predictions.entryLoading")
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .accessibilityIdentifier("predictions.entry.loading")
        case .failed:
            VStack(alignment: .leading, spacing: 10) {
                Label("predictions.entryFailedTitle", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.warm)
                Text("predictions.entryFailedBody")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                Button("action.retry") {
                    Task { await loadEntry(focusFailure: true) }
                }
                .buttonStyle(.borderedProminent)
                .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityFocused($entryErrorFocused)
            .accessibilityIdentifier("predictions.entry.error")
        case .ready:
            if let savedEntry {
                Label {
                    Text("predictions.lastSaved")
                    + Text(verbatim: " ")
                    + Text(savedEntry.updatedAt, style: .relative)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            } else {
                Text("predictions.notSaved")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }

            if isEditable {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("predictions.save", systemImage: "checkmark.seal.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || !hasUnsavedChanges)
                .accessibilityIdentifier("predictions.save")
            } else {
                Label(readOnlyMessageKey, systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.warm)
                    .accessibilityIdentifier("predictions.readOnly")
            }

            if savedConfirmation {
                Label("predictions.saved", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityFocused($saveStatusFocused)
                    .accessibilityIdentifier("predictions.saved")
            } else if saveFailed {
                Label(saveErrorKey, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
                .accessibilityFocused($saveStatusFocused)
                .accessibilityIdentifier("predictions.save.error")
            }
        }
    }

    @ViewBuilder
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "predictions.rulesTitle")
            Text("predictions.rulesSummary")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            if let rulesURL = game.rulesURL {
                Link(destination: rulesURL) {
                    Label("predictions.openRules", systemImage: "safari")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("predictions.rulesLink")
            } else {
                Label("predictions.demoRules", systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
    }

    private var isEditable: Bool {
        game.isEditable(at: currentDate) && !lockRejected
    }

    private var canEditDraft: Bool {
        guard isEditable else { return false }
        switch authentication.status {
        case .loading:
            return false
        case .authenticated:
            return entryState == .ready
        case .signedOut, .unavailable:
            return true
        }
    }

    private var effectiveState: PredictionGameState {
        if lockRejected {
            return .locked
        }
        return game.effectiveState(at: currentDate)
    }

    private var stateColor: Color {
        switch effectiveState {
        case .open: AppTheme.accent
        case .locked: AppTheme.warm
        case .settled: .green
        case .cancelled: AppTheme.live
        }
    }

    private var readOnlyMessageKey: LocalizedStringKey {
        switch effectiveState {
        case .open: "predictions.instructionsBody"
        case .locked: "predictions.lockedBody"
        case .settled: "predictions.settledBody"
        case .cancelled: "predictions.cancelledBody"
        }
    }

    private var hasUnsavedChanges: Bool {
        guard let draft else { return false }
        return draft.rankings != savedEntry?.rankings
    }

    private var saveErrorKey: LocalizedStringKey {
        lockRejected ? "predictions.lockRejected" : "predictions.saveFailed"
    }

    private func move(
        teamID: String,
        groupID: String,
        direction: PredictionMoveDirection
    ) {
        guard canEditDraft, var updatedDraft = draft else { return }
        updatedDraft.move(teamID: teamID, in: groupID, direction: direction)
        draft = updatedDraft
        savedConfirmation = false
        saveFailed = false
    }

    @MainActor
    private func loadEntry(focusFailure: Bool) async {
        let currentRequestID = UUID()
        entryRequestID = currentRequestID
        saveRequestID = nil
        isSaving = false
        savedEntry = nil
        savedConfirmation = false
        saveFailed = false
        lockRejected = false
        currentDate = Date()
        draft = try? PredictionDraft(game: game)

        guard case let .authenticated(user) = authentication.status else {
            entryState = .notRequired
            return
        }
        entryState = .loading
        do {
            let provider = try scopedProvider
            let entry = try await provider.predictionEntry(
                for: game,
                forAccountID: user.id
            )
            guard entryRequestID == currentRequestID,
                  authentication.status.user?.id == user.id,
                  !Task.isCancelled else { return }
            draft = try PredictionDraft(game: game, entry: entry)
            savedEntry = entry
            entryState = .ready
        } catch {
            guard entryRequestID == currentRequestID,
                  authentication.status.user?.id == user.id,
                  !Task.isCancelled else { return }
            entryState = .failed
            if focusFailure {
                entryErrorFocused = false
                await Task.yield()
                guard entryRequestID == currentRequestID,
                      authentication.status.user?.id == user.id,
                      !Task.isCancelled else { return }
                entryErrorFocused = true
            }
        }
    }

    @MainActor
    private func save() async {
        currentDate = Date()
        guard isEditable,
              entryState == .ready,
              !isSaving,
              let draft,
              case let .authenticated(user) = authentication.status else {
            return
        }
        let currentRequestID = UUID()
        saveRequestID = currentRequestID
        isSaving = true
        saveFailed = false
        savedConfirmation = false
        do {
            let provider = try scopedProvider
            let entry = try await provider.savePredictionEntry(
                for: game,
                rankings: draft.rankings,
                forAccountID: user.id
            )
            guard saveRequestID == currentRequestID,
                  authentication.status.user?.id == user.id,
                  !Task.isCancelled else { return }
            savedEntry = entry
            self.draft = try PredictionDraft(game: game, entry: entry)
            isSaving = false
            savedConfirmation = true
            focusSaveStatus()
        } catch let error as SportsDataError {
            guard saveRequestID == currentRequestID,
                  authentication.status.user?.id == user.id,
                  !Task.isCancelled else { return }
            isSaving = false
            if error == .forbidden || error == .invalidResponse(statusCode: 409) {
                lockRejected = true
                currentDate = max(currentDate, game.lockAt)
            }
            saveFailed = true
            focusSaveStatus()
        } catch {
            guard saveRequestID == currentRequestID,
                  authentication.status.user?.id == user.id,
                  !Task.isCancelled else { return }
            isSaving = false
            saveFailed = true
            focusSaveStatus()
        }
    }

    @MainActor
    private func focusSaveStatus() {
        saveStatusFocused = false
        Task { @MainActor in
            await Task.yield()
            saveStatusFocused = true
        }
    }

    private func localizedFormat(_ key: String.LocalizationValue, _ value: Int) -> String {
        String(
            format: String(localized: key, locale: appModel.language.locale),
            value
        )
    }

    private func positionAccessibilityLabel(
        teamName: String,
        position: Int,
        qualifies: Bool
    ) -> String {
        let format = qualifies
            ? String(
                localized: "predictions.positionQualifiesAccessibility",
                locale: appModel.language.locale
            )
            : String(
                localized: "predictions.positionAccessibility",
                locale: appModel.language.locale
            )
        return String(format: format, teamName, position)
    }

    private func moveAccessibilityLabel(
        teamName: String,
        direction: PredictionMoveDirection,
        destination: Int
    ) -> String {
        let format: String
        switch direction {
        case .up:
            format = String(
                localized: "predictions.moveUpAccessibility",
                locale: appModel.language.locale
            )
        case .down:
            format = String(
                localized: "predictions.moveDownAccessibility",
                locale: appModel.language.locale
            )
        }
        return String(format: format, teamName, destination)
    }

    private var scopedProvider: any IdentityScopedPredictionProviding {
        get throws {
            guard let provider = appModel.dataProvider
                as? any IdentityScopedPredictionProviding else {
                throw SportsDataError.unauthorized
            }
            return provider
        }
    }
}

private enum PredictionEntryLoadState: Equatable {
    case notRequired
    case loading
    case ready
    case failed
}
