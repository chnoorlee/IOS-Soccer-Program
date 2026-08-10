import Foundation

protocol PersonalVideoStateStoring: Sendable {
    func article(id: String) async throws -> Article?
    func recordArticleIfSaved(_ article: Article) async throws
    func favoriteArticles() async throws -> [Article]
    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState
    func saveArticleFavorite(
        article: Article,
        updatedAt: Date
    ) async throws -> ArticleFavoriteState
    func removeArticleFavorite(articleID: String) async throws -> ArticleFavoriteState
    func video(id: String) async throws -> SportsVideo?
    func recordVideo(_ video: SportsVideo) async throws
    func continueWatching() async throws -> [ContinueWatchingItem]
    func watchHistory() async throws -> [WatchHistoryItem]
    func removeWatchHistoryItem(videoID: String) async throws
    func clearWatchHistory() async throws
    func watchProgress(videoID: String) async throws -> WatchProgress?
    func saveWatchProgress(
        video: SportsVideo,
        positionSeconds: Int,
        completed: Bool,
        updatedAt: Date
    ) async throws -> WatchProgress
    func favoriteVideos() async throws -> [SportsVideo]
    func videoFavorite(videoID: String) async throws -> VideoFavoriteState
    func saveFavorite(video: SportsVideo, updatedAt: Date) async throws -> VideoFavoriteState
    func removeFavorite(videoID: String) async throws -> VideoFavoriteState
    func follows() async throws -> [SportsFollow]
    func saveFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        updatedAt: Date
    ) async throws -> SportsFollow
    func removeFollow(type: FollowEntityType, entityID: String) async throws
    func exportGuestPersonalization() async throws -> GuestPersonalizationState
    func guestPersonalizationSummary() async throws -> GuestPersonalizationSummary
    func clearGuestPersonalization() async throws
}

actor FilePersonalVideoStateStore: PersonalVideoStateStoring {
    private let rootDirectory: URL
    private var loadedState: StoredState?

    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
            self.rootDirectory = (applicationSupport ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("SportsHub", isDirectory: true)
                .appendingPathComponent("PersonalVideoState", isDirectory: true)
        }
    }

    func article(id: String) throws -> Article? {
        try state().articlesByID[id]
    }

    func recordArticleIfSaved(_ article: Article) throws {
        var state = try state()
        guard state.favoriteDatesByArticleID[article.id] != nil,
              state.articlesByID[article.id] != article else {
            return
        }
        state.articlesByID[article.id] = article
        try persist(state)
    }

    func favoriteArticles() throws -> [Article] {
        let state = try state()
        return state.favoriteDatesByArticleID
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .compactMap { state.articlesByID[$0.key] }
    }

    func articleFavorite(articleID: String) throws -> ArticleFavoriteState {
        let updatedAt = try state().favoriteDatesByArticleID[articleID]
        return ArticleFavoriteState(
            articleID: articleID,
            isFavorite: updatedAt != nil,
            updatedAt: updatedAt
        )
    }

    func saveArticleFavorite(
        article: Article,
        updatedAt: Date
    ) throws -> ArticleFavoriteState {
        var state = try state()
        state.articlesByID[article.id] = article
        state.favoriteDatesByArticleID[article.id] =
            state.favoriteDatesByArticleID[article.id] ?? updatedAt
        try persist(state)
        return ArticleFavoriteState(
            articleID: article.id,
            isFavorite: true,
            updatedAt: state.favoriteDatesByArticleID[article.id]
        )
    }

    func removeArticleFavorite(articleID: String) throws -> ArticleFavoriteState {
        var state = try state()
        state.favoriteDatesByArticleID[articleID] = nil
        state.articlesByID[articleID] = nil
        try persist(state)
        return ArticleFavoriteState(articleID: articleID, isFavorite: false, updatedAt: nil)
    }

    func video(id: String) throws -> SportsVideo? {
        try state().videosByID[id]
    }

    func recordVideo(_ video: SportsVideo) throws {
        var state = try state()
        let snapshot = video.personalStateSnapshot
        guard state.videosByID[video.id] != snapshot else { return }
        state.videosByID[video.id] = snapshot
        if video.type == .live {
            state.progressByVideoID[video.id] = nil
        } else if let progress = state.progressByVideoID[video.id],
                  progress.positionSeconds > video.durationSeconds {
            state.progressByVideoID[video.id] = WatchProgress(
                videoID: progress.videoID,
                positionSeconds: video.durationSeconds,
                completed: progress.completed,
                updatedAt: progress.updatedAt
            )
        }
        pruneUnusedVideoSnapshots(keeping: video.id, state: &state)
        try persist(state)
    }

    func continueWatching() throws -> [ContinueWatchingItem] {
        let state = try state()
        return state.progressByVideoID.values
            .filter { !$0.completed && $0.positionSeconds > 0 }
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { progress in
                guard let video = state.videosByID[progress.videoID],
                      video.type != .live else {
                    return nil
                }
                return ContinueWatchingItem(video: video, progress: progress)
            }
    }

    func watchHistory() throws -> [WatchHistoryItem] {
        let state = try state()
        return state.progressByVideoID.values
            .filter { $0.positionSeconds > 0 }
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { progress in
                guard let video = state.videosByID[progress.videoID],
                      video.type != .live else {
                    return nil
                }
                return WatchHistoryItem(video: video, progress: progress)
            }
    }

    func clearWatchHistory() throws {
        var state = try state()
        state.progressByVideoID.removeAll()
        for videoID in Array(state.videosByID.keys) {
            pruneVideoIfUnused(videoID, state: &state)
        }
        try persist(state)
    }

    func removeWatchHistoryItem(videoID: String) throws {
        var state = try state()
        guard state.progressByVideoID.removeValue(forKey: videoID) != nil else { return }
        pruneVideoIfUnused(videoID, state: &state)
        try persist(state)
    }

    func watchProgress(videoID: String) throws -> WatchProgress? {
        try state().progressByVideoID[videoID]
    }

    func saveWatchProgress(
        video: SportsVideo,
        positionSeconds: Int,
        completed: Bool,
        updatedAt: Date
    ) throws -> WatchProgress {
        guard video.type != .live else {
            throw SportsDataError.contractViolation(field: "video.type")
        }
        guard positionSeconds >= 0 else {
            throw SportsDataError.contractViolation(field: "positionSeconds")
        }
        var state = try state()
        let progress = WatchProgress(
            videoID: video.id,
            positionSeconds: min(positionSeconds, video.durationSeconds),
            completed: completed,
            updatedAt: updatedAt
        )
        state.videosByID[video.id] = video.personalStateSnapshot
        state.progressByVideoID[video.id] = progress
        try persist(state)
        return progress
    }

    func favoriteVideos() throws -> [SportsVideo] {
        let state = try state()
        return state.favoriteDatesByVideoID
            .sorted { $0.value > $1.value }
            .compactMap { state.videosByID[$0.key] }
    }

    func videoFavorite(videoID: String) throws -> VideoFavoriteState {
        let updatedAt = try state().favoriteDatesByVideoID[videoID]
        return VideoFavoriteState(
            videoID: videoID,
            isFavorite: updatedAt != nil,
            updatedAt: updatedAt
        )
    }

    func saveFavorite(video: SportsVideo, updatedAt: Date) throws -> VideoFavoriteState {
        var state = try state()
        state.videosByID[video.id] = video.personalStateSnapshot
        state.favoriteDatesByVideoID[video.id] = state.favoriteDatesByVideoID[video.id] ?? updatedAt
        try persist(state)
        return VideoFavoriteState(
            videoID: video.id,
            isFavorite: true,
            updatedAt: state.favoriteDatesByVideoID[video.id]
        )
    }

    func removeFavorite(videoID: String) throws -> VideoFavoriteState {
        var state = try state()
        state.favoriteDatesByVideoID[videoID] = nil
        pruneVideoIfUnused(videoID, state: &state)
        try persist(state)
        return VideoFavoriteState(videoID: videoID, isFavorite: false, updatedAt: nil)
    }

    func follows() throws -> [SportsFollow] {
        try state().followsByTargetKey.values
            .map { stored in
                SportsFollow(
                    id: Self.followKey(type: stored.type, entityID: stored.entityID),
                    type: stored.type,
                    entityID: stored.entityID,
                    createdAt: stored.updatedAt,
                    entity: stored.entity
                )
            }
            .canonicalFollowOrder
    }

    func saveFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        updatedAt: Date
    ) throws -> SportsFollow {
        let entityID = entityID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidFollowIdentifier(entityID) else {
            throw SportsDataError.notFound
        }
        guard updatedAt <= Date().addingTimeInterval(5 * 60) else {
            throw SportsDataError.contractViolation(field: "updatedAt")
        }
        guard entity == nil || (entity?.type == type && entity?.entityID == entityID) else {
            throw SportsDataError.contractViolation(field: "entity")
        }
        var state = try state()
        let key = Self.followKey(type: type, entityID: entityID)
        let existing = state.followsByTargetKey[key]
        guard existing != nil || state.followsByTargetKey.count < 500 else {
            throw SportsDataError.contractViolation(field: "follows")
        }
        let stored = StoredFollow(
            type: type,
            entityID: entityID,
            updatedAt: existing?.updatedAt ?? updatedAt,
            entity: entity ?? existing?.entity
        )
        state.followsByTargetKey[key] = stored
        try persist(state)
        return SportsFollow(
            id: key,
            type: stored.type,
            entityID: stored.entityID,
            createdAt: stored.updatedAt,
            entity: stored.entity
        )
    }

    func removeFollow(type: FollowEntityType, entityID: String) throws {
        let entityID = entityID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidFollowIdentifier(entityID) else {
            throw SportsDataError.notFound
        }
        var state = try state()
        state.followsByTargetKey[Self.followKey(type: type, entityID: entityID)] = nil
        try persist(state)
    }

    func exportGuestPersonalization() throws -> GuestPersonalizationState {
        let state = try state()
        return GuestPersonalizationState(
            watchProgress: state.progressByVideoID.values.sorted { $0.updatedAt > $1.updatedAt },
            videoFavorites: state.favoriteDatesByVideoID
                .map { GuestVideoFavoriteRecord(videoID: $0.key, updatedAt: $0.value) }
                .sorted { $0.updatedAt > $1.updatedAt },
            articleFavorites: state.favoriteDatesByArticleID
                .map { GuestArticleFavoriteRecord(articleID: $0.key, updatedAt: $0.value) }
                .sorted { lhs, rhs in
                    lhs.updatedAt == rhs.updatedAt
                        ? lhs.articleID < rhs.articleID
                        : lhs.updatedAt > rhs.updatedAt
                },
            follows: state.followsByTargetKey.values
                .map {
                    GuestFollowRecord(
                        type: $0.type,
                        entityID: $0.entityID,
                        updatedAt: $0.updatedAt
                    )
                }
                .sorted { $0.updatedAt > $1.updatedAt }
        )
    }

    func guestPersonalizationSummary() throws -> GuestPersonalizationSummary {
        let state = try state()
        return GuestPersonalizationSummary(
            progressCount: state.progressByVideoID.count,
            favoriteCount: state.favoriteDatesByVideoID.count,
            articleFavoriteCount: state.favoriteDatesByArticleID.count,
            followCount: state.followsByTargetKey.count,
            videoSnapshotCount: state.videosByID.count
        )
    }

    func clearGuestPersonalization() throws {
        do {
            if FileManager.default.fileExists(atPath: stateURL.path) {
                try FileManager.default.removeItem(at: stateURL)
            }
            loadedState = StoredState()
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
    }

    private func state() throws -> StoredState {
        if let loadedState { return loadedState }
        let url = stateURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            let empty = StoredState()
            loadedState = empty
            return empty
        }

        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode(StoredState.self, from: data)
            guard (1...StoredState.currentSchemaVersion).contains(decoded.schemaVersion),
                  decoded.progressByVideoID.allSatisfy({ $0.key == $0.value.videoID }),
                  decoded.videosByID.allSatisfy({ $0.key == $0.value.id }),
                  decoded.articlesByID.allSatisfy({ $0.key == $0.value.id }),
                  decoded.favoriteDatesByArticleID.keys.allSatisfy({
                      decoded.articlesByID[$0] != nil
                  }),
                  decoded.favoriteDatesByVideoID.keys.allSatisfy({
                      decoded.videosByID[$0] != nil
                  }),
                  decoded.followsByTargetKey.count <= 500,
                  decoded.followsByTargetKey.allSatisfy({ entry in
                      entry.key == Self.followKey(
                          type: entry.value.type,
                          entityID: entry.value.entityID
                          )
                          && Self.isValidFollowIdentifier(entry.value.entityID)
                          && entry.value.updatedAt <= Date().addingTimeInterval(5 * 60)
                          && (entry.value.entity == nil
                              || (entry.value.entity?.type == entry.value.type
                                  && entry.value.entity?.entityID == entry.value.entityID))
                  }),
                  decoded.progressByVideoID.allSatisfy({ entry in
                      guard let video = decoded.videosByID[entry.key] else { return false }
                      return video.type != .live && entry.value.positionSeconds <= video.durationSeconds
                  }) else {
                throw SportsDataError.localStorageUnavailable
            }
            if decoded.schemaVersion < StoredState.currentSchemaVersion {
                decoded.schemaVersion = StoredState.currentSchemaVersion
                try persist(decoded)
                return decoded
            }
            loadedState = decoded
            return decoded
        } catch let error as SportsDataError {
            throw error
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
    }

    private func persist(_ state: StoredState) throws {
        do {
            try FileManager.default.createDirectory(
                at: rootDirectory,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(state)
            try data.write(
                to: stateURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            loadedState = state
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
    }

    private func pruneVideoIfUnused(_ videoID: String, state: inout StoredState) {
        guard state.favoriteDatesByVideoID[videoID] == nil,
              state.progressByVideoID[videoID] == nil else {
            return
        }
        state.videosByID[videoID] = nil
    }

    private func pruneUnusedVideoSnapshots(
        keeping retainedVideoID: String,
        state: inout StoredState
    ) {
        for videoID in Array(state.videosByID.keys) where videoID != retainedVideoID {
            guard state.favoriteDatesByVideoID[videoID] == nil,
                  state.progressByVideoID[videoID] == nil else {
                continue
            }
            state.videosByID[videoID] = nil
        }
    }

    private var stateURL: URL {
        rootDirectory.appendingPathComponent("guest-v1.json", isDirectory: false)
    }

    private static func followKey(type: FollowEntityType, entityID: String) -> String {
        "\(type.rawValue):\(entityID)"
    }

    private static func isValidFollowIdentifier(_ value: String) -> Bool {
        let forbidden = CharacterSet(charactersIn: "/\\?#")
        return (1...128).contains(value.count)
            && value.rangeOfCharacter(from: forbidden) == nil
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }

    private struct StoredFollow: Codable {
        let type: FollowEntityType
        let entityID: String
        let updatedAt: Date
        let entity: FollowEntitySnapshot?
    }

    private struct StoredState: Codable {
        static let currentSchemaVersion = 3

        var schemaVersion = currentSchemaVersion
        var articlesByID: [String: Article] = [:]
        var favoriteDatesByArticleID: [String: Date] = [:]
        var videosByID: [String: SportsVideo] = [:]
        var progressByVideoID: [String: WatchProgress] = [:]
        var favoriteDatesByVideoID: [String: Date] = [:]
        var followsByTargetKey: [String: StoredFollow] = [:]

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case articlesByID
            case favoriteDatesByArticleID
            case videosByID
            case progressByVideoID
            case favoriteDatesByVideoID
            case followsByTargetKey
        }

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(
                Int.self,
                forKey: .schemaVersion
            ) ?? Self.currentSchemaVersion
            articlesByID = try container.decodeIfPresent(
                [String: Article].self,
                forKey: .articlesByID
            ) ?? [:]
            favoriteDatesByArticleID = try container.decodeIfPresent(
                [String: Date].self,
                forKey: .favoriteDatesByArticleID
            ) ?? [:]
            videosByID = try container.decodeIfPresent(
                [String: SportsVideo].self,
                forKey: .videosByID
            ) ?? [:]
            progressByVideoID = try container.decodeIfPresent(
                [String: WatchProgress].self,
                forKey: .progressByVideoID
            ) ?? [:]
            favoriteDatesByVideoID = try container.decodeIfPresent(
                [String: Date].self,
                forKey: .favoriteDatesByVideoID
            ) ?? [:]
            followsByTargetKey = try container.decodeIfPresent(
                [String: StoredFollow].self,
                forKey: .followsByTargetKey
            ) ?? [:]
        }
    }
}

private extension SportsVideo {
    var personalStateSnapshot: SportsVideo {
        SportsVideo(
            id: id,
            type: type,
            titleArabic: titleArabic,
            titleEnglish: titleEnglish,
            descriptionArabic: descriptionArabic,
            descriptionEnglish: descriptionEnglish,
            poster: nil,
            durationSeconds: durationSeconds,
            isPlayable: isPlayable,
            availabilityReason: availabilityReason
        )
    }
}
