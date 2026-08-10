import SwiftUI

enum ContextualAlertTarget: Hashable, Sendable {
    case entity(FollowEntitySnapshot)
    case fixture(Fixture)

    func presentation(follows: [SportsFollow]) -> ContextualAlertPresentation {
        switch self {
        case let .entity(entity):
            ContextualAlertPresentation(
                entityType: entity.type,
                entityID: entity.entityID,
                follows: follows
            )
        case let .fixture(fixture):
            ContextualAlertPresentation(fixture: fixture, follows: follows)
        }
    }

    var followChoices: [FollowEntitySnapshot] {
        switch self {
        case let .entity(entity):
            [entity]
        case let .fixture(fixture):
            [
                .team(fixture.homeTeam),
                .team(fixture.awayTeam),
                .competition(fixture.competition)
            ]
        }
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case let .entity(entity):
            entity.displayName(in: language)
        case let .fixture(fixture):
            let home = fixture.homeTeam.displayName(in: language)
            let away = fixture.awayTeam.displayName(in: language)
            return "\(home) — \(away)"
        }
    }

    var subtitleLocalizationKey: String? {
        switch self {
        case let .entity(entity):
            entity.type.localizationKey
        case .fixture:
            nil
        }
    }

    func subtitle(in language: AppLanguage) -> String? {
        guard case let .fixture(fixture) = self else { return nil }
        return fixture.competition.displayName(in: language)
    }

    var ineligibleTitleKey: LocalizedStringKey {
        switch self {
        case .entity: "contextualAlerts.ineligible.entityTitle"
        case .fixture: "contextualAlerts.ineligible.fixtureTitle"
        }
    }

    var ineligibleBodyKey: LocalizedStringKey {
        switch self {
        case .entity: "contextualAlerts.ineligible.entityBody"
        case .fixture: "contextualAlerts.ineligible.fixtureBody"
        }
    }
}

struct ContextualAlertSettingsButton: View {
    let target: ContextualAlertTarget
    let accessibilityIdentifier: String
    var compact = false

    @State private var isPresented = false

    var body: some View {
        Group {
            if compact {
                Button {
                    isPresented = true
                } label: {
                    Image(systemName: "bell")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("contextualAlerts.manage"))
                .accessibilityHint(Text("contextualAlerts.buttonHint"))
                .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                Button {
                    isPresented = true
                } label: {
                    Label("contextualAlerts.manage", systemImage: "bell")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityHint(Text("contextualAlerts.buttonHint"))
                .accessibilityIdentifier(accessibilityIdentifier)
            }
        }
        .sheet(isPresented: $isPresented) {
            ContextualAlertSettingsSheet(target: target)
        }
    }
}

private struct ContextualAlertSettingsSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var followErrorFocused: Bool

    let target: ContextualAlertTarget

    private var presentation: ContextualAlertPresentation {
        target.presentation(follows: appModel.orderedFollows)
    }

    private var isSettlingFollow: Bool {
        target.followChoices.contains { entity in
            appModel.isFollowMutationInProgress(
                type: entity.type,
                entityID: entity.entityID
            )
        }
    }

    private var isEligibleForSettings: Bool {
        presentation.eligibility.isEligible && !isSettlingFollow
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    contextCard
                    eligibilityCard
                    globalScopeCard

                    if appModel.followError != nil {
                        followErrorCard
                    }

                    if isSettlingFollow {
                        EmptyView()
                    } else if isEligibleForSettings {
                        NotificationSettingsCard()
                    } else {
                        followChoices
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .accessibilityIdentifier("contextualAlerts.sheet")
            .navigationTitle("contextualAlerts.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("contextualAlerts.close") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("contextualAlerts.close")
                }
            }
        }
        .task(id: isEligibleForSettings) {
            guard isEligibleForSettings else { return }
            await appModel.notificationSettings.refresh()
        }
        .onChange(of: appModel.followError) { _, error in
            followErrorFocused = error != nil
        }
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(target.title(in: appModel.language))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "bell.badge")
                    .foregroundStyle(AppTheme.accent)
            }
            contextSubtitle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("contextualAlerts.context")
    }

    @ViewBuilder
    private var contextSubtitle: some View {
        if let key = target.subtitleLocalizationKey {
            Text(LocalizedStringKey(key))
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        } else if let subtitle = target.subtitle(in: appModel.language) {
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
    }

    @ViewBuilder
    private var eligibilityCard: some View {
        if isSettlingFollow {
            HStack(spacing: 10) {
                ProgressView()
                Text("contextualAlerts.updatingAudience")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .sportsCard()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("contextualAlerts.updatingAudience")
        } else if let key = presentation.eligibility.localizationKey {
            Label {
                Text(LocalizedStringKey(key))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .sportsCard()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("contextualAlerts.eligible")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label(target.ineligibleTitleKey, systemImage: "bell.slash")
                    .font(.subheadline.weight(.semibold))
                Text(target.ineligibleBodyKey)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sportsCard()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("contextualAlerts.ineligible")
        }
    }

    private var globalScopeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("contextualAlerts.globalTitle", systemImage: "person.2.badge.gearshape")
                .font(.subheadline.weight(.semibold))
            Text("contextualAlerts.globalBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("contextualAlerts.scope")
    }

    private var followChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("contextualAlerts.followChoices")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(target.followChoices, id: \.self) { entity in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entity.displayName(in: appModel.language))
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(LocalizedStringKey(entity.type.localizationKey))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    SportsFollowButton(
                        type: entity.type,
                        entityID: entity.entityID,
                        entity: entity,
                        accessibilityIdentifier: "contextualAlerts.follow.\(entity.type.rawValue).\(entity.entityID)"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .sportsCard()
            }
        }
        .accessibilityIdentifier("contextualAlerts.followChoices")
    }

    private var followErrorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("following.syncFailed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            Text("following.syncFailedBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            Button("action.dismiss") {
                appModel.dismissFollowError()
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityFocused($followErrorFocused)
        .accessibilityIdentifier("contextualAlerts.followError")
    }
}
