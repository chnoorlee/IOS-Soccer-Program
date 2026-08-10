import Foundation

protocol AuthenticationClient: Sendable {
    func signInWithApple(_ credential: AppleSignInCredential) async throws -> AuthSession
    func refreshSession(refreshToken: String) async throws -> AuthSession
    func revokeSession(accessToken: String, refreshToken: String) async throws
    func deleteAccount(accessToken: String, idempotencyKey: String) async throws
    func mergeGuestPersonalization(
        _ state: GuestPersonalizationState,
        accessToken: String
    ) async throws -> GuestMergeResult
}

struct UnavailableAuthenticationClient: AuthenticationClient {
    func signInWithApple(_ credential: AppleSignInCredential) async throws -> AuthSession {
        throw AuthenticationError.unavailable
    }

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        throw AuthenticationError.unavailable
    }

    func revokeSession(accessToken: String, refreshToken: String) async throws {
        throw AuthenticationError.unavailable
    }

    func deleteAccount(accessToken: String, idempotencyKey: String) async throws {
        throw AuthenticationError.unavailable
    }

    func mergeGuestPersonalization(
        _ state: GuestPersonalizationState,
        accessToken: String
    ) async throws -> GuestMergeResult {
        throw AuthenticationError.unavailable
    }
}

struct RemoteAuthenticationClient: AuthenticationClient {
    private let baseURL: URL
    private let client: any HTTPClient
    private let now: @Sendable () -> Date

    init(
        baseURL: URL,
        client: any HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = Date.init
    ) throws {
        guard baseURL.scheme?.lowercased() == "https",
              baseURL.host != nil,
              baseURL.pathComponents.last == "v1",
              baseURL.query == nil,
              baseURL.fragment == nil else {
            throw AuthenticationError.unavailable
        }
        self.baseURL = baseURL
        self.client = client
        self.now = now
    }

    func signInWithApple(_ credential: AppleSignInCredential) async throws -> AuthSession {
        try validateCredential(credential)
        let body = AppleSignInRequestDTO(
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode,
            rawNonce: credential.rawNonce,
            givenName: credential.givenName,
            familyName: credential.familyName,
            email: credential.email
        )
        let response: AuthSessionResponseDTO = try await post(
            path: ["auth", "apple"],
            body: body,
            accessToken: nil,
            idempotencyKey: nil,
            accepting: [200]
        )
        return try response.data.domain(now: now())
    }

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        let refreshToken = try validatedToken(refreshToken, field: "refreshToken")
        let response: AuthSessionResponseDTO = try await post(
            path: ["auth", "refresh"],
            body: AuthRefreshRequestDTO(refreshToken: refreshToken),
            accessToken: nil,
            idempotencyKey: nil,
            accepting: [200]
        )
        return try response.data.domain(now: now())
    }

    func revokeSession(accessToken: String, refreshToken: String) async throws {
        let accessToken = try validatedToken(accessToken, field: "accessToken")
        let refreshToken = try validatedToken(refreshToken, field: "refreshToken")
        let _: EmptyResponse = try await post(
            path: ["auth", "logout"],
            body: AuthLogoutRequestDTO(refreshToken: refreshToken),
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString,
            accepting: [204]
        )
    }

    func deleteAccount(accessToken: String, idempotencyKey: String) async throws {
        let accessToken = try validatedToken(accessToken, field: "accessToken")
        let idempotencyKey = try validatedIdempotencyKey(idempotencyKey)
        var url = baseURL
        url.appendPathComponent("me")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        _ = try await send(request, accepting: [204])
    }

    func mergeGuestPersonalization(
        _ state: GuestPersonalizationState,
        accessToken: String
    ) async throws -> GuestMergeResult {
        try validateGuestState(state)
        guard state.watchProgress.count <= 500 else {
            throw AuthenticationError.contractViolation(field: "watchProgress")
        }
        guard state.videoFavorites.count <= 500 else {
            throw AuthenticationError.contractViolation(field: "videoFavorites")
        }
        guard state.articleFavorites.count <= 500 else {
            throw AuthenticationError.contractViolation(field: "articleFavorites")
        }
        guard state.follows.count <= 500 else {
            throw AuthenticationError.contractViolation(field: "follows")
        }
        let accessToken = try validatedToken(accessToken, field: "accessToken")
        let response: GuestMergeResponseDTO = try await post(
            path: ["me", "guest-merge"],
            body: GuestMergeRequestDTO(state: state),
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString,
            accepting: [200]
        )
        let result = try response.data.domain()
        let inputCount = state.watchProgress.count
            + state.videoFavorites.count
            + state.articleFavorites.count
            + state.follows.count
        let acknowledgedCount = result.progressUpserted
            + result.favoritesUpserted
            + result.articleFavoritesUpserted
            + result.followsUpserted
            + result.serverNewerRetained
        guard result.progressUpserted <= state.watchProgress.count,
              result.favoritesUpserted <= state.videoFavorites.count,
              result.articleFavoritesUpserted <= state.articleFavorites.count,
              result.followsUpserted <= state.follows.count,
              acknowledgedCount == inputCount else {
            throw AuthenticationError.contractViolation(field: "mergeAcknowledgement")
        }
        return result
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: [String],
        body: Body,
        accessToken: String?,
        idempotencyKey: String?,
        accepting statusCodes: Set<Int>
    ) async throws -> Response {
        var url = baseURL
        for component in path {
            url.appendPathComponent(component)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        do {
            request.httpBody = try APIJSON.makeEncoder().encode(body)
        } catch {
            throw AuthenticationError.contractViolation(field: "requestBody")
        }

        let response = try await send(request, accepting: statusCodes)

        if Response.self == EmptyResponse.self {
            guard let empty = EmptyResponse() as? Response else {
                throw AuthenticationError.decoding
            }
            return empty
        }
        do {
            return try APIJSON.makeDecoder().decode(Response.self, from: response.data)
        } catch {
            throw AuthenticationError.decoding
        }
    }

    private func send(
        _ request: URLRequest,
        accepting statusCodes: Set<Int>
    ) async throws -> HTTPResponse {
        let response: HTTPResponse
        do {
            response = try await client.send(request)
        } catch let error as SportsDataError {
            throw mapSportsDataError(error)
        } catch {
            throw AuthenticationError.serverUnavailable
        }

        guard statusCodes.contains(response.statusCode) else {
            switch response.statusCode {
            case 400:
                throw AuthenticationError.invalidCredential
            case 401, 403:
                throw AuthenticationError.unauthorized
            case 429:
                throw AuthenticationError.rateLimited
            case 500...599:
                throw AuthenticationError.serverUnavailable
            default:
                throw AuthenticationError.invalidResponse(statusCode: response.statusCode)
            }
        }
        return response
    }

    private func validateCredential(_ credential: AppleSignInCredential) throws {
        _ = try validatedToken(credential.identityToken, field: "identityToken")
        guard (8...8192).contains(credential.authorizationCode.count),
              credential.authorizationCode.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              credential.authorizationCode.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }),
              (32...128).contains(credential.rawNonce.count),
              credential.rawNonce.unicodeScalars.allSatisfy({
                  CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
              }) else {
            throw AuthenticationError.invalidCredential
        }
    }

    private func validateGuestState(_ state: GuestPersonalizationState) throws {
        let maximumUpdateTime = now().addingTimeInterval(5 * 60)
        for progress in state.watchProgress {
            _ = try validatedPersonalIdentifier(progress.videoID, field: "watchProgress.videoId")
            guard progress.positionSeconds >= 0,
                  progress.updatedAt <= maximumUpdateTime else {
                throw AuthenticationError.contractViolation(field: "watchProgress")
            }
        }
        for favorite in state.videoFavorites {
            _ = try validatedPersonalIdentifier(favorite.videoID, field: "videoFavorites.videoId")
            guard favorite.updatedAt <= maximumUpdateTime else {
                throw AuthenticationError.contractViolation(field: "videoFavorites")
            }
        }
        for favorite in state.articleFavorites {
            _ = try validatedPersonalIdentifier(
                favorite.articleID,
                field: "articleFavorites.articleId"
            )
            guard favorite.updatedAt <= maximumUpdateTime else {
                throw AuthenticationError.contractViolation(field: "articleFavorites")
            }
        }
        for follow in state.follows {
            _ = try validatedPersonalIdentifier(follow.entityID, field: "follows.entityId")
            guard follow.updatedAt <= maximumUpdateTime else {
                throw AuthenticationError.contractViolation(field: "follows")
            }
        }

        guard Set(state.watchProgress.map(\.videoID)).count == state.watchProgress.count,
              Set(state.videoFavorites.map(\.videoID)).count == state.videoFavorites.count,
              Set(state.articleFavorites.map(\.articleID)).count
                == state.articleFavorites.count,
              Set(state.follows.map {
                  "\($0.type.rawValue):\($0.entityID)"
              }).count == state.follows.count else {
            throw AuthenticationError.contractViolation(field: "guestDuplicates")
        }
    }

    private func validatedPersonalIdentifier(_ value: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\?#")
        guard value == trimmed,
              !value.isEmpty,
              value.count <= 128,
              value.rangeOfCharacter(from: forbidden) == nil,
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw AuthenticationError.contractViolation(field: field)
        }
        return value
    }

    private func validatedToken(_ token: String, field: String) throws -> String {
        guard (16...16384).contains(token.count),
              token.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              token.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw AuthenticationError.contractViolation(field: field)
        }
        return token
    }

    private func validatedIdempotencyKey(_ value: String) throws -> String {
        guard (16...128).contains(value.count),
              value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw AuthenticationError.contractViolation(field: "idempotencyKey")
        }
        return value
    }

    private func mapSportsDataError(_ error: SportsDataError) -> AuthenticationError {
        switch error {
        case .networkUnavailable:
            .networkUnavailable
        case .rateLimited:
            .rateLimited
        case .unauthorized, .forbidden:
            .unauthorized
        default:
            .serverUnavailable
        }
    }
}

private struct AppleSignInRequestDTO: Encodable {
    let identityToken: String
    let authorizationCode: String
    let rawNonce: String
    let givenName: String?
    let familyName: String?
    let email: String?
}

private struct AuthRefreshRequestDTO: Encodable {
    let refreshToken: String
}

private struct AuthLogoutRequestDTO: Encodable {
    let refreshToken: String
}

private struct AuthSessionResponseDTO: Decodable {
    let data: AuthSessionDTO
}

private struct AuthSessionDTO: Decodable {
    let user: AuthUser
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let refreshTokenExpiresAt: Date

    func domain(now: Date) throws -> AuthSession {
        let userID = user.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty,
              userID.count <= 128,
              !displayName.isEmpty,
              displayName.count <= 200,
              user.createdAt <= now.addingTimeInterval(5 * 60),
              userID.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }),
              displayName.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw AuthenticationError.contractViolation(field: "user")
        }
        if let email {
            guard !email.isEmpty,
                  email.count <= 320,
                  email.contains("@"),
                  email.unicodeScalars.allSatisfy({
                      !CharacterSet.controlCharacters.contains($0)
                  }) else {
                throw AuthenticationError.contractViolation(field: "user.email")
            }
        }
        guard (16...16384).contains(accessToken.count),
              (16...16384).contains(refreshToken.count),
              accessToken.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              refreshToken.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              accessToken.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }),
              refreshToken.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw AuthenticationError.contractViolation(field: "tokens")
        }
        guard accessTokenExpiresAt > now,
              accessTokenExpiresAt <= now.addingTimeInterval(60 * 60),
              refreshTokenExpiresAt > accessTokenExpiresAt,
              refreshTokenExpiresAt <= now.addingTimeInterval(90 * 24 * 60 * 60) else {
            throw AuthenticationError.contractViolation(field: "tokenExpiry")
        }
        return AuthSession(
            user: AuthUser(
                id: userID,
                displayName: displayName,
                email: email,
                createdAt: user.createdAt
            ),
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: accessTokenExpiresAt,
            refreshTokenExpiresAt: refreshTokenExpiresAt
        )
    }
}

private struct GuestMergeRequestDTO: Encodable {
    let watchProgress: [GuestWatchProgressDTO]
    let videoFavorites: [GuestVideoFavoriteDTO]
    let articleFavorites: [GuestArticleFavoriteDTO]
    let follows: [GuestFollowDTO]

    init(state: GuestPersonalizationState) {
        watchProgress = state.watchProgress.map(GuestWatchProgressDTO.init)
        videoFavorites = state.videoFavorites.map(GuestVideoFavoriteDTO.init)
        articleFavorites = state.articleFavorites.map(GuestArticleFavoriteDTO.init)
        follows = state.follows.map(GuestFollowDTO.init)
    }
}

private struct GuestWatchProgressDTO: Encodable {
    let videoId: String
    let positionSeconds: Int
    let completed: Bool
    let updatedAt: Date

    init(_ progress: WatchProgress) {
        videoId = progress.videoID
        positionSeconds = progress.positionSeconds
        completed = progress.completed
        updatedAt = progress.updatedAt
    }
}

private struct GuestVideoFavoriteDTO: Encodable {
    let videoId: String
    let updatedAt: Date

    init(_ favorite: GuestVideoFavoriteRecord) {
        videoId = favorite.videoID
        updatedAt = favorite.updatedAt
    }
}

private struct GuestArticleFavoriteDTO: Encodable {
    let articleId: String
    let updatedAt: Date

    init(_ favorite: GuestArticleFavoriteRecord) {
        articleId = favorite.articleID
        updatedAt = favorite.updatedAt
    }
}

private struct GuestFollowDTO: Encodable {
    let type: FollowEntityType
    let entityId: String
    let updatedAt: Date

    init(_ follow: GuestFollowRecord) {
        type = follow.type
        entityId = follow.entityID
        updatedAt = follow.updatedAt
    }
}

private struct GuestMergeResponseDTO: Decodable {
    let data: GuestMergeResultDTO
}

private struct GuestMergeResultDTO: Decodable {
    let progressUpserted: Int
    let favoritesUpserted: Int
    let articleFavoritesUpserted: Int
    let followsUpserted: Int
    let serverNewerRetained: Int

    func domain() throws -> GuestMergeResult {
        guard progressUpserted >= 0,
              favoritesUpserted >= 0,
              articleFavoritesUpserted >= 0,
              followsUpserted >= 0,
              serverNewerRetained >= 0 else {
            throw AuthenticationError.contractViolation(field: "mergeCounts")
        }
        return GuestMergeResult(
            progressUpserted: progressUpserted,
            favoritesUpserted: favoritesUpserted,
            articleFavoritesUpserted: articleFavoritesUpserted,
            followsUpserted: followsUpserted,
            serverNewerRetained: serverNewerRetained
        )
    }
}

private struct EmptyResponse: Decodable {
    init() {}
}
