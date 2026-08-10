import SwiftUI

struct AccountDeletionView: View {
    private enum PresentedAlert: Identifiable {
        case failure(AuthenticationError)
        case completion(localCleanupFailed: Bool)

        var id: String {
            switch self {
            case .failure:
                "failure"
            case .completion:
                "completion"
            }
        }
    }

    @EnvironmentObject private var authentication: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var showsConfirmation = false
    @State private var presentedAlert: PresentedAlert?
    @AccessibilityFocusState private var warningFocused: Bool

    var body: some View {
        List {
            Section {
                Label {
                    Text("accountDeletion.warningTitle")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.live)
                }
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($warningFocused)
                .accessibilityIdentifier("accountDeletion.warning")

                Text("accountDeletion.warningBody")
                    .font(.subheadline)
            }

            Section("accountDeletion.deletesTitle") {
                deletionRow("accountDeletion.itemAccount", systemImage: "person.crop.circle")
                deletionRow("accountDeletion.itemPersonalization", systemImage: "star")
                deletionRow("accountDeletion.itemNotifications", systemImage: "bell.slash")
                deletionRow("accountDeletion.itemDevice", systemImage: "iphone")
            }

            Section {
                Text("accountDeletion.legal")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }

            Section {
                Button("accountDeletion.action", role: .destructive) {
                    showsConfirmation = true
                }
                .disabled(authentication.isBusy)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityHint(Text("accountDeletion.actionHint"))
                .accessibilityIdentifier("accountDeletion.action")
            }

            if authentication.isBusy {
                Section {
                    ProgressView("accountDeletion.working")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("accountDeletion.working")
                }
            }
        }
        .navigationTitle("accountDeletion.title")
        .accessibilityIdentifier("accountDeletion.screen")
        .confirmationDialog(
            "accountDeletion.confirmTitle",
            isPresented: $showsConfirmation,
            titleVisibility: .visible
        ) {
            Button("accountDeletion.confirmAction", role: .destructive) {
                requestDeletion()
            }
            .accessibilityIdentifier("accountDeletion.confirm")
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("accountDeletion.confirmBody")
        }
        .alert(item: $presentedAlert) { alert in
            switch alert {
            case let .failure(error):
                Alert(
                    title: Text("accountDeletion.failedTitle"),
                    message: Text(LocalizedStringKey(error.localizationKey)),
                    primaryButton: .default(Text("action.retry")) {
                        requestDeletion()
                    },
                    secondaryButton: .cancel(Text("action.cancel"))
                )
            case let .completion(localCleanupFailed):
                Alert(
                    title: Text("accountDeletion.completeTitle"),
                    message: localCleanupFailed
                        ? Text("accountDeletion.completeCleanupWarning")
                        : Text("accountDeletion.completeBody"),
                    dismissButton: .default(Text("action.done")) {
                        dismiss()
                    }
                )
            }
        }
        .task {
            authentication.dismissError()
            await Task.yield()
            warningFocused = true
        }
    }

    private func deletionRow(_ titleKey: LocalizedStringKey, systemImage: String) -> some View {
        Label(titleKey, systemImage: systemImage)
            .font(.subheadline)
    }

    private func requestDeletion() {
        guard !authentication.isBusy else { return }
        Task {
            let deleted = await authentication.deleteAccount()
            if deleted {
                presentedAlert = .completion(
                    localCleanupFailed: authentication.lastError == .secureStorageUnavailable
                )
            } else if let error = authentication.lastError {
                presentedAlert = .failure(error)
            }
        }
    }
}
