import Foundation
import SwiftUI

struct VideoDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    let videoID: String
    let preview: SportsVideo?

    @State private var details: SportsVideoDetails?
    @State private var failed = false
    @State private var isRequestingPlayback = false
    @State private var playbackFailure: PlaybackRequestFailure?
    @State private var playbackSession: PlaybackSession?
    @State private var playbackRequestID: UUID?
    @State private var initialProgress: WatchProgress?
    @State private var isFavorite = false
    @State private var isRequestingFavorite = false
    @State private var favoriteFailure: PersonalStateFailure?
    @State private var favoriteRequestID: UUID?
    @State private var freshness: PublicContentFreshness?
    @State private var loadRequestID: UUID?
    @State private var personalStateRequestID: UUID?
    @AccessibilityFocusState private var freshnessFocused: Bool

    init(video: SportsVideo) {
        videoID = video.id
        preview = video
    }

    init(videoID: String, preview: SportsVideo? = nil) {
        self.videoID = videoID
        self.preview = preview
    }

    var body: some View {
        Group {
            if let details {
                videoContent(details)
            } else if failed {
                LoadStateView(state: .error) {
                    Task { await load(announceFreshness: true) }
                }
            } else {
                LoadStateView(state: .loading)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("explore.videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let video = details?.video ?? preview {
                    SportsShareButton(
                        route: .video(video.id),
                        fallbackText: video.title(in: appModel.language),
                        accessibilityHint: "accessibility.sharesVideo"
                    )
                }
            }
        }
        .task(id: videoID) { await load() }
        .task(id: playbackRequestID) {
            guard playbackRequestID != nil, let video = details?.video else { return }
            await requestPlayback(for: video)
        }
        .task(id: favoriteRequestID) {
            guard favoriteRequestID != nil else { return }
            await updateFavorite()
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationStateDidChange)) { _ in
            personalStateRequestID = nil
            favoriteRequestID = nil
            playbackRequestID = nil
            playbackSession = nil
            initialProgress = nil
            isFavorite = false
            favoriteFailure = nil
            playbackFailure = nil
            Task { await loadPersonalState() }
        }
        .fullScreenCover(item: $playbackSession, onDismiss: {
            Task { await refreshWatchProgress() }
        }) { session in
            if let video = details?.video {
                PlaybackView(
                    session: session,
                    video: video,
                    initialProgress: initialProgress
                )
            }
        }
    }

    private func videoContent(_ details: SportsVideoDetails) -> some View {
        let video = details.video
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let freshness {
                    PublicContentStatusView(
                        freshness: freshness,
                        identifier: "video"
                    )
                    .accessibilityFocused($freshnessFocused)
                }

                VideoPosterMediaView(video: video, presentation: .detail)

                HStack {
                    StatusPill(
                        text: LocalizedStringKey(video.type.localizationKey),
                        color: video.type == .live ? AppTheme.live : AppTheme.accent
                    )
                    Spacer()
                    if video.type != .live {
                        Label(video.durationText, systemImage: "clock")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                }

                Text(video.title(in: appModel.language))
                    .font(.largeTitle.weight(.black))
                    .multilineTextAlignment(.leading)
                    .accessibilityAddTraits(.isHeader)

                if !video.description(in: appModel.language).isEmpty {
                    ExpandableVideoDescription(
                        text: video.description(in: appModel.language)
                    )
                    .id("\(video.id)-\(appModel.language.rawValue)")
                }

                favoriteCard

                availabilityCard(video)

                editorialContext(details)

                if !details.audioLanguages.isEmpty || !details.subtitleLanguages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        if !details.audioLanguages.isEmpty {
                            LabeledContent(
                                "video.audio",
                                value: localizedLanguages(details.audioLanguages)
                            )
                        }
                        if !details.subtitleLanguages.isEmpty {
                            LabeledContent(
                                "video.subtitles",
                                value: localizedLanguages(details.subtitleLanguages)
                            )
                        }
                    }
                    .sportsCard()
                }

                if !details.relatedVideos.isEmpty {
                    relatedVideos(details.relatedVideos)
                }
            }
            .padding(16)
        }
        .refreshable { await load(announceFreshness: true) }
        .accessibilityIdentifier("video.detail")
    }

    @ViewBuilder
    private func editorialContext(_ details: SportsVideoDetails) -> some View {
        let publisher = details.publisher(in: appModel.language)
        if publisher != nil || details.program != nil || details.publishedAt != nil {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "video.about")

                if let publisher {
                    LabeledContent("video.publisher", value: publisher)
                        .accessibilityIdentifier("video.publisher")
                }
                if let program = details.program {
                    NavigationLink {
                        VideoProgramDetailView(
                            programID: program.id,
                            previewProgram: program
                        )
                    } label: {
                        HStack(spacing: 10) {
                            Text("video.program")
                            Spacer(minLength: 0)
                            Text(program.title(in: appModel.language))
                                .foregroundStyle(AppTheme.muted)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.forward")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.muted)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("video.programs.openFromVideoHint"))
                    .accessibilityIdentifier("video.program")
                }
                if let publishedAt = details.publishedAt {
                    LabeledContent(
                        "video.published",
                        value: publishedAt,
                        format: .dateTime.day().month().year()
                    )
                }
            }
            .sportsCard()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("video.editorialContext")
        }
    }

    private func relatedVideos(_ videos: [SportsVideo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "video.related")
            ForEach(videos) { video in
                NavigationLink {
                    VideoDetailView(video: video)
                } label: {
                    VideoCard(video: video)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("video.related.\(video.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.related")
    }

    private func availabilityCard(_ video: SportsVideo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if video.isPlayable {
                Button {
                    guard playbackRequestID == nil else { return }
                    playbackRequestID = UUID()
                } label: {
                    if isRequestingPlayback {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("video.authorizing")
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    } else {
                        Label("video.watchNow", systemImage: "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequestingPlayback)
                .accessibilityIdentifier("video.watch")
            } else {
                Label(
                    LocalizedStringKey((video.availabilityReason ?? .unavailable).localizationKey),
                    systemImage: "lock.fill"
                )
                .foregroundStyle(AppTheme.warm)
            }

            if let playbackFailure {
                Label(
                    LocalizedStringKey(playbackFailure.localizationKey),
                    systemImage: playbackFailure.systemImage
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
                .accessibilityIdentifier("video.playback.error")
            }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.availability")
    }

    private var favoriteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                guard favoriteRequestID == nil else { return }
                favoriteRequestID = UUID()
            } label: {
                if isRequestingFavorite {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("video.updatingSaved")
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                } else if isFavorite {
                    Label("video.removeFromSaved", systemImage: "bookmark.slash.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    Label("video.saveVideo", systemImage: "bookmark.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRequestingFavorite)
            .accessibilityIdentifier("video.favorite")
            .accessibilityHint(Text("video.favoriteHint"))

            if let favoriteFailure {
                Label(
                    LocalizedStringKey(favoriteFailure.localizationKey),
                    systemImage: favoriteFailure.systemImage
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.warm)
                .accessibilityIdentifier("video.favorite.error")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsCard()
        .accessibilityElement(children: .contain)
    }

    @MainActor
    private func load(announceFreshness: Bool = false) async {
        let requestID = UUID()
        loadRequestID = requestID
        failed = false
        playbackFailure = nil
        do {
            let loadedDetails = try await appModel.dataProvider.videoDetails(id: videoID)
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            details = loadedDetails
            await loadPersonalState()
            guard loadRequestID == requestID, !Task.isCancelled else { return }
        } catch let error as SportsDataError {
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            if error == .contentWithdrawn || error == .forbidden || error == .notFound {
                details = nil
            }
            failed = true
        } catch {
            guard loadRequestID == requestID, !Task.isCancelled else { return }
            failed = true
        }
        let updated = await appModel.publicContentFreshness(
            for: .video(id: videoID)
        )
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshness = updated
        guard announceFreshness || updated?.requiresAttention == true else { return }
        freshnessFocused = false
        await Task.yield()
        guard loadRequestID == requestID, !Task.isCancelled else { return }
        freshnessFocused = updated != nil
    }

    @MainActor
    private func loadPersonalState() async {
        let requestID = UUID()
        personalStateRequestID = requestID
        let provider = appModel.dataProvider
        async let progressRequest = provider.watchProgress(videoID: videoID)
        async let favoriteRequest = provider.videoFavorite(videoID: videoID)

        let loadedProgress: WatchProgress?
        do {
            loadedProgress = try await progressRequest
        } catch {
            loadedProgress = nil
        }

        let loadedFavorite: Bool
        let loadedFailure: PersonalStateFailure?
        do {
            let state = try await favoriteRequest
            loadedFavorite = state.isFavorite
            loadedFailure = nil
        } catch let error as SportsDataError {
            loadedFavorite = false
            loadedFailure = PersonalStateFailure(error: error)
        } catch {
            loadedFavorite = false
            loadedFailure = .temporary
        }
        guard personalStateRequestID == requestID, !Task.isCancelled else { return }
        initialProgress = loadedProgress
        isFavorite = loadedFavorite
        favoriteFailure = loadedFailure
    }

    @MainActor
    private func refreshWatchProgress() async {
        let requestID = UUID()
        personalStateRequestID = requestID
        do {
            let loadedProgress = try await appModel.dataProvider.watchProgress(videoID: videoID)
            guard personalStateRequestID == requestID, !Task.isCancelled else { return }
            initialProgress = loadedProgress
            NotificationCenter.default.post(name: .watchProgressDidChange, object: nil)
        } catch {
            guard personalStateRequestID == requestID, !Task.isCancelled else { return }
            initialProgress = nil
        }
    }

    @MainActor
    private func updateFavorite() async {
        guard !isRequestingFavorite else { return }
        isRequestingFavorite = true
        favoriteFailure = nil
        defer {
            isRequestingFavorite = false
            favoriteRequestID = nil
        }

        do {
            let state = try await appModel.dataProvider.setVideoFavorite(
                videoID: videoID,
                isFavorite: !isFavorite
            )
            guard !Task.isCancelled else { return }
            isFavorite = state.isFavorite
            NotificationCenter.default.post(name: .videoFavoritesDidChange, object: nil)
        } catch let error as SportsDataError {
            guard !Task.isCancelled else { return }
            favoriteFailure = PersonalStateFailure(error: error)
        } catch {
            guard !Task.isCancelled else { return }
            favoriteFailure = .temporary
        }
    }

    @MainActor
    private func requestPlayback(for video: SportsVideo) async {
        guard video.isPlayable, !isRequestingPlayback else { return }
        isRequestingPlayback = true
        playbackFailure = nil
        defer {
            isRequestingPlayback = false
            playbackRequestID = nil
        }

        do {
            let session = try await appModel.dataProvider.createPlaybackSession(
                videoID: video.id,
                deviceID: appModel.playbackDeviceID,
                capabilities: appModel.playbackCapabilities
            )
            guard !Task.isCancelled else { return }
            guard !session.isExpired(), session.fairPlay == nil else {
                playbackFailure = .configuration
                return
            }
            playbackSession = session
        } catch let error as SportsDataError {
            guard !Task.isCancelled else { return }
            playbackFailure = PlaybackRequestFailure(error: error)
        } catch {
            guard !Task.isCancelled else { return }
            playbackFailure = .temporary
        }
    }

    private func localizedLanguages(_ codes: [String]) -> String {
        codes.map { code in
            appModel.language.locale.localizedString(forLanguageCode: code) ?? code
        }
        .joined(separator: ", ")
    }

    private enum PlaybackRequestFailure: Hashable {
        case signInRequired
        case rightsUnavailable
        case temporary
        case configuration

        init(error: SportsDataError) {
            switch error {
            case .unauthorized:
                self = .signInRequired
            case .forbidden, .notFound, .contentWithdrawn:
                self = .rightsUnavailable
            case let .invalidResponse(statusCode) where statusCode == 409:
                self = .rightsUnavailable
            case .networkUnavailable, .rateLimited, .serverUnavailable:
                self = .temporary
            default:
                self = .configuration
            }
        }

        var localizationKey: String {
            switch self {
            case .signInRequired: "video.playbackSignInRequired"
            case .rightsUnavailable: "video.playbackRightsUnavailable"
            case .temporary: "video.playbackTemporaryFailure"
            case .configuration: "video.playbackConfigurationFailure"
            }
        }

        var systemImage: String {
            switch self {
            case .signInRequired: "person.crop.circle.badge.exclamationmark"
            case .rightsUnavailable: "lock.fill"
            case .temporary: "wifi.exclamationmark"
            case .configuration: "lock.shield.fill"
            }
        }
    }

    private enum PersonalStateFailure: Hashable {
        case signInRequired
        case unavailable
        case temporary

        init(error: SportsDataError) {
            switch error {
            case .unauthorized:
                self = .signInRequired
            case .forbidden, .notFound, .contentWithdrawn:
                self = .unavailable
            default:
                self = .temporary
            }
        }

        var localizationKey: String {
            switch self {
            case .signInRequired: "video.savedSignInRequired"
            case .unavailable: "video.savedUnavailable"
            case .temporary: "video.savedTemporaryFailure"
            }
        }

        var systemImage: String {
            switch self {
            case .signInRequired: "person.crop.circle.badge.exclamationmark"
            case .unavailable: "bookmark.slash.fill"
            case .temporary: "wifi.exclamationmark"
            }
        }
    }
}

enum VideoDescriptionPresentation {
    static let collapseThreshold = 160
    static let collapsedLineLimit = 4

    static func isExpandable(_ text: String) -> Bool {
        text.count > collapseThreshold
    }

    static func lineLimit(for text: String, isExpanded: Bool) -> Int? {
        isExpandable(text) && !isExpanded ? collapsedLineLimit : nil
    }
}

private struct ExpandableVideoDescription: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(VideoDescriptionPresentation.lineLimit(
                    for: text,
                    isExpanded: isExpanded
                ))
                .multilineTextAlignment(.leading)

            if VideoDescriptionPresentation.isExpandable(text) {
                Button {
                    isExpanded.toggle()
                } label: {
                    Text(LocalizedStringKey(
                        isExpanded ? "video.showLess" : "video.showMore"
                    ))
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
                .accessibilityIdentifier("video.description.toggle")
            }
        }
    }
}
