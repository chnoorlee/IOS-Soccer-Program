import SwiftUI

struct VideoCard: View {
    @EnvironmentObject private var appModel: AppModel
    let video: SportsVideo
    let continuation: ContinueWatchingItem?

    init(video: SportsVideo, continuation: ContinueWatchingItem? = nil) {
        self.video = video
        self.continuation = continuation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                VideoPosterMediaView(video: video, presentation: .card)
                    .accessibilityHidden(true)

                if video.type != .live {
                    Image(systemName: "play.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(13)
                        .background(.black.opacity(0.56), in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHidden(true)
                }

                HStack {
                    StatusPill(
                        text: LocalizedStringKey(video.type.localizationKey),
                        color: video.type == .live ? AppTheme.live : AppTheme.accent
                    )
                    Spacer()
                    if video.type != .live {
                        Text(video.durationText)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .foregroundStyle(.white)
                            .background(.black.opacity(0.72))
                            .clipShape(Capsule())
                    }
                }
                .padding(12)
            }
            .accessibilityHidden(true)

            Text(video.title(in: appModel.language))
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.leading)

            if !video.description(in: appModel.language).isEmpty {
                Text(video.description(in: appModel.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            if let continuation {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: continuation.fractionCompleted)
                        .tint(AppTheme.accent)
                        .accessibilityHidden(true)
                    Text("video.progressPercent \(continuation.percentageCompleted)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    Text("video.progressAccessibility \(continuation.percentageCompleted)")
                )
            }

            if !video.isPlayable {
                Label(
                    LocalizedStringKey((video.availabilityReason ?? .unavailable).localizationKey),
                    systemImage: "lock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityIdentifier("video.card.\(video.id)")
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("accessibility.opensVideo"))
    }
}
