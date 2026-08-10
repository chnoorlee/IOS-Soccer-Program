import SwiftUI
import UIKit

enum VideoPosterMediaPresentation: Hashable {
    case card
    case featured
    case thumbnail
    case detail

    var maximumDisplayPixelSize: Int {
        switch self {
        case .thumbnail: 480
        case .card: 960
        case .featured: 1_280
        case .detail: 2_048
        }
    }

    var aspectRatio: CGFloat {
        self == .featured ? 4.0 / 3.0 : 16.0 / 9.0
    }

    var cornerRadius: CGFloat {
        switch self {
        case .thumbnail: 12
        case .card: 16
        case .featured, .detail: 22
        }
    }
}

struct VideoPosterMediaView: View {
    @EnvironmentObject private var appModel: AppModel

    let video: SportsVideo
    let presentation: VideoPosterMediaPresentation

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var didFail = false
    @State private var retryID = UUID()
    @State private var activeLoadID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            accessibleAperture

            if presentation == .detail,
               let poster = video.poster,
               loadedImage != nil {
                Label {
                    Text(verbatim: localizedCredit(poster))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "photo.fill")
                        .accessibilityHidden(true)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: localizedCredit(poster)))
                .accessibilityIdentifier("video.poster.\(video.id).credit")
            }

            if presentation == .detail, didFail, video.poster != nil {
                Button {
                    retryID = UUID()
                } label: {
                    Label("video.poster.retry", systemImage: "arrow.clockwise")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("video.poster.\(video.id).retry")
            }
        }
        .task(id: LoadIdentity(poster: video.poster, retryID: retryID)) {
            await loadPoster()
        }
    }

    @ViewBuilder
    private var accessibleAperture: some View {
        if presentation == .detail, let poster = video.poster, loadedImage != nil {
            aperture
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: poster.altText(in: appModel.language)))
        } else if presentation == .detail, didFail, video.poster != nil {
            aperture
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("video.poster.unavailable"))
        } else {
            aperture
                .accessibilityHidden(true)
        }
    }

    private var aperture: some View {
        ZStack {
            VideoPosterFallbackArtwork(
                type: video.type,
                showsFailure: presentation == .detail && didFail
            )

            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(12)
                    .background(.black.opacity(0.42), in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(presentation.aspectRatio, contentMode: .fit)
        .clipped()
        .clipShape(
            RoundedRectangle(cornerRadius: presentation.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: presentation.cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityIdentifier("video.poster.\(video.id).\(stateIdentifier)")
    }

    private var stateIdentifier: String {
        if loadedImage != nil { return "loaded" }
        if didFail { return "failed" }
        if isLoading { return "loading" }
        return "placeholder"
    }

    @MainActor
    private func loadPoster() async {
        let loadID = UUID()
        activeLoadID = loadID
        loadedImage = nil
        didFail = false
        guard let poster = video.poster else {
            isLoading = false
            return
        }

        isLoading = true
        do {
            let data = try await VideoPosterImagePipeline.shared.data(for: poster)
            try Task.checkCancellation()
            let decodedImage = await VideoPosterImageDecoder.shared.decode(
                data,
                media: poster,
                maximumPixelSize: presentation.maximumDisplayPixelSize
            )
            try Task.checkCancellation()
            guard activeLoadID == loadID,
                  let decodedImage else {
                throw VideoPosterImageLoadError.invalidImage
            }
            loadedImage = decodedImage.image
            isLoading = false
        } catch is CancellationError {
            guard activeLoadID == loadID else { return }
            isLoading = false
        } catch {
            guard activeLoadID == loadID else { return }
            loadedImage = nil
            isLoading = false
            didFail = true
        }
    }

    private func localizedCredit(_ poster: VideoPosterMedia) -> String {
        String(
            format: String(
                localized: "video.poster.creditFormat",
                locale: appModel.language.locale
            ),
            poster.credit(in: appModel.language)
        )
    }

    private struct LoadIdentity: Hashable {
        let poster: VideoPosterMedia?
        let retryID: UUID
    }
}

private struct VideoPosterFallbackArtwork: View {
    let type: SportsVideoType
    let showsFailure: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.ink, AppTheme.accent.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack {
                Capsule()
                    .fill(type == .live ? AppTheme.live : AppTheme.accent)
                    .frame(width: 5)
                    .padding(.vertical, 18)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Rectangle()
                        .fill(.white.opacity(0.32))
                        .frame(width: 54, height: 2)
                    Rectangle()
                        .fill(AppTheme.warm)
                        .frame(width: 28, height: 4)
                }
            }
            .padding(.horizontal, 18)

            Image(
                systemName: type == .live
                    ? "dot.radiowaves.left.and.right"
                    : "play.rectangle.fill"
            )
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(.white.opacity(0.88))
            .accessibilityHidden(true)

            if showsFailure {
                VStack {
                    Spacer(minLength: 0)
                    Label(
                        "video.poster.unavailable",
                        systemImage: "photo.badge.exclamationmark"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(12)
                }
            }
        }
    }
}
