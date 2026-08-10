import Foundation
import SwiftUI

enum MatchLiveUpdatePhase: Equatable, Sendable {
    case connecting
    case waitingForKickoff(lastCheckedAt: Date?)
    case connected(lastUpdatedAt: Date)
    case retrying(attempt: Int)
    case paused
    case ended
    case stopped
    case unavailable

    var requiresAttention: Bool {
        switch self {
        case .retrying, .stopped, .unavailable:
            true
        case .connecting, .waitingForKickoff, .connected, .paused, .ended:
            false
        }
    }

    var identifierSuffix: String {
        switch self {
        case .connecting: "connecting"
        case .waitingForKickoff: "waiting"
        case .connected: "connected"
        case .retrying: "retrying"
        case .paused: "paused"
        case .ended: "ended"
        case .stopped: "stopped"
        case .unavailable: "unavailable"
        }
    }
}

struct MatchLiveStatusView: View {
    let phase: MatchLiveUpdatePhase
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .font(.subheadline.weight(.semibold))
                    detail
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            if phase == .unavailable {
                Button("action.retry", action: retry)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("match.live.retry")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("match.live.status.\(phase.identifierSuffix)")
    }

    @ViewBuilder
    private var detail: some View {
        switch phase {
        case .connecting:
            Text("match.live.connectingBody")
        case let .waitingForKickoff(lastCheckedAt):
            if let lastCheckedAt {
                HStack(spacing: 4) {
                    Text("match.live.lastChecked")
                    Text(lastCheckedAt, style: .relative)
                }
            } else {
                Text("match.live.waitingBody")
            }
        case let .connected(lastUpdatedAt):
            HStack(spacing: 4) {
                Text("match.live.lastUpdate")
                Text(lastUpdatedAt, style: .relative)
            }
        case .retrying:
            Text("match.live.retryingBody")
        case .paused:
            Text("match.live.pausedBody")
        case .ended:
            Text("match.live.endedBody")
        case .stopped:
            Text("match.live.stoppedBody")
        case .unavailable:
            Text("match.live.unavailableBody")
        }
    }

    private var titleKey: LocalizedStringKey {
        switch phase {
        case .connecting: "match.live.connectingTitle"
        case .waitingForKickoff: "match.live.waitingTitle"
        case .connected: "match.live.connectedTitle"
        case .retrying: "match.live.retryingTitle"
        case .paused: "match.live.pausedTitle"
        case .ended: "match.live.endedTitle"
        case .stopped: "match.live.stoppedTitle"
        case .unavailable: "match.live.unavailableTitle"
        }
    }

    private var systemImage: String {
        switch phase {
        case .connecting: "arrow.triangle.2.circlepath"
        case .waitingForKickoff: "clock.badge.checkmark"
        case .connected: "dot.radiowaves.left.and.right"
        case .retrying: "wifi.exclamationmark"
        case .paused: "pause.circle.fill"
        case .ended: "checkmark.circle.fill"
        case .stopped: "minus.circle.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch phase {
        case .connected:
            AppTheme.accent
        case .connecting, .waitingForKickoff, .paused, .ended, .stopped:
            AppTheme.muted
        case .retrying:
            AppTheme.warm
        case .unavailable:
            AppTheme.live
        }
    }
}
