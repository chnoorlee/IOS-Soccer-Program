import Foundation

/// Routes personal state to the server only when a Keychain session exists.
/// An expired session remains an account session and therefore fails closed
/// instead of silently writing new activity into the guest profile.
struct SessionPersonalizationSportsDataProvider: SportsDataProviding,
    IdentityScopedFollowProviding,
    IdentityScopedPredictionProviding {
    let base: any SportsDataProviding
    let authenticated: any SportsDataProviding
    let guest: any SportsDataProviding
    let sessionStore: any AuthSessionStoring
    let communityMutationsEnabled: Bool

    init(
        base: any SportsDataProviding,
        authenticated: any SportsDataProviding,
        guest: any SportsDataProviding,
        sessionStore: any AuthSessionStoring,
        communityMutationsEnabled: Bool = false
    ) {
        self.base = base
        self.authenticated = authenticated
        self.guest = guest
        self.sessionStore = sessionStore
        self.communityMutationsEnabled = communityMutationsEnabled
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
    func homeFeed() async throws -> HomeFeed {
        let hasSession = try await hasAccountSession()
        if hasSession {
            return try await authenticated.homeFeed()
        }
        return try await base.homeFeed()
    }
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
        let hasSession = try await hasAccountSession()
        if hasSession {
            return try await base.articleDetails(id: id)
        }
        return try await guest.articleDetails(id: id)
    }

    func favoriteArticles() async throws -> [Article] {
        try await personalProvider().favoriteArticles()
    }

    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState {
        try await personalProvider().articleFavorite(articleID: articleID)
    }

    func setArticleFavorite(
        articleID: String,
        isFavorite: Bool
    ) async throws -> ArticleFavoriteState {
        try await personalProvider().setArticleFavorite(
            articleID: articleID,
            isFavorite: isFavorite
        )
    }
    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int
    ) async throws -> ArticleCommentPage {
        let currentAccountID = try await activeAccountID()
        if let accountID = currentAccountID {
            let provider = try await identityBoundProvider(forAccountID: accountID)
            guard let scoped = provider as? any IdentityScopedCommunityProviding else {
                throw SportsDataError.unauthorized
            }
            return try await scoped.articleComments(
                articleID: articleID,
                cursor: cursor,
                limit: limit,
                forAccountID: accountID
            )
        }
        return try await base.articleComments(
            articleID: articleID,
            cursor: cursor,
            limit: limit
        )
    }
    func articleReaction(articleID: String) async throws -> ArticleReactionSummary {
        let currentAccountID = try await activeAccountID()
        if let accountID = currentAccountID {
            let provider = try await identityBoundProvider(forAccountID: accountID)
            guard let scoped = provider as? any IdentityScopedCommunityProviding else {
                throw SportsDataError.unauthorized
            }
            return try await scoped.articleReaction(
                articleID: articleID,
                forAccountID: accountID
            )
        }
        return try await base.articleReaction(articleID: articleID)
    }
    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?
    ) async throws -> ArticleReactionSummary {
        let (provider, accountID) = try await communityProviderForActiveAccount()
        return try await provider.setArticleReaction(
            articleID: articleID,
            reaction: reaction,
            forAccountID: accountID
        )
    }
    func createArticleComment(articleID: String, body: String) async throws -> ArticleComment {
        let (provider, accountID) = try await communityProviderForActiveAccount()
        return try await provider.createArticleComment(
            articleID: articleID,
            body: body,
            forAccountID: accountID
        )
    }
    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?
    ) async throws -> CommunityReportReceipt {
        let (provider, accountID) = try await communityProviderForActiveAccount()
        return try await provider.reportArticleComment(
            commentID: commentID,
            reason: reason,
            details: details,
            forAccountID: accountID
        )
    }
    func blockCommunityAuthor(authorID: String) async throws {
        let (provider, accountID) = try await communityProviderForActiveAccount()
        try await provider.blockCommunityAuthor(
            authorID: authorID,
            forAccountID: accountID
        )
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
        let hasSession = try await hasAccountSession()
        if hasSession {
            return try await base.videoDetails(id: id)
        }
        return try await guest.videoDetails(id: id)
    }

    func continueWatching() async throws -> [ContinueWatchingItem] {
        try await personalProvider().continueWatching()
    }

    func watchHistory() async throws -> [WatchHistoryItem] {
        try await personalProvider().watchHistory()
    }

    func removeWatchHistoryItem(videoID: String) async throws {
        try await personalProvider().removeWatchHistoryItem(videoID: videoID)
    }

    func clearWatchHistory() async throws {
        try await personalProvider().clearWatchHistory()
    }

    func watchProgress(videoID: String) async throws -> WatchProgress? {
        try await personalProvider().watchProgress(videoID: videoID)
    }

    func saveWatchProgress(
        videoID: String,
        positionSeconds: Int,
        completed: Bool
    ) async throws -> WatchProgress {
        try await personalProvider().saveWatchProgress(
            videoID: videoID,
            positionSeconds: positionSeconds,
            completed: completed
        )
    }

    func favoriteVideos() async throws -> [SportsVideo] {
        try await personalProvider().favoriteVideos()
    }

    func videoFavorite(videoID: String) async throws -> VideoFavoriteState {
        try await personalProvider().videoFavorite(videoID: videoID)
    }

    func setVideoFavorite(videoID: String, isFavorite: Bool) async throws -> VideoFavoriteState {
        try await personalProvider().setVideoFavorite(videoID: videoID, isFavorite: isFavorite)
    }

    func follows() async throws -> [SportsFollow] {
        try await personalProvider().follows()
    }

    func follows(forAccountID accountID: String?) async throws -> [SportsFollow] {
        let provider = try await identityBoundProvider(forAccountID: accountID)
        if let accountID {
            guard let scopedProvider = provider as? any IdentityScopedFollowProviding else {
                throw SportsDataError.unauthorized
            }
            return try await scopedProvider.follows(forAccountID: accountID)
        }
        return try await provider.follows()
    }

    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool
    ) async throws -> SportsFollow? {
        try await personalProvider().setFollow(
            type: type,
            entityID: entityID,
            entity: entity,
            isFollowing: isFollowing
        )
    }

    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool,
        forAccountID accountID: String?
    ) async throws -> SportsFollow? {
        let provider = try await identityBoundProvider(forAccountID: accountID)
        if let accountID {
            guard let scopedProvider = provider as? any IdentityScopedFollowProviding else {
                throw SportsDataError.unauthorized
            }
            return try await scopedProvider.setFollow(
                type: type,
                entityID: entityID,
                entity: entity,
                isFollowing: isFollowing,
                forAccountID: accountID
            )
        }
        return try await provider.setFollow(
            type: type,
            entityID: entityID,
            entity: entity,
            isFollowing: isFollowing
        )
    }

    func notificationPreferences() async throws -> NotificationPreferences {
        try await personalProvider().notificationPreferences()
    }

    func setNotificationPreference(
        _ type: NotificationPreferenceType,
        enabled: Bool
    ) async throws -> NotificationPreferences {
        try await personalProvider().setNotificationPreference(type, enabled: enabled)
    }

    func registerNotificationDevice(_ registration: PushDeviceRegistration) async throws {
        try await personalProvider().registerNotificationDevice(registration)
    }

    func predictionGames() async throws -> [PredictionGame] {
        try await base.predictionGames()
    }

    func predictionEntry(for game: PredictionGame) async throws -> PredictionEntry? {
        try await personalProvider().predictionEntry(for: game)
    }

    func predictionEntry(
        for game: PredictionGame,
        forAccountID accountID: String
    ) async throws -> PredictionEntry? {
        let provider = try await identityBoundProvider(forAccountID: accountID)
        guard let scoped = provider as? any IdentityScopedPredictionProviding else {
            throw SportsDataError.unauthorized
        }
        return try await scoped.predictionEntry(for: game, forAccountID: accountID)
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking]
    ) async throws -> PredictionEntry {
        try await personalProvider().savePredictionEntry(for: game, rankings: rankings)
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking],
        forAccountID accountID: String
    ) async throws -> PredictionEntry {
        let provider = try await identityBoundProvider(forAccountID: accountID)
        guard let scoped = provider as? any IdentityScopedPredictionProviding else {
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
        try await base.createPlaybackSession(
            videoID: videoID,
            deviceID: deviceID,
            capabilities: capabilities
        )
    }

    func search(query: String) async throws -> [SearchResultItem] {
        try await base.search(query: query)
    }

    private func personalProvider() async throws -> any SportsDataProviding {
        try await hasAccountSession() ? authenticated : guest
    }

    private func communityProviderForActiveAccount() async throws -> (
        provider: any IdentityScopedCommunityProviding,
        accountID: String
    ) {
        guard communityMutationsEnabled else {
            throw SportsDataError.forbidden
        }
        guard let accountID = try await activeAccountID() else {
            throw SportsDataError.unauthorized
        }
        let provider = try await identityBoundProvider(forAccountID: accountID)
        guard let scoped = provider as? any IdentityScopedCommunityProviding else {
            throw SportsDataError.unauthorized
        }
        return (scoped, accountID)
    }

    private func activeAccountID() async throws -> String? {
        do {
            return try await sessionStore.session()?.user.id
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
    }

    /// Resolves a personal provider only when the caller's captured identity
    /// still matches the active session. This prevents a stale task from using
    /// a newly signed-in account's token after an account switch.
    private func identityBoundProvider(
        forAccountID accountID: String?
    ) async throws -> any SportsDataProviding {
        let session: AuthSession?
        do {
            session = try await sessionStore.session()
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
        switch (accountID, session?.user.id) {
        case (nil, nil):
            return guest
        case let (.some(expectedID), .some(currentID)) where expectedID == currentID:
            return authenticated
        default:
            throw SportsDataError.unauthorized
        }
    }

    private func hasAccountSession() async throws -> Bool {
        do {
            return try await sessionStore.session() != nil
        } catch {
            throw SportsDataError.localStorageUnavailable
        }
    }
}
