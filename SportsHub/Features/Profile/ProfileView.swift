import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var authentication: AuthenticationManager
    @EnvironmentObject private var subscriptionStore: PremiumSubscriptionModel

    var body: some View {
        Form {
            Section("profile.account") {
                accountContent
            }

            if let error = authentication.lastError {
                Section {
                    Label(
                        LocalizedStringKey(error.localizationKey),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(AppTheme.warm)
                    .accessibilityIdentifier("profile.authentication.error")

                    Button("action.dismiss") {
                        authentication.dismissError()
                    }
                    .frame(minHeight: 44)
                }
            }

            Section("profile.premiumSection") {
                NavigationLink {
                    SubscriptionView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "ticket.fill")
                            .foregroundStyle(AppTheme.warm)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("premium.title")
                                .font(.headline)
                            Text(premiumEntryStatusKey)
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                }
                .frame(minHeight: 44)
                .accessibilityHint(Text("premium.entryHint"))
                .accessibilityIdentifier("profile.premium")
            }

            Section("profile.preferences") {
                Picker("profile.language", selection: $appModel.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("profile.appearance") {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityLabel(Text("profile.appearance"))
                }

                NavigationLink {
                    PrivacyDataView()
                } label: {
                    Label("profile.privacy", systemImage: "hand.raised.fill")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("profile.privacy")

                Button {
                    appModel.resetOnboarding()
                } label: {
                    Label("profile.editInterests", systemImage: "slider.horizontal.3")
                }
                .frame(minHeight: 44)
                .accessibilityHint(Text("profile.editInterestsHint"))
                .accessibilityIdentifier("profile.editInterests")
            }

            Section("profile.library") {
                NavigationLink {
                    WatchHistoryView()
                } label: {
                    Label("history.title", systemImage: "clock.arrow.circlepath")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("profile.watchHistory")
            }

            Section("profile.about") {
                Text("profile.aboutBody")
                    .font(.subheadline)

                LabeledContent("common.demoData", value: "0.1.0")
            }

        }
        .navigationTitle("profile.title")
        .accessibilityIdentifier("profile.screen")
        .task {
            await authentication.refreshGuestSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchProgressDidChange)) { _ in
            Task { await authentication.refreshGuestSummary() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoFavoritesDidChange)) { _ in
            Task { await authentication.refreshGuestSummary() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .articleFavoritesDidChange)) { _ in
            Task { await authentication.refreshGuestSummary() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .followsDidChange)) { _ in
            Task { await authentication.refreshGuestSummary() }
        }
    }

    private var premiumEntryStatusKey: LocalizedStringKey {
        if subscriptionStore.isPremiumActive {
            return "premium.status.activeShort"
        }
        if subscriptionStore.configuration.isPreview {
            return "premium.status.previewShort"
        }
        switch subscriptionStore.configuration.state {
        case .ready: return "premium.status.availableShort"
        case .unconfigured: return "premium.status.unconfiguredShort"
        case .invalid: return "premium.status.invalidShort"
        }
    }

    @ViewBuilder
    private var accountContent: some View {
        switch authentication.status {
        case .loading:
            ProgressView("profile.accountLoading")
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("profile.authentication.loading")
        case .unavailable:
            guestIdentityLabel
            Text("profile.accountUnavailable")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            guestSummary
        case .signedOut:
            guestIdentityLabel
            Text("profile.guestBody")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            guestSummary
            AppleSignInControl(
                isEnabled: !authentication.isBusy,
                onCredential: { credential in
                    await authentication.signIn(with: credential)
                },
                onFailure: { error in
                    authentication.reportSignInFailure(error)
                }
            )
        case let .authenticated(user):
            authenticatedIdentity(user)
            pendingMerge
            mergeResult
            Button("profile.signOut", role: .destructive) {
                Task { await authentication.signOut() }
            }
            .disabled(authentication.isBusy)
            .frame(minHeight: 44)
            .accessibilityIdentifier("profile.signOut")

            NavigationLink {
                AccountDeletionView()
            } label: {
                Label {
                    Text("profile.deleteAccount")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.live)
                }
            }
            .disabled(authentication.isBusy)
            .frame(minHeight: 44)
            .accessibilityIdentifier("profile.deleteAccount")
        }

        if authentication.isBusy, authentication.status != .loading {
            ProgressView("profile.accountWorking")
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("profile.authentication.working")
        }
    }

    private var guestIdentityLabel: some View {
        Label("profile.guestMode", systemImage: "person.crop.circle")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("profile.authentication.guest")
    }

    @ViewBuilder
    private var guestSummary: some View {
        if authentication.guestSummary.hasMergeableData {
            Text(
                "profile.guestSummary \(authentication.guestSummary.progressCount) \(authentication.guestSummary.favoriteCount) \(authentication.guestSummary.articleFavoriteCount) \(authentication.guestSummary.followCount)"
            )
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("profile.guestSummary")
        }
    }

    private func authenticatedIdentity(_ user: AuthUser) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(verbatim: user.displayName)
            } icon: {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
            }
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let email = user.email {
                Text(verbatim: email)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.authentication.account")
    }

    @ViewBuilder
    private var pendingMerge: some View {
        if authentication.guestSummary.hasMergeableData {
            VStack(alignment: .leading, spacing: 8) {
                Label("profile.mergeGuestTitle", systemImage: "arrow.triangle.merge")
                    .font(.subheadline.weight(.bold))
                Text(
                    "profile.mergeGuestSummary \(authentication.guestSummary.progressCount) \(authentication.guestSummary.favoriteCount) \(authentication.guestSummary.articleFavoriteCount) \(authentication.guestSummary.followCount)"
                )
                .font(.subheadline)
                Text("profile.mergeGuestPolicy")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                Button("profile.mergeGuestAction") {
                    Task { await authentication.mergeGuestPersonalization() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authentication.isBusy)
                .frame(minHeight: 44)
                .accessibilityHint(Text("profile.mergeGuestPolicy"))
                .accessibilityIdentifier("profile.mergeGuest")
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var mergeResult: some View {
        if let result = authentication.lastMergeResult {
            VStack(alignment: .leading, spacing: 8) {
                Label("profile.mergeComplete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(
                    "profile.mergeResult \(result.progressUpserted) \(result.favoritesUpserted) \(result.articleFavoritesUpserted) \(result.followsUpserted) \(result.serverNewerRetained)"
                )
                .font(.caption)
                Button("action.dismiss") {
                    authentication.dismissMergeResult()
                }
                .frame(minHeight: 44)
            }
            .accessibilityIdentifier("profile.mergeResult")
        }
    }
}
