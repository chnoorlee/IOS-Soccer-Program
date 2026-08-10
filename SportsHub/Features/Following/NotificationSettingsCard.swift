import SwiftUI

struct NotificationSettingsCard: View {
    @EnvironmentObject private var authentication: AuthenticationManager
    @EnvironmentObject private var settings: NotificationSettingsModel
    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("following.alerts", systemImage: "bell.badge.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("following.alertsDescription")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)

            if authentication.status.user == nil {
                accountRequired
            } else {
                authorizationContent
            }

            if let error = settings.error {
                errorContent(error)
            }
        }
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notifications.card")
        .onChange(of: settings.error) { _, error in
            isErrorFocused = error != nil
        }
    }

    @ViewBuilder
    private var authorizationContent: some View {
        switch settings.authorizationStatus {
        case .unknown:
            if settings.isLoading {
                ProgressView("notifications.loading")
                    .frame(minHeight: 44)
            } else {
                retryButton
            }
        case .notDetermined:
            Text("notifications.permissionBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            Button {
                Task { await settings.requestAuthorization() }
            } label: {
                if settings.isRequestingAuthorization {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("notifications.enable")
                    }
                } else {
                    Text("notifications.enable")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(settings.isRequestingAuthorization)
            .frame(minHeight: 44)
            .accessibilityIdentifier("notifications.enable")
        case .denied:
            Label("notifications.deniedTitle", systemImage: "bell.slash.fill")
                .font(.subheadline.weight(.semibold))
            Text("notifications.deniedBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            Button("notifications.openSettings") {
                Task { await settings.openSystemSettings() }
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("notifications.openSettings")
        case .authorized, .provisional, .ephemeral:
            registrationStatus
            preferencesContent
        }
    }

    private var accountRequired: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("notifications.accountRequiredTitle", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
            Text("notifications.accountRequiredBody")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("notifications.accountRequired")
    }

    @ViewBuilder
    private var registrationStatus: some View {
        switch settings.pushRegistrationState {
        case .idle:
            EmptyView()
        case .registering:
            ProgressView("notifications.registration.registering")
                .frame(minHeight: 44)
                .accessibilityIdentifier("notifications.registration.registering")
        case .registered:
            Label("notifications.registration.registered", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
                .frame(minHeight: 44)
                .accessibilityIdentifier("notifications.registration.registered")
        case .failed:
            Label("notifications.registration.failed", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
                .frame(minHeight: 44)
                .accessibilityIdentifier("notifications.registration.failed")
        }
    }

    @ViewBuilder
    private var preferencesContent: some View {
        if let preferences = settings.preferences {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(NotificationPreferenceType.allCases) { type in
                    Toggle(
                        LocalizedStringKey(type.localizationKey),
                        isOn: Binding(
                            get: { preferences[type] },
                            set: { enabled in
                                Task {
                                    await settings.setPreference(type, enabled: enabled)
                                }
                            }
                        )
                    )
                    .tint(AppTheme.accent)
                    .disabled(!settings.updatingPreferences.isEmpty)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("notifications.preference.\(type.rawValue)")
                }
            }
        } else if settings.isLoading {
            ProgressView("notifications.preferencesLoading")
                .frame(minHeight: 44)
        } else if settings.error == nil {
            retryButton
        }
    }

    private func errorContent(_ error: NotificationSettingsError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(LocalizedStringKey(error.localizationKey))
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.warm)
            .accessibilityFocused($isErrorFocused)

            HStack {
                Button("action.retry") {
                    Task { await settings.refresh() }
                }
                .frame(minHeight: 44)

                Button("action.dismiss") {
                    settings.dismissError()
                }
                .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notifications.error")
    }

    private var retryButton: some View {
        Button("action.retry") {
            Task { await settings.refresh() }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("notifications.retry")
    }
}
