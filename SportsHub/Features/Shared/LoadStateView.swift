import SwiftUI

struct LoadStateView: View {
    enum State {
        case loading
        case empty
        case error
    }

    let state: State
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            switch state {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                Text("common.loading")
                    .foregroundStyle(AppTheme.muted)

            case .empty:
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)
                Text("common.empty")
                    .font(.headline)

            case .error:
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.warm)
                    .accessibilityHidden(true)
                Text("common.error")
                    .font(.headline)
                if let retry {
                    Button("action.retry", action: retry)
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding()
    }
}

