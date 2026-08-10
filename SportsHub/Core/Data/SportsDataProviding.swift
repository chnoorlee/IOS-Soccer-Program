import Foundation

enum TeamMatchSnapshotRequestLimits {
    static let maximumTeamsPerHTTPBatch = 20
    static let maximumTeamsPerDashboard = 100
}

enum TransferPaginationContract {
    static let maximumPageSize = 100
    static let maximumCursorLength = 512
}

enum VideoProgramPaginationContract {
    static let maximumPageSize = 50
    static let maximumCursorLength = 2_048
    static let maximumDescriptionLength = 500
}

enum SeasonCalendarDataContract {
    static let maximumEventCount = 200
    static let maximumWindowDuration: TimeInterval = 400 * 24 * 60 * 60
    static let maximumEventDuration: TimeInterval = 120 * 24 * 60 * 60
    static let maximumSourceNameLength = 100
    static let maximumTitleLength = 160
    static let maximumDetailLength = 500
}

enum CompetitionSeasonCatalogContract {
    static let maximumSeasonCount = 50

    static func validate(
        seasons: [Season],
        currentSeasonID: String?,
        field: String
    ) throws {
        guard seasons.count <= maximumSeasonCount else {
            throw SportsDataError.contractViolation(field: "\(field).seasons")
        }

        var seasonIDs = Set<String>()
        for (index, season) in seasons.enumerated() {
            guard seasonIDs.insert(season.id).inserted else {
                throw SportsDataError.contractViolation(field: "\(field).seasons.id")
            }
            guard season.startDate < season.endDate else {
                throw SportsDataError.contractViolation(
                    field: "\(field).seasons[\(index)].startDate"
                )
            }
            guard index > 0 else { continue }
            let previous = seasons[index - 1]
            guard previous.startDate > season.startDate
                    || (previous.startDate == season.startDate && previous.id < season.id) else {
                throw SportsDataError.contractViolation(field: "\(field).seasons.order")
            }
        }

        let currentSeasons = seasons.filter(\.isCurrent)
        if let currentSeasonID {
            guard currentSeasons.count == 1,
                  currentSeasons[0].id == currentSeasonID else {
                throw SportsDataError.contractViolation(field: "\(field).currentSeasonId")
            }
        } else if !currentSeasons.isEmpty {
            throw SportsDataError.contractViolation(field: "\(field).currentSeasonId")
        }
    }
}

protocol SportsDataProviding: Sendable {
    func teams() async throws -> [Team]
    func players() async throws -> [PlayerProfile]
    func competitions() async throws -> [Competition]
    func teamDetails(id: String) async throws -> TeamDetails
    func teamMatchSnapshots(ids: [String]) async throws -> [TeamMatchSnapshot]
    func teamContent(id: String) async throws -> TeamContent
    func teamSquad(id: String, seasonID: String) async throws -> [PlayerProfile]
    func playerDetails(id: String) async throws -> PlayerDetails
    func playerContent(id: String) async throws -> PlayerContent
    func playerTransfers(id: String) async throws -> [PlayerTransfer]
    func transferUpdates(
        cursor: String?,
        limit: Int,
        status: TransferStatus?
    ) async throws -> TransferPage
    func seasonCalendar() async throws -> SeasonCalendarSnapshot
    func competitionStandings(id: String, seasonID: String) async throws -> [StandingGroup]
    func competitionLeaders(
        id: String,
        seasonID: String,
        category: CompetitionLeaderCategory
    ) async throws -> [CompetitionLeader]
    func competitionFixtures(id: String, seasonID: String) async throws -> [Fixture]
    func competitionContent(id: String) async throws -> CompetitionContent
    func homeFeed() async throws -> HomeFeed
    func fixtures(on date: Date) async throws -> [Fixture]
    func fixtureDetails(id: String) async throws -> MatchDetails
    func fixtureContent(id: String) async throws -> FixtureContent
    func fixtureEventUpdates(id: String, afterRevision: Int) async throws -> FixtureEventBatch
    func fixtureStandings(for fixture: Fixture) async throws -> FixtureStandingsContext
    func fixtureHeadToHead(
        for fixture: Fixture,
        limit: Int
    ) async throws -> FixtureHeadToHeadContext
    func articles() async throws -> [Article]
    func articleDetails(id: String) async throws -> ArticleDetails
    func favoriteArticles() async throws -> [Article]
    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState
    func setArticleFavorite(
        articleID: String,
        isFavorite: Bool
    ) async throws -> ArticleFavoriteState
    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int
    ) async throws -> ArticleCommentPage
    func articleReaction(articleID: String) async throws -> ArticleReactionSummary
    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?
    ) async throws -> ArticleReactionSummary
    func createArticleComment(articleID: String, body: String) async throws -> ArticleComment
    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?
    ) async throws -> CommunityReportReceipt
    func blockCommunityAuthor(authorID: String) async throws
    func videoDiscovery() async throws -> VideoDiscoveryFeed
    func videoPrograms(
        cursor: String?,
        limit: Int,
        sport: VideoSport?
    ) async throws -> VideoProgramPage
    func videoProgramDetails(
        id: String,
        cursor: String?,
        limit: Int
    ) async throws -> VideoProgramDetailsPage
    func videos() async throws -> [SportsVideo]
    func videoDetails(id: String) async throws -> SportsVideoDetails
    func continueWatching() async throws -> [ContinueWatchingItem]
    func watchHistory() async throws -> [WatchHistoryItem]
    func removeWatchHistoryItem(videoID: String) async throws
    func clearWatchHistory() async throws
    func watchProgress(videoID: String) async throws -> WatchProgress?
    func saveWatchProgress(
        videoID: String,
        positionSeconds: Int,
        completed: Bool
    ) async throws -> WatchProgress
    func favoriteVideos() async throws -> [SportsVideo]
    func videoFavorite(videoID: String) async throws -> VideoFavoriteState
    func setVideoFavorite(videoID: String, isFavorite: Bool) async throws -> VideoFavoriteState
    func follows() async throws -> [SportsFollow]
    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool
    ) async throws -> SportsFollow?
    func notificationPreferences() async throws -> NotificationPreferences
    func setNotificationPreference(
        _ type: NotificationPreferenceType,
        enabled: Bool
    ) async throws -> NotificationPreferences
    func registerNotificationDevice(_ registration: PushDeviceRegistration) async throws
    func predictionGames() async throws -> [PredictionGame]
    func predictionEntry(for game: PredictionGame) async throws -> PredictionEntry?
    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking]
    ) async throws -> PredictionEntry
    func createPlaybackSession(
        videoID: String,
        deviceID: String,
        capabilities: PlaybackCapabilities
    ) async throws -> PlaybackSession
    func search(query: String) async throws -> [SearchResultItem]
}

extension SportsDataProviding {
    func setFollow(
        type: FollowEntityType,
        entityID: String,
        isFollowing: Bool
    ) async throws -> SportsFollow? {
        try await setFollow(
            type: type,
            entityID: entityID,
            entity: nil,
            isFollowing: isFollowing
        )
    }
}

protocol IdentityScopedFollowProviding: Sendable {
    func follows(forAccountID accountID: String?) async throws -> [SportsFollow]
    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool,
        forAccountID accountID: String?
    ) async throws -> SportsFollow?
}

protocol IdentityScopedPredictionProviding: Sendable {
    func predictionEntry(
        for game: PredictionGame,
        forAccountID accountID: String
    ) async throws -> PredictionEntry?
    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking],
        forAccountID accountID: String
    ) async throws -> PredictionEntry
}

protocol IdentityScopedCommunityProviding: Sendable {
    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int,
        forAccountID accountID: String
    ) async throws -> ArticleCommentPage
    func articleReaction(
        articleID: String,
        forAccountID accountID: String
    ) async throws -> ArticleReactionSummary
    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?,
        forAccountID accountID: String
    ) async throws -> ArticleReactionSummary
    func createArticleComment(
        articleID: String,
        body: String,
        forAccountID accountID: String
    ) async throws -> ArticleComment
    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?,
        forAccountID accountID: String
    ) async throws -> CommunityReportReceipt
    func blockCommunityAuthor(authorID: String, forAccountID accountID: String) async throws
}

enum SportsDataError: LocalizedError, Equatable, Sendable {
    case invalidConfiguration
    case invalidQuery
    case fixtureNotFound
    case unauthorized
    case forbidden
    case notFound
    case contentWithdrawn
    case contentRejected
    case rateLimited
    case serverUnavailable
    case networkUnavailable
    case localStorageUnavailable
    case invalidResponse(statusCode: Int)
    case contractViolation(field: String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "The sports data service is not configured."
        case .invalidQuery:
            "The search query must contain between 2 and 100 characters."
        case .fixtureNotFound:
            "The requested fixture could not be found."
        case .unauthorized:
            "Authentication is required."
        case .forbidden:
            "The requested sports content is not available for this account or region."
        case .notFound:
            "The requested sports resource could not be found."
        case .contentWithdrawn:
            "The requested content has been withdrawn."
        case .contentRejected:
            "The submitted community content was not accepted."
        case .rateLimited:
            "The sports data service is temporarily rate limited."
        case .serverUnavailable:
            "The sports data service is temporarily unavailable."
        case .networkUnavailable:
            "A network connection is unavailable."
        case .localStorageUnavailable:
            "Personal sports data could not be read or saved on this device."
        case let .invalidResponse(statusCode):
            "The sports data service returned HTTP \(statusCode)."
        case let .contractViolation(field):
            "The sports data response violated the contract at \(field)."
        case .decoding:
            "The sports data response could not be decoded."
        }
    }

    var isRecoverableForFallback: Bool {
        switch self {
        case .networkUnavailable, .rateLimited, .serverUnavailable:
            true
        default:
            false
        }
    }

    static func normalized(_ error: Error) -> SportsDataError {
        if let dataError = error as? SportsDataError {
            return dataError
        }
        if error is URLError {
            return .networkUnavailable
        }
        return .serverUnavailable
    }
}
