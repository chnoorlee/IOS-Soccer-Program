import SwiftUI
import UIKit

enum ArticleHeroMediaPresentation: Hashable {
    case card
    case leadingCard
    case detail

    var maximumDisplayPixelSize: Int {
        switch self {
        case .card: 960
        case .leadingCard: 1_280
        case .detail: 2_048
        }
    }
}

struct ArticleHeroMediaView: View {
    @EnvironmentObject private var appModel: AppModel

    let article: Article
    let presentation: ArticleHeroMediaPresentation

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var didFail = false
    @State private var retryID = UUID()
    @State private var activeLoadID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            accessibleAperture

            if presentation == .detail,
               let media = article.heroMedia,
               loadedImage != nil {
                Label {
                    Text(verbatim: localizedCredit(media))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "camera.fill")
                        .accessibilityHidden(true)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: localizedCredit(media)))
                .accessibilityIdentifier("article.heroMedia.\(article.id).credit")
            }

            if presentation == .detail, didFail, article.heroMedia != nil {
                Button {
                    retryID = UUID()
                } label: {
                    Label("article.heroMedia.retry", systemImage: "arrow.clockwise")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("article.heroMedia.\(article.id).retry")
            }
        }
        .task(id: LoadIdentity(media: article.heroMedia, retryID: retryID)) {
            await loadMedia()
        }
    }

    @ViewBuilder
    private var accessibleAperture: some View {
        if presentation == .detail, let media = article.heroMedia, loadedImage != nil {
            aperture
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: media.altText(in: appModel.language)))
        } else if presentation == .detail, didFail, article.heroMedia != nil {
            aperture
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("article.heroMedia.unavailable"))
        } else {
            aperture
                .accessibilityHidden(true)
        }
    }

    private var aperture: some View {
        ZStack {
            ArticleHeroFallbackArtwork(
                format: article.format,
                showsFailure: didFail
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
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: presentation == .detail ? 22 : 14,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: presentation == .detail ? 22 : 14,
                style: .continuous
            )
            .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityIdentifier(
            "article.heroMedia.\(article.id).\(accessibilityStateIdentifier)"
        )
    }

    private var accessibilityStateIdentifier: String {
        if loadedImage != nil { return "loaded" }
        if didFail { return "failed" }
        if isLoading { return "loading" }
        return "placeholder"
    }

    @MainActor
    private func loadMedia() async {
        let loadID = UUID()
        activeLoadID = loadID
        loadedImage = nil
        didFail = false
        guard let media = article.heroMedia else {
            isLoading = false
            return
        }

        isLoading = true
        do {
            let data = try await ArticleHeroImagePipeline.shared.data(for: media)
            try Task.checkCancellation()
            let decodedImage = await ArticleHeroImageDecoder.shared.decode(
                data,
                media: media,
                maximumPixelSize: presentation.maximumDisplayPixelSize
            )
            try Task.checkCancellation()
            guard activeLoadID == loadID,
                  let decodedImage else {
                throw ArticleHeroImageLoadError.invalidImage
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

    private func localizedCredit(_ media: ArticleHeroMedia) -> String {
        String(
            format: String(
                localized: "article.heroMedia.creditFormat",
                locale: appModel.language.locale
            ),
            media.credit(in: appModel.language)
        )
    }

    private struct LoadIdentity: Hashable {
        let media: ArticleHeroMedia?
        let retryID: UUID
    }
}

private struct ArticleHeroFallbackArtwork: View {
    let format: ArticleFormat
    let showsFailure: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.ink, AppTheme.accent.opacity(0.84)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack {
                Capsule()
                    .fill(AppTheme.accent)
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
                systemName: format == .visualBrief
                    ? "chart.bar.xaxis.ascending"
                    : "newspaper.fill"
            )
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(.white.opacity(0.88))

            if showsFailure {
                VStack {
                    Spacer(minLength: 0)
                    Label(
                        "article.heroMedia.unavailable",
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
