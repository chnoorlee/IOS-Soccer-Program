import Foundation
import OSLog

struct LocalPersonalizationSportsDataProvider: SportsDataProviding {
    private static let storageLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SportsHub",
        category: "PersonalizationState"
    )

    let base: any SportsDataProviding
    let store: any PersonalVideoStateStoring
    private let now: @Sendable () -> Date

    init(
        base: any SportsDataProviding,
        store: any PersonalVideoStateStoring = FilePersonalVideoStateStore(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.base = base
        self.store = store
        self.now = now
    }

    func teams() async throws -> [Team] { try await base.teams() }
    func players() async throws -> [PlayerProfile] { try await base.players() }
    func competitions() async throws -> [Competition] { try await base.competitions() }
    func teamDetails(id: String) async throws -> TeamDetails { try await base.teamDetails(id: id) }
    func teamMatchSnapshots(ids: [String]) async throws -> [TeamMatchSnapshot] {
        try await base.teamMatchSnapshots(ids: ids)
    }
    func teamContent(id: String) async throws -> TeamContent { try await base.teamContent(id: id) }
    func teamSquad(id: String, seasonID: String) async throws -> [PlayerProfile] {
        try await base.teamSquad(id: id, seasonID: seasonID)
    }
    func playerDetails(id: String) async throws -> PlayerDetails { try await base.playerDetails(id: id) }
    func playerContent(id: String) async throws -> PlayerContent { try await base.playerContent(id: id) }
    func playerTransfers(id: String) async throws -> [PlayerTransfer] {
        try await base.playerTransfers(id: id)
    }
    func transferUpdates(
        cursor: String?,
        limit: Int,
        status: TransferStatus?
    ) async throws -> TransferPage {
        try await base.transferUpdates(cursor: cursor, limit: limit, status: status)
    }
    func seasonCalendar() async throws -> SeasonCalendarSnapshot {
        try await base.seasonCalendar()
    }
    func competitionStandings(id: String, seasonID: String) async throws -> [StandingGroup] {
        try await base.competitionStandings(id: id, seasonID: seasonID)
    }
    func competitionLeaders(
        id: String,
        seasonID: String,
        category: CompetitionLeaderCategory
    ) async throws -> [CompetitionLeader] {
        try await base.competitionLeaders(id: id, seasonID: seasonID, category: category)
    }
    func competitionFixtures(id: String, seasonID: String) async throws -> [Fixture] {
        try await base.competitionFixtures(id: id, seasonID: seasonID)
    }
    func competitionContent(id: String) async throws -> CompetitionContent {
        try await base.competitionContent(id: id)
    }
    func homeFeed() async throws -> HomeFeed { try await base.homeFeed() }
    func fixtures(on date: Date) async throws -> [Fixture] { try await base.fixtures(on: date) }
    func fixtureDetails(id: String) async throws -> MatchDetails {
        try await base.fixtureDetails(id: id)
    }
    func fixtureContent(id: String) async throws -> FixtureContent {
        try await base.fixtureContent(id: id)
    }
    func fixtureEventUpdates(id: String, afterRevision: Int) async throws -> FixtureEventBatch {
        try await base.fixtureEventUpdates(id: id, afterRevision: afterRevision)
    }
    func fixtureStandings(for fixture: Fixture) async throws -> FixtureStandingsContext {
        try await base.fixtureStandings(for: fixture)
    }
    func fixtureHeadToHead(
        for fixture: Fixture,
        limit: Int
    ) async throws -> FixtureHeadToHeadContext {
        try await base.fixtureHeadToHead(for: fixture, limit: limit)
    }
    func articles() async throws -> [Article] { try await base.articles() }
    func articleDetails(id: String) async throws -> ArticleDetails {
        let id = try validatedIdentifier(id)
        let details = try await base.articleDetails(id: id)
        guard details.article.id == id else {
            throw SportsDataError.contractViolation(field: "article.id")
        }
        do {
            try await store.recordArticleIfSaved(details.article)
        } catch {
            Self.storageLogger.error("Saved article metadata could not be refreshed")
        }
        return details
    }

    func favoriteArticles() async throws -> [Article] {
        try await store.favoriteArticles()
    }

    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState {
        let articleID = try validatedIdentifier(articleID)
        return try await store.articleFavorite(articleID: articleID)
    }

    func setArticleFavorite(
        articleID: String,
        isFavorite: Bool
    ) async throws -> ArticleFavoriteState {
        let articleID = try validatedIdentifier(articleID)
        if isFavorite {
            let article = try await resolvedArticle(id: articleID)
            return try await store.saveArticleFavorite(article: article, updatedAt: now())
        }
        return try await store.removeArticleFavorite(articleID: articleID)
    }
    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int
    ) async throws -> ArticleCommentPage {
        try await base.articleComments(articleID: articleID, cursor: cursor, limit: limit)
    }
    func articleReaction(articleID: String) async throws -> ArticleReactionSummary {
        try await base.articleReaction(articleID: articleID)
    }
    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?
    ) async throws -> ArticleReactionSummary {
        throw SportsDataError.unauthorized
    }
    func createArticleComment(articleID: String, body: String) async throws -> ArticleComment {
        throw SportsDataError.unauthorized
    }
    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?
    ) async throws -> CommunityReportReceipt {
        throw SportsDataError.unauthorized
    }
    func blockCommunityAuthor(authorID: String) async throws {
        throw SportsDataError.unauthorized
    }
    func videoDiscovery() async throws -> VideoDiscoveryFeed { try await base.videoDiscovery() }
    func videoPrograms(
        cursor: String?,
        limit: Int,
        sport: VideoSport?
    ) async throws -> VideoProgramPage {
        try await base.videoPrograms(cursor: cursor, limit: limit, sport: sport)
    }
    func videoProgramDetails(
        id: String,
        cursor: String?,
        limit: Int
    ) async throws -> VideoProgramDetailsPage {
        try await base.videoProgramDetails(id: id, cursor: cursor, limit: limit)
    }
    func videos() async throws -> [SportsVideo] { try await base.videos() }
    func videoDetails(id: String) async throws -> SportsVideoDetails {
        let details = try await base.videoDetails(id: id)
        do {
            try await store.recordVideo(details.video)
        } catch {
            Self.storageLogger.error("Video metadata snapshot could not be stored")
        }
        return details
    }

    func continueWatching() async throws -> [ContinueWatchingItem] {
        try await store.continueWatching()
    }

    func watchHistory() async throws -> [WatchHistoryItem] {
        try await store.watchHistory()
    }

    func removeWatchHistoryItem(videoID: String) async throws {
        let videoID = try validatedIdentifier(videoID)
        try await store.removeWatchHistoryItem(videoID: videoID)
    }

    func clearWatchHistory() async throws {
        try await store.clearWatchHistory()
    }

    func watchProgress(videoID: String) async throws -> WatchProgress? {
        let videoID = try validatedIdentifier(videoID)
        return try await store.watchProgress(videoID: videoID)
    }

    func saveWatchProgress(
        videoID: String,
        positionSeconds: Int,
        completed: Bool
    ) async throws -> WatchProgress {
        let video = try await resolvedVideo(id: videoID)
        return try await store.saveWatchProgress(
            video: video,
            positionSeconds: positionSeconds,
            completed: completed,
            updatedAt: now()
        )
    }

    func favoriteVideos() async throws -> [SportsVideo] {
        try await store.favoriteVideos()
    }

    func videoFavorite(videoID: String) async throws -> VideoFavoriteState {
        let videoID = try validatedIdentifier(videoID)
        return try await store.videoFavorite(videoID: videoID)
    }

    func setVideoFavorite(videoID: String, isFavorite: Bool) async throws -> VideoFavoriteState {
        let videoID = try validatedIdentifier(videoID)
        if isFavorite {
            let video = try await resolvedVideo(id: videoID)
            return try await store.saveFavorite(video: video, updatedAt: now())
        }
        return try await store.removeFavorite(videoID: videoID)
    }

    func follows() async throws -> [SportsFollow] {
        let stored = try await store.follows()
        let legacyTeamIDs = Set(stored.compactMap { follow in
            follow.type == .team && follow.entity == nil ? follow.entityID : nil
        })
        guard !legacyTeamIDs.isEmpty else { return stored.canonicalFollowOrder }

        do {
            let teamsByID = (try await base.teams()).reduce(into: [String: Team]()) {
                $0[$1.id] = $1
            }
            for follow in stored where follow.type == .team
                && legacyTeamIDs.contains(follow.entityID) {
                guard let team = teamsByID[follow.entityID] else { continue }
                _ = try await store.saveFollow(
                    type: .team,
                    entityID: follow.entityID,
                    entity: .team(team),
                    updatedAt: follow.createdAt
                )
            }
            return (try await store.follows()).canonicalFollowOrder
        } catch {
            return stored.canonicalFollowOrder
        }
    }

    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool
    ) async throws -> SportsFollow? {
        let entityID = try validatedIdentifier(entityID)
        guard entity == nil || (entity?.type == type && entity?.entityID == entityID) else {
            throw SportsDataError.contractViolation(field: "entity")
        }
        if isFollowing {
            return try await store.saveFollow(
                type: type,
                entityID: entityID,
                entity: entity,
                updatedAt: now()
            )
        }
        try await store.removeFollow(type: type, entityID: entityID)
        return nil
    }

    func notificationPreferences() async throws -> NotificationPreferences {
        throw SportsDataError.unauthorized
    }

    func setNotificationPreference(
        _ type: NotificationPreferenceType,
        enabled: Bool
    ) async throws -> NotificationPreferences {
        throw SportsDataError.unauthorized
    }

    func registerNotificationDevice(_ registration: PushDeviceRegistration) async throws {
        throw SportsDataError.unauthorized
    }

    func predictionGames() async throws -> [PredictionGame] {
        try await base.predictionGames()
    }

    func predictionEntry(for game: PredictionGame) async throws -> PredictionEntry? {
        throw SportsDataError.unauthorized
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking]
    ) async throws -> PredictionEntry {
        throw SportsDataError.unauthorized
    }

    func createPlaybackSession(
        videoID: String,
        deviceID: String,
        capabilities: PlaybackCapabilities
    ) async throws -> PlaybackSession {
        try await base.createPlaybackSession(
            videoID: videoID,
            deviceID: deviceID,
            capabilities: capabilities
        )
    }

    func search(query: String) async throws -> [SearchResultItem] {
        try await base.search(query: query)
    }

    private func resolvedVideo(id: String) async throws -> SportsVideo {
        let id = try validatedIdentifier(id)
        let stored = try await store.video(id: id)
        if let stored {
            return stored
        }
        let details = try await base.videoDetails(id: id)
        return details.video
    }

    private func resolvedArticle(id: String) async throws -> Article {
        let id = try validatedIdentifier(id)
        let stored = try await store.article(id: id)
        if let stored {
            return stored
        }
        let details = try await articleDetails(id: id)
        return details.article
    }

    private func validatedIdentifier(_ value: String) throws -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\?#")
        guard !value.isEmpty,
              value.count <= 128,
              value.rangeOfCharacter(from: forbidden) == nil,
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw SportsDataError.notFound
        }
        return value
    }
}
