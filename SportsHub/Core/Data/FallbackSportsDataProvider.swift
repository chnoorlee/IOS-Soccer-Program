import Foundation

struct FallbackSportsDataProvider: SportsDataProviding, IdentityScopedPredictionProviding {
    let primary: any SportsDataProviding
    let fallback: any SportsDataProviding
    private let freshnessReporter: any PublicContentFreshnessReporting
    private let now: @Sendable () -> Date

    init(
        primary: any SportsDataProviding,
        fallback: any SportsDataProviding,
        freshnessReporter: any PublicContentFreshnessReporting = NoopPublicContentFreshnessReporter(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.primary = primary
        self.fallback = fallback
        self.freshnessReporter = freshnessReporter
        self.now = now
    }

    func teams() async throws -> [Team] {
        do {
            return try await primary.teams()
        } catch {
            guard canFallback(after: error) else { throw error }
            return try await fallback.teams()
        }
    }

    func players() async throws -> [PlayerProfile] {
        do {
            return try await primary.players()
        } catch {
            guard canFallback(after: error) else { throw error }
            return try await fallback.players()
        }
    }

    func competitions() async throws -> [Competition] {
        do {
            return try await primary.competitions()
        } catch {
            guard canFallback(after: error) else { throw error }
            return try await fallback.competitions()
        }
    }

    func teamDetails(id: String) async throws -> TeamDetails {
        let resource = PublicContentResource.team(id: id)
        do {
            return try await primary.teamDetails(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.teamDetails(id: id)
            await recordDemoFallback(for: resource)
            return value
        }
    }

    func teamMatchSnapshots(ids: [String]) async throws -> [TeamMatchSnapshot] {
        let resource = PublicContentResource.teamMatchSnapshots(ids: ids)
        do {
            return try await primary.teamMatchSnapshots(ids: ids)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.teamMatchSnapshots(ids: ids)
            await recordDemoFallback(for: resource)
            return value
        }
    }

    func teamContent(id: String) async throws -> TeamContent {
        let resource = PublicContentResource.teamContent(id: id)
        do {
            return try await primary.teamContent(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.teamContent(id: id)
            await recordDemoFallback(for: resource)
            return value
        }
    }

    func fixtureContent(id: String) async throws -> FixtureContent {
        let resource = PublicContentResource.fixtureContent(id: id)
        do {
            return try await primary.fixtureContent(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.fixtureContent(id: id)
            await recordDemoFallback(for: resource)
            return value
        }
    }

    func teamSquad(id: String, seasonID: String) async throws -> [PlayerProfile] {
        do {
            return try await primary.teamSquad(id: id, seasonID: seasonID)
        } catch {
            guard canFallback(after: error) else { throw error }
            return try await fallback.teamSquad(id: id, seasonID: seasonID)
        }
    }

    func playerDetails(id: String) async throws -> PlayerDetails {
        do {
            return try await primary.playerDetails(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            return try await fallback.playerDetails(id: id)
        }
    }

    func playerContent(id: String) async throws -> PlayerContent {
        let resource = PublicContentResource.playerContent(id: id)
        do {
            return try await primary.playerContent(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.playerContent(id: id)
            await recordDemoFallback(for: resource)
            return value
        }
    }

    func playerTransfers(id: String) async throws -> [PlayerTransfer] {
        do {
            return try await primary.playerTransfers(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            return try await fallback.playerTransfers(id: id)
        }
    }

    func transferUpdates(
        cursor: String?,
        limit: Int,
        status: TransferStatus?
    ) async throws -> TransferPage {
        let resource = PublicContentResource.transfers(status: status)
        do {
            return try await primary.transferUpdates(cursor: cursor, limit: limit, status: status)
        } catch {
            // A failed later page must stay failed. Falling back with a cursor
            // could append fictional records to an already-live result set.
            guard cursor == nil, canFallback(after: error) else { throw error }
            let value = try await fallback.transferUpdates(
                cursor: cursor,
                limit: limit,
                status: status
            )
            await recordDemoFallback(for: resource)
            // Never expose a demo cursor after a live-provider failure. A later
            // page could otherwise mix fictional and live records in one feed.
            return TransferPage(
                transfers: value.transfers,
                nextCursor: nil,
                hasMore: false
            )
        }
    }

    func seasonCalendar() async throws -> SeasonCalendarSnapshot {
        do {
            return try await primary.seasonCalendar()
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.seasonCalendar()
            await recordDemoFallback(for: .seasonCalendar)
            return value
        }
    }

    func competitionStandings(id: String, seasonID: String) async throws -> [StandingGroup] {
        do {
            return try await primary.competitionStandings(id: id, seasonID: seasonID)
        } catch {
            guard canFallback(after: error) else { throw error }
            return try await fallback.competitionStandings(id: id, seasonID: seasonID)
        }
    }

    func competitionContent(id: String) async throws -> CompetitionContent {
        let resource = PublicContentResource.competitionContent(id: id)
        do {
            return try await primary.competitionContent(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.competitionContent(id: id)
            await recordDemoFallback(for: resource)
            return value
        }
    }

    func competitionLeaders(
        id: String,
        seasonID: String,
        category: CompetitionLeaderCategory
    ) async throws -> [CompetitionLeader] {
        do {
            return try await primary.competitionLeaders(
                id: id,
                seasonID: seasonID,
                category: category
            )
        } catch {
            guard canFallback(after: error) else { throw error }
            return try await fallback.competitionLeaders(
                id: id,
                seasonID: seasonID,
                category: category
            )
        }
    }

    func competitionFixtures(id: String, seasonID: String) async throws -> [Fixture] {
        let resource = PublicContentResource.competitionFixtures(id: id, seasonID: seasonID)
        do {
            return try await primary.competitionFixtures(id: id, seasonID: seasonID)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.competitionFixtures(id: id, seasonID: seasonID)
            await recordDemoFallback(for: resource)
            return value
        }
    }

    func homeFeed() async throws -> HomeFeed {
        do {
            return try await primary.homeFeed()
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.homeFeed()
            await recordDemoFallback(for: .home)
            return value
        }
    }

    func fixtures(on date: Date) async throws -> [Fixture] {
        let resource = PublicContentResource.fixtures(on: date)
        do {
            return try await primary.fixtures(on: date)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.fixtures(on: date)
            await recordDemoFallback(for: resource)
            return value
        }
    }

    func fixtureDetails(id: String) async throws -> MatchDetails {
        do {
            return try await primary.fixtureDetails(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.fixtureDetails(id: id)
            await recordDemoFallback(for: .fixture(id: id))
            return value
        }
    }

    func fixtureEventUpdates(id: String, afterRevision: Int) async throws -> FixtureEventBatch {
        // A live real-world match must never acquire fictional events when the
        // primary service is unavailable.
        try await primary.fixtureEventUpdates(id: id, afterRevision: afterRevision)
    }

    func fixtureStandings(for fixture: Fixture) async throws -> FixtureStandingsContext {
        do {
            return try await primary.fixtureStandings(for: fixture)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.fixtureStandings(for: fixture)
            await recordDemoFallback(for: .fixtureStandings(id: fixture.id))
            return value
        }
    }

    func fixtureHeadToHead(
        for fixture: Fixture,
        limit: Int
    ) async throws -> FixtureHeadToHeadContext {
        do {
            return try await primary.fixtureHeadToHead(for: fixture, limit: limit)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.fixtureHeadToHead(for: fixture, limit: limit)
            await recordDemoFallback(for: .fixtureHeadToHead(id: fixture.id))
            return value
        }
    }

    func articles() async throws -> [Article] {
        do {
            return try await primary.articles()
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.articles()
            await recordDemoFallback(for: .articles)
            return value
        }
    }

    func articleDetails(id: String) async throws -> ArticleDetails {
        do {
            return try await primary.articleDetails(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.articleDetails(id: id)
            await recordDemoFallback(for: .article(id: id))
            return value
        }
    }

    func favoriteArticles() async throws -> [Article] {
        try await primary.favoriteArticles()
    }

    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState {
        try await primary.articleFavorite(articleID: articleID)
    }

    func setArticleFavorite(
        articleID: String,
        isFavorite: Bool
    ) async throws -> ArticleFavoriteState {
        try await primary.setArticleFavorite(articleID: articleID, isFavorite: isFavorite)
    }

    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int
    ) async throws -> ArticleCommentPage {
        try await primary.articleComments(articleID: articleID, cursor: cursor, limit: limit)
    }

    func articleReaction(articleID: String) async throws -> ArticleReactionSummary {
        try await primary.articleReaction(articleID: articleID)
    }

    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?
    ) async throws -> ArticleReactionSummary {
        try await primary.setArticleReaction(articleID: articleID, reaction: reaction)
    }

    func createArticleComment(articleID: String, body: String) async throws -> ArticleComment {
        try await primary.createArticleComment(articleID: articleID, body: body)
    }

    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?
    ) async throws -> CommunityReportReceipt {
        try await primary.reportArticleComment(
            commentID: commentID,
            reason: reason,
            details: details
        )
    }

    func blockCommunityAuthor(authorID: String) async throws {
        try await primary.blockCommunityAuthor(authorID: authorID)
    }

    func videoDiscovery() async throws -> VideoDiscoveryFeed {
        do {
            return try await primary.videoDiscovery()
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.videoDiscovery()
            await recordDemoFallback(for: .videoDiscovery)
            return value
        }
    }

    func videoPrograms(
        cursor: String?,
        limit: Int,
        sport: VideoSport?
    ) async throws -> VideoProgramPage {
        do {
            return try await primary.videoPrograms(cursor: cursor, limit: limit, sport: sport)
        } catch {
            guard cursor == nil, canFallback(after: error) else { throw error }
            let value = try await fallback.videoPrograms(
                cursor: nil,
                limit: limit,
                sport: sport
            )
            await recordDemoFallback(for: .videoPrograms(sport: sport))
            return VideoProgramPage(
                programs: value.programs,
                nextCursor: nil,
                hasMore: false
            )
        }
    }

    func videoProgramDetails(
        id: String,
        cursor: String?,
        limit: Int
    ) async throws -> VideoProgramDetailsPage {
        do {
            return try await primary.videoProgramDetails(
                id: id,
                cursor: cursor,
                limit: limit
            )
        } catch {
            guard cursor == nil, canFallback(after: error) else { throw error }
            let value = try await fallback.videoProgramDetails(
                id: id,
                cursor: nil,
                limit: limit
            )
            await recordDemoFallback(for: .videoProgram(id: id))
            return VideoProgramDetailsPage(
                program: value.program,
                episodes: value.episodes,
                nextCursor: nil,
                hasMore: false
            )
        }
    }

    func videos() async throws -> [SportsVideo] {
        do {
            return try await primary.videos()
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.videos()
            await recordDemoFallback(for: .videos)
            return value
        }
    }

    func videoDetails(id: String) async throws -> SportsVideoDetails {
        do {
            return try await primary.videoDetails(id: id)
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.videoDetails(id: id)
            await recordDemoFallback(for: .video(id: id))
            return value
        }
    }

    func continueWatching() async throws -> [ContinueWatchingItem] {
        // Account state must never silently switch to a demo identity.
        try await primary.continueWatching()
    }

    func watchHistory() async throws -> [WatchHistoryItem] {
        try await primary.watchHistory()
    }

    func removeWatchHistoryItem(videoID: String) async throws {
        try await primary.removeWatchHistoryItem(videoID: videoID)
    }

    func clearWatchHistory() async throws {
        try await primary.clearWatchHistory()
    }

    func watchProgress(videoID: String) async throws -> WatchProgress? {
        try await primary.watchProgress(videoID: videoID)
    }

    func saveWatchProgress(
        videoID: String,
        positionSeconds: Int,
        completed: Bool
    ) async throws -> WatchProgress {
        try await primary.saveWatchProgress(
            videoID: videoID,
            positionSeconds: positionSeconds,
            completed: completed
        )
    }

    func favoriteVideos() async throws -> [SportsVideo] {
        try await primary.favoriteVideos()
    }

    func videoFavorite(videoID: String) async throws -> VideoFavoriteState {
        try await primary.videoFavorite(videoID: videoID)
    }

    func setVideoFavorite(videoID: String, isFavorite: Bool) async throws -> VideoFavoriteState {
        try await primary.setVideoFavorite(videoID: videoID, isFavorite: isFavorite)
    }

    func follows() async throws -> [SportsFollow] {
        try await primary.follows()
    }

    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool
    ) async throws -> SportsFollow? {
        try await primary.setFollow(
            type: type,
            entityID: entityID,
            entity: entity,
            isFollowing: isFollowing
        )
    }

    func notificationPreferences() async throws -> NotificationPreferences {
        try await primary.notificationPreferences()
    }

    func setNotificationPreference(
        _ type: NotificationPreferenceType,
        enabled: Bool
    ) async throws -> NotificationPreferences {
        try await primary.setNotificationPreference(type, enabled: enabled)
    }

    func registerNotificationDevice(_ registration: PushDeviceRegistration) async throws {
        try await primary.registerNotificationDevice(registration)
    }

    func predictionGames() async throws -> [PredictionGame] {
        do {
            return try await primary.predictionGames()
        } catch {
            guard canFallback(after: error) else { throw error }
            let value = try await fallback.predictionGames()
            await recordDemoFallback(for: .predictionGames)
            return value
        }
    }

    func predictionEntry(for game: PredictionGame) async throws -> PredictionEntry? {
        try await primary.predictionEntry(for: game)
    }

    func predictionEntry(
        for game: PredictionGame,
        forAccountID accountID: String
    ) async throws -> PredictionEntry? {
        guard let scoped = primary as? any IdentityScopedPredictionProviding else {
            throw SportsDataError.unauthorized
        }
        return try await scoped.predictionEntry(for: game, forAccountID: accountID)
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking]
    ) async throws -> PredictionEntry {
        try await primary.savePredictionEntry(for: game, rankings: rankings)
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking],
        forAccountID accountID: String
    ) async throws -> PredictionEntry {
        guard let scoped = primary as? any IdentityScopedPredictionProviding else {
            throw SportsDataError.unauthorized
        }
        return try await scoped.savePredictionEntry(
            for: game,
            rankings: rankings,
            forAccountID: accountID
        )
    }

    func createPlaybackSession(
        videoID: String,
        deviceID: String,
        capabilities: PlaybackCapabilities
    ) async throws -> PlaybackSession {
        // Playback authorization is short-lived and rights-sensitive. A network
        // failure must never manufacture a playable session from demo data.
        try await primary.createPlaybackSession(
            videoID: videoID,
            deviceID: deviceID,
            capabilities: capabilities
        )
    }

    func search(query: String) async throws -> [SearchResultItem] {
        // Search has no per-response provenance UI. Returning fictional demo
        // hits after a live failure would make them indistinguishable from
        // provider results, so this path fails closed.
        try await primary.search(query: query)
    }

    private func recordDemoFallback(for resource: PublicContentResource) async {
        await freshnessReporter.record(
            .demoFallback(checkedAt: now()),
            for: resource
        )
    }

    private func canFallback(after error: Error) -> Bool {
        if let dataError = error as? SportsDataError {
            return dataError.isRecoverableForFallback
        }
        return error is URLError
    }
}

struct FailingSportsDataProvider: SportsDataProviding {
    let error: SportsDataError

    func teams() async throws -> [Team] { throw error }
    func players() async throws -> [PlayerProfile] { throw error }
    func competitions() async throws -> [Competition] { throw error }
    func teamDetails(id: String) async throws -> TeamDetails { throw error }
    func teamMatchSnapshots(ids: [String]) async throws -> [TeamMatchSnapshot] { throw error }
    func teamContent(id: String) async throws -> TeamContent { throw error }
    func teamSquad(id: String, seasonID: String) async throws -> [PlayerProfile] { throw error }
    func playerDetails(id: String) async throws -> PlayerDetails { throw error }
    func playerContent(id: String) async throws -> PlayerContent { throw error }
    func playerTransfers(id: String) async throws -> [PlayerTransfer] { throw error }
    func transferUpdates(
        cursor: String?,
        limit: Int,
        status: TransferStatus?
    ) async throws -> TransferPage { throw error }
    func seasonCalendar() async throws -> SeasonCalendarSnapshot { throw error }
    func competitionStandings(id: String, seasonID: String) async throws -> [StandingGroup] { throw error }
    func competitionLeaders(
        id: String,
        seasonID: String,
        category: CompetitionLeaderCategory
    ) async throws -> [CompetitionLeader] { throw error }
    func competitionFixtures(id: String, seasonID: String) async throws -> [Fixture] { throw error }
    func competitionContent(id: String) async throws -> CompetitionContent { throw error }
    func homeFeed() async throws -> HomeFeed { throw error }
    func fixtures(on date: Date) async throws -> [Fixture] { throw error }
    func fixtureDetails(id: String) async throws -> MatchDetails { throw error }
    func fixtureContent(id: String) async throws -> FixtureContent { throw error }
    func fixtureEventUpdates(id: String, afterRevision: Int) async throws -> FixtureEventBatch {
        throw error
    }
    func fixtureStandings(for fixture: Fixture) async throws -> FixtureStandingsContext {
        throw error
    }
    func fixtureHeadToHead(
        for fixture: Fixture,
        limit: Int
    ) async throws -> FixtureHeadToHeadContext {
        throw error
    }
    func articles() async throws -> [Article] { throw error }
    func articleDetails(id: String) async throws -> ArticleDetails { throw error }
    func favoriteArticles() async throws -> [Article] { throw error }
    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState { throw error }
    func setArticleFavorite(
        articleID: String,
        isFavorite: Bool
    ) async throws -> ArticleFavoriteState { throw error }
    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int
    ) async throws -> ArticleCommentPage { throw error }
    func articleReaction(articleID: String) async throws -> ArticleReactionSummary { throw error }
    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?
    ) async throws -> ArticleReactionSummary { throw error }
    func createArticleComment(articleID: String, body: String) async throws -> ArticleComment {
        throw error
    }
    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?
    ) async throws -> CommunityReportReceipt { throw error }
    func blockCommunityAuthor(authorID: String) async throws { throw error }
    func videoDiscovery() async throws -> VideoDiscoveryFeed { throw error }
    func videoPrograms(
        cursor: String?,
        limit: Int,
        sport: VideoSport?
    ) async throws -> VideoProgramPage { throw error }
    func videoProgramDetails(
        id: String,
        cursor: String?,
        limit: Int
    ) async throws -> VideoProgramDetailsPage { throw error }
    func videos() async throws -> [SportsVideo] { throw error }
    func videoDetails(id: String) async throws -> SportsVideoDetails { throw error }
    func continueWatching() async throws -> [ContinueWatchingItem] { throw error }
    func watchHistory() async throws -> [WatchHistoryItem] { throw error }
    func removeWatchHistoryItem(videoID: String) async throws { throw error }
    func clearWatchHistory() async throws { throw error }
    func watchProgress(videoID: String) async throws -> WatchProgress? { throw error }
    func saveWatchProgress(
        videoID: String,
        positionSeconds: Int,
        completed: Bool
    ) async throws -> WatchProgress { throw error }
    func favoriteVideos() async throws -> [SportsVideo] { throw error }
    func videoFavorite(videoID: String) async throws -> VideoFavoriteState { throw error }
    func setVideoFavorite(videoID: String, isFavorite: Bool) async throws -> VideoFavoriteState {
        throw error
    }
    func follows() async throws -> [SportsFollow] { throw error }
    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool
    ) async throws -> SportsFollow? { throw error }
    func notificationPreferences() async throws -> NotificationPreferences { throw error }
    func setNotificationPreference(
        _ type: NotificationPreferenceType,
        enabled: Bool
    ) async throws -> NotificationPreferences { throw error }
    func registerNotificationDevice(_ registration: PushDeviceRegistration) async throws {
        throw error
    }
    func predictionGames() async throws -> [PredictionGame] { throw error }
    func predictionEntry(for game: PredictionGame) async throws -> PredictionEntry? { throw error }
    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking]
    ) async throws -> PredictionEntry { throw error }
    func createPlaybackSession(
        videoID: String,
        deviceID: String,
        capabilities: PlaybackCapabilities
    ) async throws -> PlaybackSession { throw error }
    func search(query: String) async throws -> [SearchResultItem] { throw error }
}
