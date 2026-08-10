import Foundation

struct RemoteSportsDataProvider: SportsDataProviding,
    IdentityScopedFollowProviding,
    IdentityScopedPredictionProviding,
    IdentityScopedCommunityProviding {
    private static let competitionFixturePageLimit = 100
    private static let maximumCompetitionFixtureCount = 1_000
    private static let competitionFixtureStaleIfError: TimeInterval = 6 * 60 * 60
    private static let videoPageLimit = 100
    private static let maximumVideoCount = 1_000
    private static let videoStaleIfError: TimeInterval = 15 * 60
    private static let transferStaleIfError: TimeInterval = 15 * 60
    private static let seasonCalendarStaleIfError: TimeInterval = 24 * 60 * 60

    private let baseURL: URL
    private let client: any HTTPClient
    private let cache: any SportsDataCaching
    private let accessTokenProvider: any AccessTokenProviding
    private let freshnessReporter: any PublicContentFreshnessReporting
    private let now: @Sendable () -> Date

    init(
        baseURL: URL,
        client: any HTTPClient = URLSessionHTTPClient(),
        cache: any SportsDataCaching = FileSportsDataCache(),
        accessTokenProvider: any AccessTokenProviding = NoAccessTokenProvider(),
        freshnessReporter: any PublicContentFreshnessReporting = NoopPublicContentFreshnessReporter(),
        now: @escaping @Sendable () -> Date = Date.init
    ) throws {
        guard baseURL.scheme?.lowercased() == "https",
              baseURL.host != nil,
              baseURL.pathComponents.last == "v1" else {
            throw SportsDataError.invalidConfiguration
        }
        self.baseURL = baseURL
        self.client = client
        self.cache = cache
        self.accessTokenProvider = accessTokenProvider
        self.freshnessReporter = freshnessReporter
        self.now = now
    }

    func teams() async throws -> [Team] {
        let url = try makeURL(
            pathComponents: ["teams"],
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )
        return try await load(
            TeamListResponseDTO.self,
            from: url,
            staleIfError: 7 * 24 * 60 * 60
        ) { try $0.domain() }
    }

    func players() async throws -> [PlayerProfile] {
        let url = try makeURL(
            pathComponents: ["players"],
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )
        return try await load(
            PlayerListResponseDTO.self,
            from: url,
            staleIfError: 7 * 24 * 60 * 60
        ) { try $0.domain() }
    }

    func competitions() async throws -> [Competition] {
        let url = try makeURL(
            pathComponents: ["competitions"],
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )
        return try await load(
            CompetitionListResponseDTO.self,
            from: url,
            staleIfError: 7 * 24 * 60 * 60
        ) { try $0.domain() }
    }

    func teamDetails(id: String) async throws -> TeamDetails {
        let id = try requestIdentifier(id)
        let url = try makeURL(pathComponents: ["teams", id])
        return try await load(
            TeamDetailResponseDTO.self,
            from: url,
            staleIfError: 60 * 60,
            resource: .team(id: id)
        ) { try $0.data.domain(expectedTeamID: id) }
    }

    func teamMatchSnapshots(ids: [String]) async throws -> [TeamMatchSnapshot] {
        let ids = try requestTeamSnapshotIDs(ids)
        let resource = PublicContentResource.teamMatchSnapshots(ids: ids)
        do {
            var snapshots: [TeamMatchSnapshot] = []
            var batchFreshness: [PublicContentFreshness] = []
            snapshots.reserveCapacity(ids.count)
            batchFreshness.reserveCapacity(
                (ids.count + TeamMatchSnapshotRequestLimits.maximumTeamsPerHTTPBatch - 1)
                    / TeamMatchSnapshotRequestLimits.maximumTeamsPerHTTPBatch
            )

            for start in stride(
                from: 0,
                to: ids.count,
                by: TeamMatchSnapshotRequestLimits.maximumTeamsPerHTTPBatch
            ) {
                try Task.checkCancellation()
                let end = min(
                    start + TeamMatchSnapshotRequestLimits.maximumTeamsPerHTTPBatch,
                    ids.count
                )
                let batchIDs = Array(ids[start..<end])
                let url = try makeURL(
                    pathComponents: ["teams", "match-snapshots"],
                    queryItems: batchIDs.map { URLQueryItem(name: "teamId", value: $0) }
                )
                let (batch, freshness) = try await loadValidated(
                    TeamMatchSnapshotListResponseDTO.self,
                    from: url,
                    staleIfError: 60 * 60
                ) { try $0.domain(expectedTeamIDs: batchIDs) }
                snapshots.append(contentsOf: batch)
                batchFreshness.append(freshness)
            }

            await freshnessReporter.record(
                aggregateBatchFreshness(batchFreshness),
                for: resource
            )
            return snapshots
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            await freshnessReporter.record(.refreshFailed(at: now()), for: resource)
            if error is DecodingError {
                throw SportsDataError.decoding
            }
            throw error
        }
    }

    func teamContent(id: String) async throws -> TeamContent {
        let id = try requestIdentifier(id)
        let url = try makeURL(pathComponents: ["teams", id, "content"])
        return try await load(
            TeamContentResponseDTO.self,
            from: url,
            staleIfError: 15 * 60,
            resource: .teamContent(id: id)
        ) { try $0.data.domain(expectedTeamID: id) }
    }

    func fixtureContent(id: String) async throws -> FixtureContent {
        let id = try requestIdentifier(id)
        let url = try makeURL(pathComponents: ["fixtures", id, "content"])
        return try await load(
            FixtureContentResponseDTO.self,
            from: url,
            staleIfError: 15 * 60,
            resource: .fixtureContent(id: id)
        ) { try $0.data.domain(expectedFixtureID: id) }
    }

    func teamSquad(id: String, seasonID: String) async throws -> [PlayerProfile] {
        let id = try requestIdentifier(id)
        let seasonID = try requestIdentifier(seasonID)
        let url = try makeURL(
            pathComponents: ["teams", id, "squad"],
            queryItems: [URLQueryItem(name: "seasonId", value: seasonID)]
        )
        return try await load(
            PlayerListResponseDTO.self,
            from: url,
            staleIfError: 6 * 60 * 60
        ) { try $0.domain() }
    }

    func playerDetails(id: String) async throws -> PlayerDetails {
        let id = try requestIdentifier(id)
        let url = try makeURL(pathComponents: ["players", id])
        return try await load(
            PlayerDetailResponseDTO.self,
            from: url,
            staleIfError: 60 * 60
        ) { try $0.data.domain() }
    }

    func playerContent(id: String) async throws -> PlayerContent {
        let id = try requestIdentifier(id)
        let url = try makeURL(pathComponents: ["players", id, "content"])
        return try await load(
            PlayerContentResponseDTO.self,
            from: url,
            staleIfError: 15 * 60,
            resource: .playerContent(id: id)
        ) { try $0.data.domain(expectedPlayerID: id) }
    }

    func playerTransfers(id: String) async throws -> [PlayerTransfer] {
        let id = try requestIdentifier(id)
        let url = try makeURL(
            pathComponents: ["players", id, "transfers"],
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )
        return try await load(
            TransferListResponseDTO.self,
            from: url,
            staleIfError: 6 * 60 * 60
        ) { try $0.domain() }
    }

    func transferUpdates(
        cursor: String?,
        limit: Int,
        status: TransferStatus?
    ) async throws -> TransferPage {
        guard (1...TransferPaginationContract.maximumPageSize).contains(limit) else {
            throw SportsDataError.invalidQuery
        }
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            let normalized = cursor.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.count <= TransferPaginationContract.maximumCursorLength,
                  let validated = validatedCursor(normalized) else {
                throw SportsDataError.invalidQuery
            }
            queryItems.append(URLQueryItem(name: "cursor", value: validated))
        }
        if let status {
            let value = switch status {
            case .rumored: "RUMORED"
            case .agreed: "AGREED"
            case .completed: "COMPLETED"
            }
            queryItems.append(URLQueryItem(name: "status", value: value))
        }
        let url = try makeURL(pathComponents: ["transfers"], queryItems: queryItems)
        return try await load(
            TransferListResponseDTO.self,
            from: url,
            staleIfError: Self.transferStaleIfError,
            resource: .transfers(status: status)
        ) {
            try $0.domainPage(maximumCount: limit, expectedStatus: status)
        }
    }

    func seasonCalendar() async throws -> SeasonCalendarSnapshot {
        let url = try makeURL(pathComponents: ["season-calendar"])
        return try await load(
            SeasonCalendarResponseDTO.self,
            from: url,
            staleIfError: Self.seasonCalendarStaleIfError,
            resource: .seasonCalendar
        ) {
            try $0.data.domain()
        }
    }

    func competitionStandings(id: String, seasonID: String) async throws -> [StandingGroup] {
        let id = try requestIdentifier(id)
        let seasonID = try requestIdentifier(seasonID)
        let url = try makeURL(
            pathComponents: ["competitions", id, "standings"],
            queryItems: [URLQueryItem(name: "seasonId", value: seasonID)]
        )
        return try await load(
            StandingsResponseDTO.self,
            from: url,
            staleIfError: 5 * 60
        ) { try $0.domain() }
    }

    func competitionContent(id: String) async throws -> CompetitionContent {
        let id = try requestIdentifier(id)
        let url = try makeURL(pathComponents: ["competitions", id, "content"])
        return try await load(
            CompetitionContentResponseDTO.self,
            from: url,
            staleIfError: 15 * 60,
            resource: .competitionContent(id: id)
        ) { try $0.data.domain(expectedCompetitionID: id) }
    }

    func competitionLeaders(
        id: String,
        seasonID: String,
        category: CompetitionLeaderCategory
    ) async throws -> [CompetitionLeader] {
        let id = try requestIdentifier(id)
        let seasonID = try requestIdentifier(seasonID)
        let url = try makeURL(
            pathComponents: ["competitions", id, "leaders"],
            queryItems: [
                URLQueryItem(name: "seasonId", value: seasonID),
                URLQueryItem(name: "type", value: category.apiValue),
                URLQueryItem(name: "limit", value: "100")
            ]
        )
        return try await load(
            LeaderListResponseDTO.self,
            from: url,
            staleIfError: 5 * 60
        ) { try $0.domain() }
    }

    func competitionFixtures(id: String, seasonID: String) async throws -> [Fixture] {
        let id = try requestIdentifier(id)
        let seasonID = try requestIdentifier(seasonID)
        let resource = PublicContentResource.competitionFixtures(
            id: id,
            seasonID: seasonID
        )
        do {
            var cursor: String?
            var seenCursors: Set<String> = []
            var seenFixtureIDs: Set<String> = []
            var fixtures: [Fixture] = []

            while true {
                var queryItems = [
                    URLQueryItem(name: "seasonId", value: seasonID),
                    URLQueryItem(
                        name: "limit",
                        value: String(Self.competitionFixturePageLimit)
                    )
                ]
                if let cursor {
                    queryItems.append(URLQueryItem(name: "cursor", value: cursor))
                }
                let url = try makeURL(
                    pathComponents: ["competitions", id, "fixtures"],
                    queryItems: queryItems
                )
                let page = try await load(
                    CompetitionFixtureListResponseDTO.self,
                    from: url,
                    staleIfError: Self.competitionFixtureStaleIfError,
                    resource: resource
                ) {
                    let page = try $0.domain(
                        expectedCompetitionID: id,
                        expectedSeasonID: seasonID
                    )
                    guard page.fixtures.count <= Self.competitionFixturePageLimit,
                          fixtures.count + page.fixtures.count
                            <= Self.maximumCompetitionFixtureCount else {
                        throw SportsDataError.contractViolation(field: "data")
                    }
                    var previous = fixtures.last
                    var validatedIDs = seenFixtureIDs
                    for fixture in page.fixtures {
                        if let previous,
                           previous.kickoff > fixture.kickoff
                            || (previous.kickoff == fixture.kickoff && previous.id >= fixture.id) {
                            throw SportsDataError.contractViolation(field: "data.order")
                        }
                        guard validatedIDs.insert(fixture.id).inserted else {
                            throw SportsDataError.contractViolation(field: "data.id")
                        }
                        previous = fixture
                    }
                    if page.hasMore {
                        guard !page.fixtures.isEmpty,
                              let nextCursor = page.nextCursor,
                              let nextValidatedCursor = validatedCursor(nextCursor),
                              !seenCursors.contains(nextValidatedCursor) else {
                            throw SportsDataError.contractViolation(field: "page.nextCursor")
                        }
                    } else if page.nextCursor != nil {
                        throw SportsDataError.contractViolation(field: "page.nextCursor")
                    }
                    return page
                }

                fixtures.append(contentsOf: page.fixtures)
                seenFixtureIDs.formUnion(page.fixtures.map(\.id))
                guard page.hasMore else {
                    return fixtures
                }
                guard !page.fixtures.isEmpty,
                      let nextCursor = page.nextCursor,
                      let nextValidatedCursor = validatedCursor(nextCursor),
                      seenCursors.insert(nextValidatedCursor).inserted else {
                    throw SportsDataError.contractViolation(field: "page.nextCursor")
                }
                cursor = nextValidatedCursor
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            await freshnessReporter.record(.refreshFailed(at: now()), for: resource)
            throw error
        }
    }

    func homeFeed() async throws -> HomeFeed {
        let url = try makeURL(pathComponents: ["home"])
        if await accessTokenProvider.accountSessionExists() {
            do {
                let request = try await authorizedRequest(url: url, method: "GET")
                let response = try await sendUncached(request, accepting: [200])
                let decoded = try decode(HomeResponseDTO.self, from: response.data)
                let domain = try decoded.data.domain()
                await freshnessReporter.record(
                    .accountLive(checkedAt: now()),
                    for: .home
                )
                return domain
            } catch {
                await freshnessReporter.record(.refreshFailed(at: now()), for: .home)
                throw error
            }
        }
        return try await load(
            HomeResponseDTO.self,
            from: url,
            staleIfError: 24 * 60 * 60,
            resource: .home
        ) { try $0.data.domain() }
    }

    func fixtures(on date: Date) async throws -> [Fixture] {
        let timeZone = TimeZone.autoupdatingCurrent
        let resource = PublicContentResource.fixtures(on: date, timeZone: timeZone)
        guard case let .fixtures(day, timeZoneIdentifier) = resource else {
            throw SportsDataError.invalidConfiguration
        }

        let url = try makeURL(
            pathComponents: ["fixtures"],
            queryItems: [
                URLQueryItem(name: "date", value: day),
                URLQueryItem(name: "timeZone", value: timeZoneIdentifier),
                URLQueryItem(name: "limit", value: "100")
            ]
        )
        return try await load(
            FixtureListResponseDTO.self,
            from: url,
            staleIfError: 6 * 60 * 60,
            resource: resource
        ) { try $0.domain() }
    }

    func fixtureDetails(id: String) async throws -> MatchDetails {
        let id = try fixtureIdentifier(id)
        let url = try makeURL(pathComponents: ["fixtures", id])

        do {
            return try await load(
                FixtureDetailResponseDTO.self,
                from: url,
                staleIfError: 60 * 60,
                resource: .fixture(id: id)
            ) { try $0.data.domain() }
        } catch SportsDataError.notFound {
            throw SportsDataError.fixtureNotFound
        }
    }

    func fixtureEventUpdates(
        id: String,
        afterRevision: Int
    ) async throws -> FixtureEventBatch {
        let id = try fixtureIdentifier(id)
        guard afterRevision >= 0 else {
            throw SportsDataError.contractViolation(field: "afterRevision")
        }
        let resource = PublicContentResource.fixture(id: id)

        do {
            let url = try makeURL(
                pathComponents: ["fixtures", id, "events"],
                queryItems: [
                    URLQueryItem(
                        name: "afterRevision",
                        value: String(afterRevision)
                    )
                ]
            )
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
            let response = try await sendUncached(request, accepting: [200])
            let decoded = try decode(FixtureEventsResponseDTO.self, from: response.data)
            let batch = try decoded.domain(
                expectedFixtureID: id,
                afterRevision: afterRevision
            )
            await freshnessReporter.record(.network(at: now()), for: resource)
            return batch
        } catch is CancellationError {
            throw CancellationError()
        } catch SportsDataError.notFound {
            await freshnessReporter.record(.refreshFailed(at: now()), for: resource)
            throw SportsDataError.fixtureNotFound
        } catch {
            if Task.isCancelled { throw CancellationError() }
            await freshnessReporter.record(.refreshFailed(at: now()), for: resource)
            throw error
        }
    }

    func fixtureStandings(for fixture: Fixture) async throws -> FixtureStandingsContext {
        let id = try fixtureIdentifier(fixture.id)
        let url = try makeURL(pathComponents: ["fixtures", id, "standings"])
        do {
            return try await load(
                FixtureStandingsResponseDTO.self,
                from: url,
                staleIfError: 5 * 60,
                resource: .fixtureStandings(id: id)
            ) { try $0.domain(expectedFixture: fixture) }
        } catch SportsDataError.notFound {
            throw SportsDataError.fixtureNotFound
        }
    }

    func fixtureHeadToHead(
        for fixture: Fixture,
        limit: Int
    ) async throws -> FixtureHeadToHeadContext {
        guard (1...20).contains(limit) else {
            throw SportsDataError.contractViolation(field: "limit")
        }
        let id = try fixtureIdentifier(fixture.id)
        let url = try makeURL(
            pathComponents: ["fixtures", id, "head-to-head"],
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
        do {
            return try await load(
                FixtureHeadToHeadResponseDTO.self,
                from: url,
                staleIfError: 6 * 60 * 60,
                resource: .fixtureHeadToHead(id: id)
            ) { try $0.domain(expectedFixture: fixture, limit: limit) }
        } catch SportsDataError.notFound {
            throw SportsDataError.fixtureNotFound
        }
    }

    func articles() async throws -> [Article] {
        let url = try makeURL(
            pathComponents: ["articles"],
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )
        return try await load(
            ArticleListResponseDTO.self,
            from: url,
            staleIfError: 6 * 60 * 60,
            resource: .articles
        ) { try $0.domain() }
    }

    func articleDetails(id: String) async throws -> ArticleDetails {
        let id = try requestIdentifier(id)
        let url = try makeURL(pathComponents: ["articles", id])
        return try await load(
            ArticleDetailResponseDTO.self,
            from: url,
            staleIfError: 6 * 60 * 60,
            resource: .article(id: id)
        ) {
            let details = try $0.data.domain()
            guard details.article.id == id else {
                throw SportsDataError.contractViolation(field: "data.article.id")
            }
            return details
        }
    }

    func favoriteArticles() async throws -> [Article] {
        let url = try makeURL(
            pathComponents: ["me", "article-favorites"],
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )
        let request = try await authorizedRequest(url: url, method: "GET")
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(ArticleListResponseDTO.self, from: response.data)
        return try decoded.domain()
    }

    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState {
        let articleID = try requestIdentifier(articleID)
        let url = try makeURL(pathComponents: ["me", "article-favorites", articleID])
        let request = try await authorizedRequest(url: url, method: "GET")
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(ArticleFavoriteResponseDTO.self, from: response.data)
        let state = try decoded.data.domain()
        guard state.articleID == articleID else {
            throw SportsDataError.contractViolation(field: "data.articleId")
        }
        return state
    }

    func setArticleFavorite(
        articleID: String,
        isFavorite: Bool
    ) async throws -> ArticleFavoriteState {
        let articleID = try requestIdentifier(articleID)
        let url = try makeURL(pathComponents: ["me", "article-favorites", articleID])
        if isFavorite {
            let request = try await authorizedRequest(
                url: url,
                method: "PUT",
                idempotencyKey: true
            )
            let response = try await sendUncached(request, accepting: [200])
            let decoded = try decode(ArticleFavoriteResponseDTO.self, from: response.data)
            let state = try decoded.data.domain()
            guard state.articleID == articleID, state.isFavorite else {
                throw SportsDataError.contractViolation(field: "data.isFavorite")
            }
            return state
        }

        let request = try await authorizedRequest(
            url: url,
            method: "DELETE",
            idempotencyKey: true
        )
        _ = try await sendUncached(request, accepting: [204])
        return ArticleFavoriteState(articleID: articleID, isFavorite: false, updatedAt: nil)
    }

    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int
    ) async throws -> ArticleCommentPage {
        try await loadArticleComments(
            articleID: articleID,
            cursor: cursor,
            limit: limit,
            expectedAccountID: nil
        )
    }

    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int,
        forAccountID accountID: String
    ) async throws -> ArticleCommentPage {
        try await loadArticleComments(
            articleID: articleID,
            cursor: cursor,
            limit: limit,
            expectedAccountID: accountID
        )
    }

    private func loadArticleComments(
        articleID: String,
        cursor: String?,
        limit: Int,
        expectedAccountID: String?
    ) async throws -> ArticleCommentPage {
        let articleID = try requestIdentifier(articleID)
        guard (1...20).contains(limit) else {
            throw SportsDataError.invalidQuery
        }
        let cursor = try cursor.map { value in
            guard let validated = validatedCursor(value) else {
                throw SportsDataError.invalidQuery
            }
            return validated
        }
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let url = try makeURL(
            pathComponents: ["articles", articleID, "comments"],
            queryItems: queryItems
        )
        let request = try await communityReadRequest(
            url: url,
            expectedAccountID: expectedAccountID
        )
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(ArticleCommentListResponseDTO.self, from: response.data)
        let page = try decoded.domain(expectedArticleID: articleID, limit: limit, now: now())
        if page.hasMore {
            guard !page.comments.isEmpty,
                  let nextCursor = page.nextCursor,
                  let validated = validatedCursor(nextCursor),
                  validated != cursor else {
                throw SportsDataError.contractViolation(field: "page.nextCursor")
            }
        } else if page.nextCursor != nil {
            throw SportsDataError.contractViolation(field: "page.nextCursor")
        }
        return page
    }

    func articleReaction(articleID: String) async throws -> ArticleReactionSummary {
        try await loadArticleReaction(articleID: articleID, expectedAccountID: nil)
    }

    func articleReaction(
        articleID: String,
        forAccountID accountID: String
    ) async throws -> ArticleReactionSummary {
        try await loadArticleReaction(articleID: articleID, expectedAccountID: accountID)
    }

    private func loadArticleReaction(
        articleID: String,
        expectedAccountID: String?
    ) async throws -> ArticleReactionSummary {
        let articleID = try requestIdentifier(articleID)
        let url = try makeURL(pathComponents: ["articles", articleID, "reaction"])
        let request = try await communityReadRequest(
            url: url,
            expectedAccountID: expectedAccountID
        )
        let response = try await sendUncached(request, accepting: [200])
        return try decode(ArticleReactionResponseDTO.self, from: response.data).data.domain()
    }

    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?
    ) async throws -> ArticleReactionSummary {
        try await updateArticleReaction(
            articleID: articleID,
            reaction: reaction,
            expectedAccountID: nil
        )
    }

    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?,
        forAccountID accountID: String
    ) async throws -> ArticleReactionSummary {
        try await updateArticleReaction(
            articleID: articleID,
            reaction: reaction,
            expectedAccountID: accountID
        )
    }

    private func updateArticleReaction(
        articleID: String,
        reaction: ArticleReaction?,
        expectedAccountID: String?
    ) async throws -> ArticleReactionSummary {
        let articleID = try requestIdentifier(articleID)
        let url = try makeURL(pathComponents: ["articles", articleID, "reaction"])
        let method = reaction == nil ? "DELETE" : "PUT"
        var request = try await authorizedRequest(
            url: url,
            method: method,
            contentType: reaction == nil ? nil : "application/json",
            idempotencyKey: true,
            expectedAccountID: expectedAccountID
        )
        if let reaction {
            request.httpBody = try APIJSON.makeEncoder().encode(
                ArticleReactionInputDTO(type: reaction)
            )
        }
        let response = try await sendUncached(request, accepting: [200])
        let summary = try decode(
            ArticleReactionResponseDTO.self,
            from: response.data
        ).data.domain()
        guard summary.myReaction == reaction else {
            throw SportsDataError.contractViolation(field: "data.myReaction")
        }
        return summary
    }

    func createArticleComment(articleID: String, body: String) async throws -> ArticleComment {
        try await submitArticleComment(
            articleID: articleID,
            body: body,
            expectedAccountID: nil
        )
    }

    func createArticleComment(
        articleID: String,
        body: String,
        forAccountID accountID: String
    ) async throws -> ArticleComment {
        try await submitArticleComment(
            articleID: articleID,
            body: body,
            expectedAccountID: accountID
        )
    }

    private func submitArticleComment(
        articleID: String,
        body: String,
        expectedAccountID: String?
    ) async throws -> ArticleComment {
        let articleID = try requestIdentifier(articleID)
        let body = try normalizedCommunityText(body, maxLength: 500, required: true)
        let url = try makeURL(pathComponents: ["articles", articleID, "comments"])
        var request = try await authorizedRequest(
            url: url,
            method: "POST",
            contentType: "application/json",
            idempotencyKey: true,
            expectedAccountID: expectedAccountID
        )
        request.httpBody = try APIJSON.makeEncoder().encode(
            CreateArticleCommentInputDTO(body: body)
        )
        let response = try await sendUncached(
            request,
            accepting: [201],
            mapUnprocessableContentToRejection: true
        )
        let comment = try decode(
            ArticleCommentResponseDTO.self,
            from: response.data
        ).data.domain(
            field: "data",
            expectedArticleID: articleID,
            publishedOnly: false,
            now: now()
        )
        guard comment.isMine else {
            throw SportsDataError.contractViolation(field: "data.isMine")
        }
        guard comment.moderationState != .removed else {
            throw SportsDataError.contractViolation(field: "data.moderationState")
        }
        return comment
    }

    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?
    ) async throws -> CommunityReportReceipt {
        try await submitArticleCommentReport(
            commentID: commentID,
            reason: reason,
            details: details,
            expectedAccountID: nil
        )
    }

    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?,
        forAccountID accountID: String
    ) async throws -> CommunityReportReceipt {
        try await submitArticleCommentReport(
            commentID: commentID,
            reason: reason,
            details: details,
            expectedAccountID: accountID
        )
    }

    private func submitArticleCommentReport(
        commentID: String,
        reason: CommentReportReason,
        details: String?,
        expectedAccountID: String?
    ) async throws -> CommunityReportReceipt {
        let commentID = try requestIdentifier(commentID)
        let details = try details.flatMap {
            let normalized = try normalizedCommunityText($0, maxLength: 500, required: false)
            return normalized.isEmpty ? nil : normalized
        }
        let url = try makeURL(pathComponents: ["community", "comments", commentID, "reports"])
        var request = try await authorizedRequest(
            url: url,
            method: "POST",
            contentType: "application/json",
            idempotencyKey: true,
            expectedAccountID: expectedAccountID
        )
        request.httpBody = try APIJSON.makeEncoder().encode(
            CommentReportInputDTO(reason: reason, details: details)
        )
        let response = try await sendUncached(request, accepting: [202])
        return try decode(
            CommunityReportResponseDTO.self,
            from: response.data
        ).data.domain(now: now())
    }

    func blockCommunityAuthor(authorID: String) async throws {
        try await submitCommunityAuthorBlock(authorID: authorID, expectedAccountID: nil)
    }

    func blockCommunityAuthor(authorID: String, forAccountID accountID: String) async throws {
        try await submitCommunityAuthorBlock(authorID: authorID, expectedAccountID: accountID)
    }

    private func submitCommunityAuthorBlock(
        authorID: String,
        expectedAccountID: String?
    ) async throws {
        let authorID = try requestIdentifier(authorID)
        let url = try makeURL(pathComponents: ["me", "community-blocks", authorID])
        let request = try await authorizedRequest(
            url: url,
            method: "PUT",
            idempotencyKey: true,
            expectedAccountID: expectedAccountID
        )
        _ = try await sendUncached(request, accepting: [204])
    }

    func videoDiscovery() async throws -> VideoDiscoveryFeed {
        let url = try makeURL(pathComponents: ["videos", "discovery"])
        return try await load(
            VideoDiscoveryResponseDTO.self,
            from: url,
            staleIfError: Self.videoStaleIfError,
            resource: .videoDiscovery
        ) { try $0.domain() }
    }

    func videoPrograms(
        cursor: String?,
        limit: Int,
        sport: VideoSport?
    ) async throws -> VideoProgramPage {
        guard (1...VideoProgramPaginationContract.maximumPageSize).contains(limit) else {
            throw SportsDataError.invalidQuery
        }
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            guard let cursor = validatedCursor(cursor) else {
                throw SportsDataError.invalidQuery
            }
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let sport {
            queryItems.append(
                URLQueryItem(name: "sport", value: sport.rawValue.uppercased())
            )
        }
        let url = try makeURL(pathComponents: ["video-programs"], queryItems: queryItems)
        return try await load(
            VideoProgramListResponseDTO.self,
            from: url,
            staleIfError: Self.videoStaleIfError,
            resource: .videoPrograms(sport: sport)
        ) {
            let page = try $0.domain()
            guard page.programs.count <= limit else {
                throw SportsDataError.contractViolation(field: "data")
            }
            return page
        }
    }

    func videoProgramDetails(
        id: String,
        cursor: String?,
        limit: Int
    ) async throws -> VideoProgramDetailsPage {
        let id = try requestIdentifier(id)
        guard (1...VideoProgramPaginationContract.maximumPageSize).contains(limit) else {
            throw SportsDataError.invalidQuery
        }
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            guard let cursor = validatedCursor(cursor) else {
                throw SportsDataError.invalidQuery
            }
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let url = try makeURL(
            pathComponents: ["video-programs", id],
            queryItems: queryItems
        )
        return try await load(
            VideoProgramDetailResponseDTO.self,
            from: url,
            staleIfError: Self.videoStaleIfError,
            resource: .videoProgram(id: id)
        ) {
            let page = try $0.domain(expectedProgramID: id)
            guard page.episodes.count <= limit else {
                throw SportsDataError.contractViolation(field: "data.episodes")
            }
            return page
        }
    }

    func videos() async throws -> [SportsVideo] {
        var cursor: String?
        var seenCursors: Set<String> = []
        var seenVideoIDs: Set<String> = []
        var videos: [SportsVideo] = []

        while true {
            var queryItems = [
                URLQueryItem(name: "limit", value: String(Self.videoPageLimit))
            ]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            let url = try makeURL(pathComponents: ["videos"], queryItems: queryItems)
            let page = try await load(
                VideoListResponseDTO.self,
                from: url,
                staleIfError: Self.videoStaleIfError,
                resource: .videos
            ) {
                let page = try $0.domainPage()
                guard page.videos.count <= Self.videoPageLimit,
                      videos.count + page.videos.count <= Self.maximumVideoCount else {
                    throw SportsDataError.contractViolation(field: "data")
                }

                var validatedIDs = seenVideoIDs
                for video in page.videos {
                    guard validatedIDs.insert(video.id).inserted else {
                        throw SportsDataError.contractViolation(field: "data.id")
                    }
                }

                if page.hasMore {
                    guard !page.videos.isEmpty,
                          let nextCursor = page.nextCursor,
                          let nextValidatedCursor = validatedCursor(nextCursor),
                          !seenCursors.contains(nextValidatedCursor) else {
                        throw SportsDataError.contractViolation(field: "page.nextCursor")
                    }
                } else if page.nextCursor != nil {
                    throw SportsDataError.contractViolation(field: "page.nextCursor")
                }
                return page
            }

            videos.append(contentsOf: page.videos)
            seenVideoIDs.formUnion(page.videos.map(\.id))
            guard page.hasMore else {
                return videos
            }
            guard !page.videos.isEmpty,
                  let nextCursor = page.nextCursor,
                  let nextValidatedCursor = validatedCursor(nextCursor),
                  seenCursors.insert(nextValidatedCursor).inserted else {
                throw SportsDataError.contractViolation(field: "page.nextCursor")
            }
            cursor = nextValidatedCursor
        }
    }

    func videoDetails(id: String) async throws -> SportsVideoDetails {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { throw SportsDataError.notFound }
        let url = try makeURL(pathComponents: ["videos", id])
        return try await load(
            VideoDetailResponseDTO.self,
            from: url,
            staleIfError: 5 * 60,
            resource: .video(id: id)
        ) { try $0.data.domain(expectedVideoID: id) }
    }

    func continueWatching() async throws -> [ContinueWatchingItem] {
        let url = try makeURL(
            pathComponents: ["me", "watch-progress"],
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )
        let request = try await authorizedRequest(url: url, method: "GET")
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(ContinueWatchingResponseDTO.self, from: response.data)
        return try decoded.domain()
    }

    func watchHistory() async throws -> [WatchHistoryItem] {
        var cursor: String?
        var seenCursors: Set<String> = []
        var history: [WatchHistoryItem] = []

        while true {
            var queryItems = [URLQueryItem(name: "limit", value: "100")]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            let url = try makeURL(
                pathComponents: ["me", "watch-history"],
                queryItems: queryItems
            )
            let request = try await authorizedRequest(url: url, method: "GET")
            let response = try await sendUncached(request, accepting: [200])
            let decoded = try decode(WatchHistoryResponseDTO.self, from: response.data)
            let pageItems = try decoded.domain()

            if let last = history.last,
               let first = pageItems.first,
               last.progress.updatedAt < first.progress.updatedAt {
                throw SportsDataError.contractViolation(field: "data")
            }
            history.append(contentsOf: pageItems)
            guard Set(history.map(\.id)).count == history.count,
                  history.count <= 10_000 else {
                throw SportsDataError.contractViolation(field: "data")
            }

            guard decoded.page.hasMore else {
                guard decoded.page.nextCursor == nil else {
                    throw SportsDataError.contractViolation(field: "page.nextCursor")
                }
                return history
            }
            guard !pageItems.isEmpty,
                  let nextCursor = decoded.page.nextCursor,
                  let nextValidatedCursor = validatedCursor(nextCursor),
                  seenCursors.insert(nextValidatedCursor).inserted else {
                throw SportsDataError.contractViolation(field: "page.nextCursor")
            }
            cursor = nextValidatedCursor
        }
    }

    func clearWatchHistory() async throws {
        let url = try makeURL(pathComponents: ["me", "watch-history"])
        let request = try await authorizedRequest(
            url: url,
            method: "DELETE",
            idempotencyKey: true
        )
        _ = try await sendUncached(request, accepting: [204])
    }

    func removeWatchHistoryItem(videoID: String) async throws {
        let videoID = try requestIdentifier(videoID)
        let url = try makeURL(pathComponents: ["me", "watch-progress", videoID])
        let request = try await authorizedRequest(
            url: url,
            method: "DELETE",
            idempotencyKey: true
        )
        _ = try await sendUncached(request, accepting: [204])
    }

    func watchProgress(videoID: String) async throws -> WatchProgress? {
        let videoID = try requestIdentifier(videoID)
        let url = try makeURL(pathComponents: ["me", "watch-progress", videoID])
        let request = try await authorizedRequest(url: url, method: "GET")
        do {
            let response = try await sendUncached(request, accepting: [200])
            let decoded = try decode(WatchProgressResponseDTO.self, from: response.data)
            let progress = try decoded.data.domain(field: "data")
            guard progress.videoID == videoID else {
                throw SportsDataError.contractViolation(field: "data.videoId")
            }
            return progress
        } catch SportsDataError.notFound {
            return nil
        }
    }

    func saveWatchProgress(
        videoID: String,
        positionSeconds: Int,
        completed: Bool
    ) async throws -> WatchProgress {
        let videoID = try requestIdentifier(videoID)
        guard positionSeconds >= 0 else {
            throw SportsDataError.contractViolation(field: "positionSeconds")
        }
        let url = try makeURL(pathComponents: ["me", "watch-progress", videoID])
        var request = try await authorizedRequest(
            url: url,
            method: "PUT",
            contentType: "application/json",
            idempotencyKey: true
        )
        request.httpBody = try JSONEncoder().encode(WatchProgressInputDTO(
            positionSeconds: positionSeconds,
            completed: completed
        ))
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(WatchProgressResponseDTO.self, from: response.data)
        let progress = try decoded.data.domain(field: "data")
        guard progress.videoID == videoID else {
            throw SportsDataError.contractViolation(field: "data.videoId")
        }
        return progress
    }

    func favoriteVideos() async throws -> [SportsVideo] {
        let url = try makeURL(
            pathComponents: ["me", "video-favorites"],
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )
        let request = try await authorizedRequest(url: url, method: "GET")
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(VideoListResponseDTO.self, from: response.data)
        return try decoded.domain()
    }

    func videoFavorite(videoID: String) async throws -> VideoFavoriteState {
        let videoID = try requestIdentifier(videoID)
        let url = try makeURL(pathComponents: ["me", "video-favorites", videoID])
        let request = try await authorizedRequest(url: url, method: "GET")
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(VideoFavoriteResponseDTO.self, from: response.data)
        let state = try decoded.data.domain()
        guard state.videoID == videoID else {
            throw SportsDataError.contractViolation(field: "data.videoId")
        }
        return state
    }

    func setVideoFavorite(videoID: String, isFavorite: Bool) async throws -> VideoFavoriteState {
        let videoID = try requestIdentifier(videoID)
        let url = try makeURL(pathComponents: ["me", "video-favorites", videoID])
        if isFavorite {
            let request = try await authorizedRequest(
                url: url,
                method: "PUT",
                idempotencyKey: true
            )
            let response = try await sendUncached(request, accepting: [200])
            let decoded = try decode(VideoFavoriteResponseDTO.self, from: response.data)
            let state = try decoded.data.domain()
            guard state.videoID == videoID, state.isFavorite else {
                throw SportsDataError.contractViolation(field: "data.isFavorite")
            }
            return state
        }

        let request = try await authorizedRequest(url: url, method: "DELETE")
        _ = try await sendUncached(request, accepting: [204])
        return VideoFavoriteState(videoID: videoID, isFavorite: false, updatedAt: nil)
    }

    func follows() async throws -> [SportsFollow] {
        try await loadFollows(expectedAccountID: nil)
    }

    func follows(forAccountID accountID: String?) async throws -> [SportsFollow] {
        guard let accountID else { throw SportsDataError.unauthorized }
        return try await loadFollows(expectedAccountID: accountID)
    }

    private func loadFollows(expectedAccountID: String?) async throws -> [SportsFollow] {
        let url = try makeURL(pathComponents: ["me", "follows"])
        let request = try await authorizedRequest(
            url: url,
            method: "GET",
            expectedAccountID: expectedAccountID
        )
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(FollowListResponseDTO.self, from: response.data)
        return try decoded.domain(now: now())
    }

    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool
    ) async throws -> SportsFollow? {
        try await updateFollow(
            type: type,
            entityID: entityID,
            entity: entity,
            isFollowing: isFollowing,
            expectedAccountID: nil
        )
    }

    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool,
        forAccountID accountID: String?
    ) async throws -> SportsFollow? {
        guard let accountID else { throw SportsDataError.unauthorized }
        return try await updateFollow(
            type: type,
            entityID: entityID,
            entity: entity,
            isFollowing: isFollowing,
            expectedAccountID: accountID
        )
    }

    private func updateFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool,
        expectedAccountID: String?
    ) async throws -> SportsFollow? {
        let entityID = try requestIdentifier(entityID)
        guard entity == nil || (entity?.type == type && entity?.entityID == entityID) else {
            throw SportsDataError.contractViolation(field: "entity")
        }
        let listURL = try makeURL(pathComponents: ["me", "follows"])
        if isFollowing {
            var request = try await authorizedRequest(
                url: listURL,
                method: "POST",
                contentType: "application/json",
                idempotencyKey: true,
                expectedAccountID: expectedAccountID
            )
            request.httpBody = try APIJSON.makeEncoder().encode(
                CreateFollowInputDTO(type: type, entityId: entityID)
            )
            let response = try await sendUncached(request, accepting: [201])
            let decoded = try decode(FollowResponseDTO.self, from: response.data)
            let follow = try decoded.data.domain(field: "data", now: now())
            guard follow.type == type, follow.entityID == entityID else {
                throw SportsDataError.contractViolation(field: "data.entityId")
            }
            return follow
        }

        let currentFollows = try await loadFollows(expectedAccountID: expectedAccountID)
        guard let existing = currentFollows.first(where: {
            $0.type == type && $0.entityID == entityID
        }) else {
            return nil
        }
        let url = try makeURL(pathComponents: ["me", "follows", existing.id])
        let request = try await authorizedRequest(
            url: url,
            method: "DELETE",
            idempotencyKey: true,
            expectedAccountID: expectedAccountID
        )
        _ = try await sendUncached(request, accepting: [204])
        return nil
    }

    func notificationPreferences() async throws -> NotificationPreferences {
        let url = try makeURL(pathComponents: ["me", "notification-preferences"])
        let request = try await authorizedRequest(url: url, method: "GET")
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(
            NotificationPreferencesResponseDTO.self,
            from: response.data
        )
        return decoded.data.domain()
    }

    func setNotificationPreference(
        _ type: NotificationPreferenceType,
        enabled: Bool
    ) async throws -> NotificationPreferences {
        let url = try makeURL(pathComponents: ["me", "notification-preferences"])
        var request = try await authorizedRequest(
            url: url,
            method: "PATCH",
            contentType: "application/merge-patch+json",
            idempotencyKey: true
        )
        request.httpBody = try APIJSON.makeEncoder().encode(
            NotificationPreferencesPatchDTO(type: type, enabled: enabled)
        )
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(
            NotificationPreferencesResponseDTO.self,
            from: response.data
        )
        let preferences = decoded.data.domain()
        guard preferences[type] == enabled else {
            throw SportsDataError.contractViolation(field: "data.\(type.rawValue)")
        }
        return preferences
    }

    func registerNotificationDevice(_ registration: PushDeviceRegistration) async throws {
        let installationID = try requestIdentifier(registration.installationID)
        guard installationID == registration.installationID,
              (32...512).contains(registration.token.count),
              registration.token.count.isMultiple(of: 2),
              registration.token.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "0123456789abcdef").contains($0)
              }),
              (2...64).contains(registration.locale.count),
              registration.locale == registration.locale.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ),
              registration.locale.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
                      && !CharacterSet.whitespacesAndNewlines.contains($0)
              }),
              (1...64).contains(registration.timeZone.count),
              TimeZone(identifier: registration.timeZone) != nil else {
            throw SportsDataError.contractViolation(field: "notificationDevice")
        }
        let url = try makeURL(
            pathComponents: ["me", "notification-devices", installationID]
        )
        var request = try await authorizedRequest(
            url: url,
            method: "PUT",
            contentType: "application/json",
            idempotencyKey: true
        )
        request.httpBody = try APIJSON.makeEncoder().encode(
            PushDeviceRegistrationInputDTO(
                token: registration.token,
                environment: registration.environment,
                locale: registration.locale,
                timeZone: registration.timeZone
            )
        )
        _ = try await sendUncached(request, accepting: [204])
    }

    func predictionGames() async throws -> [PredictionGame] {
        let url = try makeURL(pathComponents: ["prediction-games"])
        return try await load(
            PredictionGameListResponseDTO.self,
            from: url,
            staleIfError: 15 * 60,
            resource: .predictionGames
        ) { try $0.domain() }
    }

    func predictionEntry(for game: PredictionGame) async throws -> PredictionEntry? {
        try await loadPredictionEntry(for: game, expectedAccountID: nil)
    }

    func predictionEntry(
        for game: PredictionGame,
        forAccountID accountID: String
    ) async throws -> PredictionEntry? {
        try await loadPredictionEntry(for: game, expectedAccountID: accountID)
    }

    private func loadPredictionEntry(
        for game: PredictionGame,
        expectedAccountID: String?
    ) async throws -> PredictionEntry? {
        let gameID = try requestIdentifier(game.id)
        let url = try makeURL(
            pathComponents: ["prediction-games", gameID, "entries", "me"]
        )
        let request = try await authorizedRequest(
            url: url,
            method: "GET",
            expectedAccountID: expectedAccountID
        )
        let response = try await sendUncached(request, accepting: [200, 404])
        guard response.statusCode == 200 else { return nil }
        let decoded = try decode(PredictionEntryResponseDTO.self, from: response.data)
        return try decoded.data.domain(for: game)
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking]
    ) async throws -> PredictionEntry {
        try await storePredictionEntry(
            for: game,
            rankings: rankings,
            expectedAccountID: nil
        )
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking],
        forAccountID accountID: String
    ) async throws -> PredictionEntry {
        try await storePredictionEntry(
            for: game,
            rankings: rankings,
            expectedAccountID: accountID
        )
    }

    private func storePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking],
        expectedAccountID: String?
    ) async throws -> PredictionEntry {
        let gameID = try requestIdentifier(game.id)
        guard game.isEditable(at: now()) else {
            throw SportsDataError.forbidden
        }
        try PredictionEntryContract.validate(rankings, for: game)
        let url = try makeURL(
            pathComponents: ["prediction-games", gameID, "entries", "me"]
        )
        var request = try await authorizedRequest(
            url: url,
            method: "PUT",
            contentType: "application/json",
            idempotencyKey: true,
            expectedAccountID: expectedAccountID
        )
        request.httpBody = try APIJSON.makeEncoder().encode(
            PredictionEntryInputDTO(rankings: rankings)
        )
        let response = try await sendUncached(request, accepting: [200])
        let decoded = try decode(PredictionEntryResponseDTO.self, from: response.data)
        let entry = try decoded.data.domain(for: game)
        guard entry.rankings == rankings else {
            throw SportsDataError.contractViolation(field: "data.rankings")
        }
        return entry
    }

    func createPlaybackSession(
        videoID: String,
        deviceID: String,
        capabilities: PlaybackCapabilities
    ) async throws -> PlaybackSession {
        let videoID = try requestIdentifier(videoID)
        let deviceID = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (16...128).contains(deviceID.count) else {
            throw SportsDataError.invalidConfiguration
        }

        let url = try makeURL(pathComponents: ["videos", videoID, "playback-session"])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        let authorization = try await authorizationHeader(required: false)
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(CreatePlaybackSessionInputDTO(
            deviceID: deviceID,
            supportsFairPlay: capabilities.supportsFairPlay
        ))

        let response = try await sendUncached(request, accepting: [201])
        let decoded = try decode(PlaybackSessionResponseDTO.self, from: response.data)
        return try decoded.data.domain(
            videoID: videoID,
            now: now(),
            capabilities: capabilities
        )
    }

    func search(query: String) async throws -> [SearchResultItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard GlobalSearchContract.validQueryLength.contains(query.count) else {
            if query.count < GlobalSearchContract.minimumQueryLength { return [] }
            throw SportsDataError.invalidQuery
        }
        let url = try makeURL(
            pathComponents: ["search"],
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(
                    name: "limit",
                    value: String(GlobalSearchContract.maximumResultCount)
                )
            ]
        )
        return try await load(
            SearchResponseDTO.self,
            from: url,
            staleIfError: nil
        ) { try $0.domain() }
    }

    private func load<Response: Decodable, Domain: Sendable>(
        _ responseType: Response.Type,
        from url: URL,
        staleIfError: TimeInterval?,
        resource: PublicContentResource? = nil,
        transform: (Response) throws -> Domain
    ) async throws -> Domain {
        do {
            let (domain, freshness) = try await loadValidated(
                responseType,
                from: url,
                staleIfError: staleIfError,
                transform: transform
            )
            if let resource {
                await freshnessReporter.record(freshness, for: resource)
            }
            return domain
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            if let resource {
                await freshnessReporter.record(.refreshFailed(at: now()), for: resource)
            }
            if error is DecodingError {
                throw SportsDataError.decoding
            }
            throw error
        }
    }

    private func loadValidated<Response: Decodable, Domain: Sendable>(
        _ responseType: Response.Type,
        from url: URL,
        staleIfError: TimeInterval?,
        transform: (Response) throws -> Domain
    ) async throws -> (domain: Domain, freshness: PublicContentFreshness) {
        let source = try await fetch(url: url, staleIfError: staleIfError)
        let decoded = try APIJSON.makeDecoder().decode(responseType, from: source.data)
        let domain = try transform(decoded)
        if source.shouldStore {
            let storedAt = source.freshness.contentStoredAt ?? now()
            let payload = CachedPayload(
                data: source.data,
                storedAt: storedAt,
                etag: source.etag
            )
            try? await cache.store(payload, for: url.absoluteString)
        }
        return (domain, source.freshness)
    }

    private func aggregateBatchFreshness(
        _ values: [PublicContentFreshness]
    ) -> PublicContentFreshness {
        let storedAt = values.compactMap(\.contentStoredAt).min() ?? now()
        let checkedAt = values.compactMap(\.checkedAt).max() ?? now()
        if values.contains(where: { $0.source == .offlineSnapshot }) {
            return .offlineSnapshot(storedAt: storedAt, checkedAt: checkedAt)
        }
        if values.contains(where: { $0.source == .revalidated }) {
            return .revalidated(storedAt: storedAt, checkedAt: checkedAt)
        }
        return .network(at: checkedAt)
    }

    private func fetch(url: URL, staleIfError: TimeInterval?) async throws -> PayloadSource {
        let cacheKey = url.absoluteString
        let cached = await cache.payload(for: cacheKey)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let etag = cached?.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let response = try await client.send(request)
            switch response.statusCode {
            case 200..<300:
                let receivedAt = now()
                return PayloadSource(
                    data: response.data,
                    etag: response.header(named: "ETag"),
                    shouldStore: true,
                    freshness: .network(at: receivedAt)
                )
            case 304:
                guard let cached else {
                    throw SportsDataError.invalidResponse(statusCode: 304)
                }
                return PayloadSource(
                    data: cached.data,
                    etag: cached.etag,
                    shouldStore: false,
                    freshness: .revalidated(storedAt: cached.storedAt, checkedAt: now())
                )
            case 401:
                throw SportsDataError.unauthorized
            case 403:
                throw SportsDataError.forbidden
            case 404:
                throw SportsDataError.notFound
            case 410:
                throw SportsDataError.contentWithdrawn
            case 429:
                throw SportsDataError.rateLimited
            case 500...599:
                throw SportsDataError.serverUnavailable
            default:
                throw SportsDataError.invalidResponse(statusCode: response.statusCode)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            let dataError = SportsDataError.normalized(error)
            if dataError.isRecoverableForFallback,
               let staleIfError,
               let cached,
               now().timeIntervalSince(cached.storedAt) <= staleIfError {
                return PayloadSource(
                    data: cached.data,
                    etag: cached.etag,
                    shouldStore: false,
                    freshness: .offlineSnapshot(storedAt: cached.storedAt, checkedAt: now())
                )
            }
            throw dataError
        }
    }

    private func authorizedRequest(
        url: URL,
        method: String,
        contentType: String? = nil,
        idempotencyKey: Bool = false,
        expectedAccountID: String? = nil
    ) async throws -> URLRequest {
        guard let authorization = try await authorizationHeader(
            required: true,
            expectedAccountID: expectedAccountID
        ) else {
            throw SportsDataError.unauthorized
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if idempotencyKey {
            request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        }
        return request
    }

    private func communityReadRequest(
        url: URL,
        expectedAccountID: String?
    ) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        let optionalAuthorization = try await authorizationHeader(
            required: expectedAccountID != nil,
            expectedAccountID: expectedAccountID
        )
        if let authorization = optionalAuthorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func authorizationHeader(
        required: Bool,
        expectedAccountID: String? = nil
    ) async throws -> String? {
        let token: String?
        if let expectedAccountID {
            token = await accessTokenProvider.accessToken(forAccountID: expectedAccountID)
        } else {
            token = await accessTokenProvider.accessToken()
        }
        guard let token else {
            if required { throw SportsDataError.unauthorized }
            return nil
        }
        guard (1...4096).contains(token.count),
              token.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              token.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw SportsDataError.invalidConfiguration
        }
        return "Bearer \(token)"
    }

    private func sendUncached(
        _ request: URLRequest,
        accepting successStatusCodes: Set<Int>,
        mapUnprocessableContentToRejection: Bool = false
    ) async throws -> HTTPResponse {
        let response: HTTPResponse
        do {
            response = try await client.send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw SportsDataError.normalized(error)
        }

        if successStatusCodes.contains(response.statusCode) {
            return response
        }
        switch response.statusCode {
        case 401:
            throw SportsDataError.unauthorized
        case 403:
            throw SportsDataError.forbidden
        case 404:
            throw SportsDataError.notFound
        case 410:
            throw SportsDataError.contentWithdrawn
        case 422 where mapUnprocessableContentToRejection:
            throw SportsDataError.contentRejected
        case 422:
            throw SportsDataError.invalidResponse(statusCode: response.statusCode)
        case 429:
            throw SportsDataError.rateLimited
        case 500...599:
            throw SportsDataError.serverUnavailable
        default:
            throw SportsDataError.invalidResponse(statusCode: response.statusCode)
        }
    }

    private func decode<Response: Decodable>(
        _ responseType: Response.Type,
        from data: Data
    ) throws -> Response {
        do {
            return try APIJSON.makeDecoder().decode(responseType, from: data)
        } catch let error as SportsDataError {
            throw error
        } catch {
            throw SportsDataError.decoding
        }
    }

    private func makeURL(
        pathComponents: [String],
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        var url = baseURL
        for component in pathComponents {
            url.appendPathComponent(component)
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SportsDataError.invalidConfiguration
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let finalURL = components.url else {
            throw SportsDataError.invalidConfiguration
        }
        return finalURL
    }

    private func requestIdentifier(_ value: String) throws -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\?#")
        guard !value.isEmpty,
              value.unicodeScalars.count <= 128,
              value.rangeOfCharacter(from: forbidden) == nil,
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw SportsDataError.notFound
        }
        return value
    }

    private func normalizedCommunityText(
        _ value: String,
        maxLength: Int,
        required: Bool
    ) throws -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowedControls = CharacterSet(charactersIn: "\n\t")
        guard (!required || !value.isEmpty),
              value.count <= maxLength,
              value.unicodeScalars.allSatisfy({ scalar in
                  !CharacterSet.controlCharacters.contains(scalar)
                      || allowedControls.contains(scalar)
              }) else {
            throw SportsDataError.invalidQuery
        }
        return value
    }

    private func requestTeamSnapshotIDs(_ values: [String]) throws -> [String] {
        guard (1...TeamMatchSnapshotRequestLimits.maximumTeamsPerDashboard)
            .contains(values.count) else {
            throw SportsDataError.invalidQuery
        }
        let normalized: [String]
        do {
            normalized = try values.map(requestIdentifier)
        } catch {
            throw SportsDataError.invalidQuery
        }
        guard Set(normalized).count == normalized.count else {
            throw SportsDataError.invalidQuery
        }
        return normalized
    }

    private func fixtureIdentifier(_ value: String) throws -> String {
        do {
            return try requestIdentifier(value)
        } catch SportsDataError.notFound {
            throw SportsDataError.fixtureNotFound
        }
    }

    private func validatedCursor(_ value: String) -> String? {
        guard (1...2_048).contains(value.count),
              value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        return value
    }

    private struct PayloadSource: Sendable {
        let data: Data
        let etag: String?
        let shouldStore: Bool
        let freshness: PublicContentFreshness
    }
}
