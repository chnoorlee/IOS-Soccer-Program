import Foundation

struct AuthUser: Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let email: String?
    let createdAt: Date
}

struct AuthSession: Codable, Equatable, Sendable {
    let user: AuthUser
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let refreshTokenExpiresAt: Date

    func hasUsableAccessToken(
        at date: Date,
        minimumValidity: TimeInterval = 60
    ) -> Bool {
        accessTokenExpiresAt > date.addingTimeInterval(minimumValidity)
    }

    func hasUsableRefreshToken(at date: Date) -> Bool {
        refreshTokenExpiresAt > date
    }
}

struct AppleSignInCredential: Equatable, Sendable {
    let identityToken: String
    let authorizationCode: String
    let rawNonce: String
    let givenName: String?
    let familyName: String?
    let email: String?
}

struct GuestVideoFavoriteRecord: Codable, Equatable, Sendable {
    let videoID: String
    let updatedAt: Date
}

struct GuestArticleFavoriteRecord: Codable, Equatable, Sendable {
    let articleID: String
    let updatedAt: Date
}

struct GuestFollowRecord: Codable, Equatable, Sendable {
    let type: FollowEntityType
    let entityID: String
    let updatedAt: Date
}

struct GuestPersonalizationState: Codable, Equatable, Sendable {
    let watchProgress: [WatchProgress]
    let videoFavorites: [GuestVideoFavoriteRecord]
    let articleFavorites: [GuestArticleFavoriteRecord]
    let follows: [GuestFollowRecord]

    init(
        watchProgress: [WatchProgress],
        videoFavorites: [GuestVideoFavoriteRecord],
        articleFavorites: [GuestArticleFavoriteRecord] = [],
        follows: [GuestFollowRecord] = []
    ) {
        self.watchProgress = watchProgress
        self.videoFavorites = videoFavorites
        self.articleFavorites = articleFavorites
        self.follows = follows
    }

    private enum CodingKeys: String, CodingKey {
        case watchProgress
        case videoFavorites
        case articleFavorites
        case follows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        watchProgress = try container.decodeIfPresent(
            [WatchProgress].self,
            forKey: .watchProgress
        ) ?? []
        videoFavorites = try container.decodeIfPresent(
            [GuestVideoFavoriteRecord].self,
            forKey: .videoFavorites
        ) ?? []
        articleFavorites = try container.decodeIfPresent(
            [GuestArticleFavoriteRecord].self,
            forKey: .articleFavorites
        ) ?? []
        follows = try container.decodeIfPresent(
            [GuestFollowRecord].self,
            forKey: .follows
        ) ?? []
    }

    static let empty = GuestPersonalizationState(
        watchProgress: [],
        videoFavorites: [],
        articleFavorites: [],
        follows: []
    )

    var summary: GuestPersonalizationSummary {
        GuestPersonalizationSummary(
            progressCount: watchProgress.count,
            favoriteCount: videoFavorites.count,
            articleFavoriteCount: articleFavorites.count,
            followCount: follows.count,
            videoSnapshotCount: 0
        )
    }

    func mergeBatches(maxItemsPerType: Int = 500) -> [GuestPersonalizationState] {
        guard maxItemsPerType > 0 else { return [] }
        let progressBatchCount = (watchProgress.count + maxItemsPerType - 1) / maxItemsPerType
        let favoriteBatchCount = (videoFavorites.count + maxItemsPerType - 1) / maxItemsPerType
        let articleFavoriteBatchCount =
            (articleFavorites.count + maxItemsPerType - 1) / maxItemsPerType
        let followBatchCount = (follows.count + maxItemsPerType - 1) / maxItemsPerType
        let batchCount = max(
            progressBatchCount,
            max(favoriteBatchCount, max(articleFavoriteBatchCount, followBatchCount))
        )
        guard batchCount > 0 else { return [] }

        return (0..<batchCount).map { index in
            let progressStart = min(index * maxItemsPerType, watchProgress.count)
            let progressEnd = min(progressStart + maxItemsPerType, watchProgress.count)
            let favoriteStart = min(index * maxItemsPerType, videoFavorites.count)
            let favoriteEnd = min(favoriteStart + maxItemsPerType, videoFavorites.count)
            let articleFavoriteStart = min(index * maxItemsPerType, articleFavorites.count)
            let articleFavoriteEnd = min(
                articleFavoriteStart + maxItemsPerType,
                articleFavorites.count
            )
            let followStart = min(index * maxItemsPerType, follows.count)
            let followEnd = min(followStart + maxItemsPerType, follows.count)
            return GuestPersonalizationState(
                watchProgress: Array(watchProgress[progressStart..<progressEnd]),
                videoFavorites: Array(videoFavorites[favoriteStart..<favoriteEnd]),
                articleFavorites: Array(
                    articleFavorites[articleFavoriteStart..<articleFavoriteEnd]
                ),
                follows: Array(follows[followStart..<followEnd])
            )
        }
    }
}

struct GuestPersonalizationSummary: Equatable, Sendable {
    let progressCount: Int
    let favoriteCount: Int
    let articleFavoriteCount: Int
    let followCount: Int
    let videoSnapshotCount: Int

    init(
        progressCount: Int,
        favoriteCount: Int,
        articleFavoriteCount: Int = 0,
        followCount: Int = 0,
        videoSnapshotCount: Int = 0
    ) {
        self.progressCount = progressCount
        self.favoriteCount = favoriteCount
        self.articleFavoriteCount = articleFavoriteCount
        self.followCount = followCount
        self.videoSnapshotCount = videoSnapshotCount
    }

    var hasMergeableData: Bool {
        progressCount > 0
            || favoriteCount > 0
            || articleFavoriteCount > 0
            || followCount > 0
    }

    var isEmpty: Bool {
        !hasMergeableData && videoSnapshotCount == 0
    }
}

enum GuestPersonalizationDefaults {
    static let followedTeamIDs = "app.followed.teamIDs"
}

struct GuestMergeResult: Equatable, Sendable {
    let progressUpserted: Int
    let favoritesUpserted: Int
    let articleFavoritesUpserted: Int
    let followsUpserted: Int
    let serverNewerRetained: Int

    init(
        progressUpserted: Int,
        favoritesUpserted: Int,
        articleFavoritesUpserted: Int = 0,
        followsUpserted: Int = 0,
        serverNewerRetained: Int
    ) {
        self.progressUpserted = progressUpserted
        self.favoritesUpserted = favoritesUpserted
        self.articleFavoritesUpserted = articleFavoritesUpserted
        self.followsUpserted = followsUpserted
        self.serverNewerRetained = serverNewerRetained
    }
}

enum AuthenticationStatus: Equatable, Sendable {
    case unavailable
    case loading
    case signedOut
    case authenticated(AuthUser)

    var user: AuthUser? {
        guard case let .authenticated(user) = self else { return nil }
        return user
    }
}

enum AuthenticationError: LocalizedError, Equatable, Sendable {
    case unavailable
    case cancelled
    case invalidCredential
    case unauthorized
    case rateLimited
    case networkUnavailable
    case serverUnavailable
    case secureStorageUnavailable
    case deviceStorageUnavailable
    case invalidResponse(statusCode: Int)
    case contractViolation(field: String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Account service is not configured."
        case .cancelled:
            "Sign in was cancelled."
        case .invalidCredential:
            "The identity credential is invalid."
        case .unauthorized:
            "The account session is no longer valid."
        case .rateLimited:
            "Too many account requests were made."
        case .networkUnavailable:
            "A network connection is unavailable."
        case .serverUnavailable:
            "The account service is temporarily unavailable."
        case .secureStorageUnavailable:
            "The secure account session could not be read or saved."
        case .deviceStorageUnavailable:
            "Guest sports data could not be read or cleared on this device."
        case let .invalidResponse(statusCode):
            "The account service returned HTTP \(statusCode)."
        case let .contractViolation(field):
            "The account response violated the contract at \(field)."
        case .decoding:
            "The account response could not be decoded."
        }
    }

    var localizationKey: String {
        switch self {
        case .unavailable:
            "auth.error.unavailable"
        case .cancelled:
            "auth.error.cancelled"
        case .invalidCredential:
            "auth.error.invalidCredential"
        case .unauthorized:
            "auth.error.unauthorized"
        case .rateLimited:
            "auth.error.rateLimited"
        case .networkUnavailable:
            "auth.error.networkUnavailable"
        case .serverUnavailable:
            "auth.error.serverUnavailable"
        case .secureStorageUnavailable:
            "auth.error.secureStorageUnavailable"
        case .deviceStorageUnavailable:
            "auth.error.deviceStorageUnavailable"
        case .invalidResponse, .contractViolation, .decoding:
            "auth.error.invalidResponse"
        }
    }
}
