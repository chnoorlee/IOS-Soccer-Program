import SwiftUI

struct PublicContentStatusView: View {
    let freshness: PublicContentFreshness
    let identifier: String

    var body: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("freshness.\(identifier).\(freshness.source.rawValue)")
    }

    @ViewBuilder
    private var detail: some View {
        switch freshness.source {
        case .network:
            timestamp("freshness.updatedAt", date: freshness.checkedAt)
        case .revalidated:
            timestamp("freshness.verifiedAt", date: freshness.checkedAt)
        case .offlineSnapshot:
            VStack(alignment: .leading, spacing: 2) {
                timestamp("freshness.snapshotAt", date: freshness.contentStoredAt)
                Text("freshness.offlineBody")
            }
        case .accountLive:
            Text("freshness.accountLiveBody")
        case .demo:
            Text("freshness.demoBody")
        case .demoFallback:
            Text("freshness.demoFallbackBody")
        case .refreshFailed:
            Text("freshness.refreshFailedBody")
        }
    }

    @ViewBuilder
    private func timestamp(_ key: LocalizedStringKey, date: Date?) -> some View {
        if let date {
            HStack(spacing: 4) {
                Text(key)
                Text(date, style: .relative)
            }
        }
    }

    private var titleKey: LocalizedStringKey {
        switch freshness.source {
        case .network: "freshness.networkTitle"
        case .revalidated: "freshness.revalidatedTitle"
        case .offlineSnapshot: "freshness.offlineTitle"
        case .accountLive: "freshness.accountLiveTitle"
        case .demo: "common.demoData"
        case .demoFallback: "freshness.demoFallbackTitle"
        case .refreshFailed: "freshness.refreshFailedTitle"
        }
    }

    private var systemImage: String {
        switch freshness.source {
        case .network: "arrow.triangle.2.circlepath.circle.fill"
        case .revalidated: "checkmark.icloud.fill"
        case .offlineSnapshot: "wifi.slash"
        case .accountLive: "person.crop.circle.badge.checkmark"
        case .demo: "testtube.2"
        case .demoFallback: "exclamationmark.arrow.triangle.2.circlepath"
        case .refreshFailed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch freshness.source {
        case .network, .revalidated, .accountLive:
            AppTheme.accent
        case .offlineSnapshot, .demoFallback:
            AppTheme.warm
        case .refreshFailed:
            AppTheme.live
        case .demo:
            AppTheme.muted
        }
    }
}
