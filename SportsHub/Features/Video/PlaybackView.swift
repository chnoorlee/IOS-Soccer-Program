import AVKit
import Combine
import OSLog
import SwiftUI

struct PlaybackView: View {
    private static let progressLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SportsHub",
        category: "WatchProgress"
    )

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appModel: AppModel

    let session: PlaybackSession
    let video: SportsVideo
    let initialProgress: WatchProgress?

    private let progressTimer = Timer.publish(
        every: ProgressPolicy.timerInterval,
        on: .main,
        in: .common
    ).autoconnect()

    @State private var launchExpired: Bool
    @State private var playbackFailed = false
    @State private var audioSessionFailed = false
    @State private var playerStatus: AVPlayerItem.Status = .unknown
    @State private var player: AVPlayer
    @State private var isPictureInPictureActive = false
    @State private var didAttemptResume = false
    @State private var lastObservedPosition: Int
    @State private var lastSavedPosition: Int
    @State private var progressSaveRequest: ProgressSnapshot?
    @State private var progressSyncFailure: ProgressSyncFailure?
    @State private var progressSyncDisabled = false
    @State private var playbackCompleted = false

    init(
        session: PlaybackSession,
        video: SportsVideo,
        initialProgress: WatchProgress? = nil
    ) {
        self.session = session
        self.video = video
        self.initialProgress = initialProgress
        _launchExpired = State(initialValue: session.isExpired())
        let savedPosition = min(
            max(initialProgress?.positionSeconds ?? 0, 0),
            video.durationSeconds
        )
        _lastObservedPosition = State(initialValue: savedPosition)
        _lastSavedPosition = State(initialValue: savedPosition)
        let player = AVPlayer(playerItem: AVPlayerItem(url: session.hlsURL))
        player.allowsExternalPlayback = session.allowsAirPlay
        _player = State(initialValue: player)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if session.fairPlay != nil {
                    unavailableState(
                        title: "video.fairPlayNotConfigured",
                        body: "video.fairPlayNotConfiguredBody",
                        icon: "lock.shield.fill"
                    )
                } else if launchExpired {
                    unavailableState(
                        title: "video.sessionExpired",
                        body: "video.sessionExpiredBody",
                        icon: "clock.badge.exclamationmark"
                    )
                } else if audioSessionFailed {
                    unavailableState(
                        title: "video.audioSessionFailed",
                        body: "video.audioSessionFailedBody",
                        icon: "speaker.slash.fill"
                    )
                } else if playbackFailed {
                    unavailableState(
                        title: "video.playbackFailed",
                        body: "video.playbackFailedBody",
                        icon: "exclamationmark.triangle.fill"
                    )
                } else {
                    playerContent
                }
            }
            .navigationTitle(video.title(in: appModel.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("video.player.done")
                }
            }
        }
        .onReceive(playerStatusPublisher) { status in
            playerStatus = status
            if status == .failed {
                player.pause()
                playbackFailed = true
            } else if status == .readyToPlay {
                resumeIfNeeded()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .AVPlayerItemFailedToPlayToEndTime,
                object: player.currentItem
            )
        ) { _ in
            player.pause()
            playbackFailed = true
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        ) { _ in
            markPlaybackCompleted()
        }
        .onReceive(progressTimer) { _ in
            captureProgressIfNeeded()
        }
        .task(id: progressSaveRequest) {
            guard let progressSaveRequest else { return }
            await persistProgress(progressSaveRequest)
        }
        .onAppear { configureAudioSession() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && !isPictureInPictureActive {
                player.pause()
            }
        }
        .onChange(of: isPictureInPictureActive) { _, isActive in
            if !isActive && scenePhase != .active {
                player.pause()
            }
        }
        .onDisappear {
            flushProgressBeforeClosing()
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    @MainActor
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback
            )
        } catch {
            player.pause()
            audioSessionFailed = true
        }
    }

    private var playerContent: some View {
        VStack(spacing: 18) {
            ZStack {
                NativePlayerView(
                    player: player,
                    allowsPictureInPicture: session.allowsPictureInPicture,
                    isPictureInPictureActive: $isPictureInPictureActive
                )
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(.black)
                    .accessibilityIdentifier("video.player")
                if playerStatus == .unknown {
                    ProgressView("video.preparingStream")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .allowsHitTesting(false)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(video.title(in: appModel.language))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Label("video.nativeControlsHint", systemImage: "captions.bubble.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                if shouldTrackProgress, lastObservedPosition > 0 {
                    ProgressView(
                        value: Double(lastObservedPosition),
                        total: Double(video.durationSeconds)
                    )
                    .tint(AppTheme.accent)
                    .accessibilityHidden(true)
                    Text("video.progressPercent \(currentProgressPercentage)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .accessibilityLabel(
                            Text("video.progressAccessibility \(currentProgressPercentage)")
                        )
                }

                if let progressSyncFailure {
                    Label(
                        LocalizedStringKey(progressSyncFailure.localizationKey),
                        systemImage: progressSyncFailure.systemImage
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warm)
                    .accessibilityIdentifier("video.player.progress.error")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
    }

    private var playerStatusPublisher: AnyPublisher<AVPlayerItem.Status, Never> {
        guard let item = player.currentItem else {
            return Just(.failed).eraseToAnyPublisher()
        }
        return item.publisher(for: \.status).eraseToAnyPublisher()
    }

    private var shouldTrackProgress: Bool {
        video.type != .live && video.durationSeconds > 0
    }

    private var currentProgressPercentage: Int {
        guard video.durationSeconds > 0 else { return 0 }
        let fraction = min(
            max(Double(lastObservedPosition) / Double(video.durationSeconds), 0),
            1
        )
        return Int((fraction * 100).rounded())
    }

    @MainActor
    private func resumeIfNeeded() {
        guard !didAttemptResume else { return }
        didAttemptResume = true
        guard shouldTrackProgress,
              let initialProgress,
              !initialProgress.completed,
              initialProgress.positionSeconds >= ProgressPolicy.minimumPosition,
              initialProgress.positionSeconds < max(
                  video.durationSeconds - ProgressPolicy.resumeEndMargin,
                  0
              ) else {
            return
        }

        let resumeTime = CMTime(seconds: Double(initialProgress.positionSeconds), preferredTimescale: 600)
        player.seek(
            to: resumeTime,
            toleranceBefore: CMTime(seconds: 1, preferredTimescale: 600),
            toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600)
        )
        lastObservedPosition = initialProgress.positionSeconds
    }

    @MainActor
    private func captureProgressIfNeeded() {
        guard shouldTrackProgress,
              !launchExpired,
              !playbackFailed,
              !audioSessionFailed,
              playerStatus == .readyToPlay,
              !progressSyncDisabled,
              let snapshot = currentProgressSnapshot() else {
            return
        }
        lastObservedPosition = snapshot.positionSeconds

        if snapshot.completed {
            guard lastSavedPosition < video.durationSeconds else { return }
        } else {
            guard abs(snapshot.positionSeconds - lastSavedPosition) >= ProgressPolicy.saveIntervalSeconds else {
                return
            }
        }
        progressSaveRequest = snapshot
    }

    @MainActor
    private func markPlaybackCompleted() {
        guard shouldTrackProgress else { return }
        playbackCompleted = true
        lastObservedPosition = video.durationSeconds
        guard !progressSyncDisabled else { return }
        let snapshot = ProgressSnapshot(
            positionSeconds: video.durationSeconds,
            completed: true
        )
        progressSaveRequest = snapshot
    }

    @MainActor
    private func currentProgressSnapshot() -> ProgressSnapshot? {
        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds >= 0 else { return nil }
        let position = min(max(Int(seconds.rounded(.down)), 0), video.durationSeconds)
        guard position >= ProgressPolicy.minimumPosition || playbackCompleted else { return nil }
        return ProgressSnapshot(
            positionSeconds: playbackCompleted ? video.durationSeconds : position,
            completed: playbackCompleted
        )
    }

    @MainActor
    private func persistProgress(_ snapshot: ProgressSnapshot) async {
        do {
            let stored = try await appModel.dataProvider.saveWatchProgress(
                videoID: video.id,
                positionSeconds: snapshot.positionSeconds,
                completed: snapshot.completed
            )
            guard !Task.isCancelled else { return }
            lastSavedPosition = stored.positionSeconds
            progressSyncFailure = nil
        } catch is CancellationError {
            return
        } catch let error as SportsDataError {
            guard !Task.isCancelled else { return }
            progressSyncFailure = ProgressSyncFailure(error: error)
            if error == .unauthorized || error == .forbidden {
                progressSyncDisabled = true
            }
        } catch {
            guard !Task.isCancelled else { return }
            progressSyncFailure = .temporary
        }
    }

    @MainActor
    private func flushProgressBeforeClosing() {
        guard shouldTrackProgress,
              !progressSyncDisabled,
              let snapshot = currentProgressSnapshot(),
              snapshot.positionSeconds != lastSavedPosition else {
            return
        }
        let provider = appModel.dataProvider
        let videoID = video.id
        Task { @MainActor in
            do {
                _ = try await provider.saveWatchProgress(
                    videoID: videoID,
                    positionSeconds: snapshot.positionSeconds,
                    completed: snapshot.completed
                )
            } catch {
                Self.progressLogger.error("Final watch-progress flush failed")
            }
        }
    }

    private func unavailableState(
        title: LocalizedStringKey,
        body: LocalizedStringKey,
        icon: String
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(AppTheme.warm)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.body)
                .foregroundStyle(.white.opacity(0.76))
                .multilineTextAlignment(.center)
            Button("video.closeAndRetry") { dismiss() }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.player.unavailable")
    }

    private struct ProgressSnapshot: Hashable {
        let positionSeconds: Int
        let completed: Bool
    }

    private enum ProgressPolicy {
        static let timerInterval: TimeInterval = 10
        static let saveIntervalSeconds = 10
        static let minimumPosition = 5
        static let resumeEndMargin = 5
    }

    private enum ProgressSyncFailure: Hashable {
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
            case .signInRequired: "video.progressSignInRequired"
            case .unavailable: "video.progressUnavailable"
            case .temporary: "video.progressTemporaryFailure"
            }
        }

        var systemImage: String {
            switch self {
            case .signInRequired: "person.crop.circle.badge.exclamationmark"
            case .unavailable: "icloud.slash.fill"
            case .temporary: "wifi.exclamationmark"
            }
        }
    }
}

private struct NativePlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let allowsPictureInPicture: Bool
    @Binding var isPictureInPictureActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPictureInPictureActive: $isPictureInPictureActive)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.delegate = context.coordinator
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = allowsPictureInPicture
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(
        _ controller: AVPlayerViewController,
        context: Context
    ) {
        controller.player = player
        controller.allowsPictureInPicturePlayback = allowsPictureInPicture
        context.coordinator.isPictureInPictureActive = $isPictureInPictureActive
    }

    static func dismantleUIViewController(
        _ controller: AVPlayerViewController,
        coordinator: Void
    ) {
        controller.player?.pause()
        controller.player = nil
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var isPictureInPictureActive: Binding<Bool>

        init(isPictureInPictureActive: Binding<Bool>) {
            self.isPictureInPictureActive = isPictureInPictureActive
        }

        func playerViewControllerWillStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            isPictureInPictureActive.wrappedValue = true
        }

        func playerViewControllerDidStopPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            isPictureInPictureActive.wrappedValue = false
        }
    }
}
