import SwiftUI

struct FeaturedVideoCard: View {
    @EnvironmentObject private var appModel: AppModel
    let item: VideoDiscoveryItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VideoPosterMediaView(video: item.video, presentation: .featured)
                .accessibilityHidden(true)

            LinearGradient(
                colors: [.clear, AppTheme.ink.opacity(0.3), AppTheme.ink.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                Text("video.featured")
                    .font(.caption.weight(.black))
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(AppTheme.ink)
                    .background(.white)
                    .clipShape(Capsule())

                Text(item.video.title(in: appModel.language))
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                metadata

                if !item.video.isPlayable {
                    Label(
                        LocalizedStringKey(
                            (item.video.availabilityReason ?? .unavailable).localizationKey
                        ),
                        systemImage: "lock.fill"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("video.featured.\(item.id)")
        .accessibilityHint(Text("accessibility.opensVideo"))
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { metadataLabels }
            VStack(alignment: .leading, spacing: 6) { metadataLabels }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var metadataLabels: some View {
        Label(
            LocalizedStringKey(item.video.type.localizationKey),
            systemImage: "play.circle.fill"
        )
        Label(
            LocalizedStringKey(item.sport.localizationKey),
            systemImage: item.sport.systemImage
        )
        if item.video.type != .live {
            Label(item.video.durationText, systemImage: "clock.fill")
        }
    }
}

struct TrendingVideoCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rankedItem: RankedVideoDiscoveryItem

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    rankBadge
                    VideoPosterMediaView(
                        video: rankedItem.item.video,
                        presentation: .thumbnail
                    )
                    .accessibilityHidden(true)
                    details
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    rankBadge
                    VideoPosterMediaView(
                        video: rankedItem.item.video,
                        presentation: .thumbnail
                    )
                    .frame(width: 96)
                    .accessibilityHidden(true)
                    details
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            "video.trending.\(rankedItem.rank).\(rankedItem.item.id)"
        )
        .accessibilityHint(Text("accessibility.opensVideo"))
    }

    private var rankBadge: some View {
        VStack(spacing: 2) {
            Text("video.trending.rank")
                .font(.caption2.weight(.bold))
            Text("#\(rankedItem.rank)")
                .font(.title2.monospacedDigit().weight(.black))
        }
        .foregroundStyle(.white)
        .frame(minWidth: 62, maxWidth: 62, minHeight: 62)
        .background(AppTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(rankedItem.item.video.title(in: appModel.language))
                .font(.headline)
                .multilineTextAlignment(.leading)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { metadataLabels }
                VStack(alignment: .leading, spacing: 5) { metadataLabels }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.muted)

            if !rankedItem.item.video.isPlayable {
                Label(
                    LocalizedStringKey(
                        (rankedItem.item.video.availabilityReason ?? .unavailable).localizationKey
                    ),
                    systemImage: "lock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            }
        }
    }

    @ViewBuilder
    private var metadataLabels: some View {
        Label(
            LocalizedStringKey(rankedItem.item.video.type.localizationKey),
            systemImage: "play.circle"
        )
        Label(
            LocalizedStringKey(rankedItem.item.sport.localizationKey),
            systemImage: rankedItem.item.sport.systemImage
        )
        if rankedItem.item.video.type != .live {
            Label(rankedItem.item.video.durationText, systemImage: "clock")
        }
    }
}
