import Foundation

actor MockSportsDataProvider: SportsDataProviding,
    IdentityScopedFollowProviding,
    IdentityScopedPredictionProviding {
    private var favoriteDatesByArticleID: [String: Date] = [:]
    private var reactionByArticleID: [String: ArticleReaction] = [:]
    private var blockedCommunityAuthorIDs: Set<String> = []
    private var reportedCommunityCommentIDs: Set<String> = []
    private var submittedCommentSequence = 0
    private var progressByVideoID: [String: WatchProgress] = [:]
    private var favoriteDatesByVideoID: [String: Date] = [:]
    private var followsByTargetKey: [String: SportsFollow] = [:]
    private var nextFollowMutationError: SportsDataError?
    private var notificationPreferencesState = NotificationPreferences.allEnabled
    private var notificationDevicesByInstallationID: [String: PushDeviceRegistration] = [:]
    private var predictionEntriesByGameID: [String: PredictionEntry] = [:]
    private var predictionEntriesByAccountID: [String: [String: PredictionEntry]] = [:]
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = Date.init) {
        self.now = now
    }

    func teams() async throws -> [Team] {
        MockSportsData.teams
    }

    func players() async throws -> [PlayerProfile] {
        MockSportsData.players
    }

    func competitions() async throws -> [Competition] {
        MockSportsData.competitions
    }

    func teamDetails(id: String) async throws -> TeamDetails {
        guard let team = MockSportsData.teams.first(where: { $0.id == id }) else {
            throw SportsDataError.notFound
        }
        let related = MockSportsData.fixtureCatalog().filter {
            $0.homeTeam.id == id || $0.awayTeam.id == id
        }
        let nextFixtures = related
            .filter { $0.state == .upcoming }
            .sorted {
                $0.kickoff == $1.kickoff ? $0.id < $1.id : $0.kickoff < $1.kickoff
            }
        let recentFixtures = related
            .filter { $0.state == .finished }
            .sorted {
                $0.kickoff == $1.kickoff ? $0.id < $1.id : $0.kickoff > $1.kickoff
            }
        return TeamDetails(
            team: team,
            competitions: MockSportsData.competitions.filter { competition in
                related.contains { $0.competition.id == competition.id }
            },
            nextFixtures: Array(nextFixtures.prefix(10)),
            recentFixtures: Array(recentFixtures.prefix(10))
        )
    }

    func teamMatchSnapshots(ids: [String]) async throws -> [TeamMatchSnapshot] {
        guard (1...TeamMatchSnapshotRequestLimits.maximumTeamsPerDashboard)
            .contains(ids.count) else {
            throw SportsDataError.invalidQuery
        }
        let forbidden = CharacterSet(charactersIn: "/\\?#")
        let normalizedIDs = ids.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard Set(normalizedIDs).count == normalizedIDs.count,
              normalizedIDs.allSatisfy({ id in
                  !id.isEmpty
                      && id.count <= 128
                      && id.rangeOfCharacter(from: forbidden) == nil
                      && id.unicodeScalars.allSatisfy({
                          !CharacterSet.controlCharacters.contains($0)
                      })
              }) else {
            throw SportsDataError.invalidQuery
        }

        let fixtures = MockSportsData.fixtureCatalog()
        return try normalizedIDs.map { id in
            guard let team = MockSportsData.teams.first(where: { $0.id == id }) else {
                throw SportsDataError.notFound
            }
            let related = fixtures.filter {
                $0.homeTeam.id == id || $0.awayTeam.id == id
            }
            let previous = related
                .filter { $0.state == .finished }
                .sorted {
                    $0.kickoff == $1.kickoff ? $0.id < $1.id : $0.kickoff > $1.kickoff
                }
                .first
            let next = related
                .filter { $0.state == .upcoming }
                .sorted {
                    $0.kickoff == $1.kickoff ? $0.id < $1.id : $0.kickoff < $1.kickoff
                }
                .first
            return TeamMatchSnapshot(
                team: team,
                previousFixture: previous,
                nextFixture: next
            )
        }
    }

    func teamContent(id: String) async throws -> TeamContent {
        guard MockSportsData.teams.contains(where: { $0.id == id }) else {
            throw SportsDataError.notFound
        }
        guard id == MockSportsData.teams[0].id else {
            return TeamContent(teamID: id, articles: [], videos: [])
        }
        return TeamContent(
            teamID: id,
            articles: Array(MockSportsData.articles().prefix(1)),
            videos: MockSportsData.videos.filter {
                ["video-highlight-1", "video-interview-1"].contains($0.id)
            }
        )
    }

    func teamSquad(id: String, seasonID: String) async throws -> [PlayerProfile] {
        guard MockSportsData.teams.contains(where: { $0.id == id }),
              seasonID == MockSportsData.season.id else {
            throw SportsDataError.notFound
        }
        return MockSportsData.players
    }

    func playerDetails(id: String) async throws -> PlayerDetails {
        guard let player = MockSportsData.players.first(where: { $0.id == id }) else {
            throw SportsDataError.notFound
        }
        return PlayerDetails(
            player: player,
            currentTeam: MockSportsData.teams[0],
            statistics: [
                NamedStatistic(name: "Appearances", value: 24),
                NamedStatistic(name: "Goals", value: player.position == "Forward" ? 14 : 3),
                NamedStatistic(name: "Assists", value: 6)
            ]
        )
    }

    func playerContent(id: String) async throws -> PlayerContent {
        guard MockSportsData.players.contains(where: { $0.id == id }) else {
            throw SportsDataError.notFound
        }
        guard id == MockSportsData.players[0].id else {
            return PlayerContent(playerID: id, articles: [], videos: [])
        }
        return PlayerContent(
            playerID: id,
            articles: Array(MockSportsData.articles().dropFirst().prefix(1)),
            videos: MockSportsData.videos.filter { $0.id == "video-interview-1" }
        )
    }

    func playerTransfers(id: String) async throws -> [PlayerTransfer] {
        guard MockSportsData.players.contains(where: { $0.id == id }) else {
            throw SportsDataError.notFound
        }
        return MockSportsData.transferCatalog(now: now()).filter { $0.player.id == id }
    }

    func transferUpdates(
        cursor: String?,
        limit: Int,
        status: TransferStatus?
    ) async throws -> TransferPage {
        guard (1...TransferPaginationContract.maximumPageSize).contains(limit) else {
            throw SportsDataError.invalidQuery
        }
        let visible = MockSportsData.transferCatalog(now: now()).filter {
            status == nil || $0.status == status
        }
        let start: Int
        if let cursor {
            let prefix = "offset-"
            guard cursor.hasPrefix(prefix),
                  let offset = Int(cursor.dropFirst(prefix.count)),
                  offset > 0,
                  offset < visible.count else {
                throw SportsDataError.invalidQuery
            }
            start = offset
        } else {
            start = 0
        }
        let end = min(start + limit, visible.count)
        let hasMore = end < visible.count
        return TransferPage(
            transfers: Array(visible[start..<end]),
            nextCursor: hasMore ? "offset-\(end)" : nil,
            hasMore: hasMore
        )
    }

    func seasonCalendar() async throws -> SeasonCalendarSnapshot {
        MockSportsData.seasonCalendar(now: now())
    }

    func competitionStandings(id: String, seasonID: String) async throws -> [StandingGroup] {
        guard let competition = MockSportsData.competitions.first(where: { $0.id == id }),
              competition.seasons.contains(where: { $0.id == seasonID }) else {
            throw SportsDataError.notFound
        }
        return MockSportsData.standings(for: seasonID)
    }

    func competitionContent(id: String) async throws -> CompetitionContent {
        guard MockSportsData.competitions.contains(where: { $0.id == id }) else {
            throw SportsDataError.notFound
        }
        guard id == MockSportsData.competitions[0].id else {
            return CompetitionContent(competitionID: id, articles: [], videos: [])
        }
        return CompetitionContent(
            competitionID: id,
            articles: Array(MockSportsData.articles().prefix(2)),
            videos: MockSportsData.videos.filter {
                ["video-original-1", "video-highlight-1"].contains($0.id)
            }
        )
    }

    func competitionLeaders(
        id: String,
        seasonID: String,
        category: CompetitionLeaderCategory
    ) async throws -> [CompetitionLeader] {
        guard let competition = MockSportsData.competitions.first(where: { $0.id == id }),
              competition.seasons.contains(where: { $0.id == seasonID }) else {
            throw SportsDataError.notFound
        }
        return MockSportsData.leaders(category: category, seasonID: seasonID)
    }

    func competitionFixtures(id: String, seasonID: String) async throws -> [Fixture] {
        guard let competition = MockSportsData.competitions.first(where: { $0.id == id }),
              competition.seasons.contains(where: { $0.id == seasonID }) else {
            throw SportsDataError.notFound
        }
        return MockSportsData.fixtures(forCompetitionID: id, seasonID: seasonID)
            .filter { $0.competition.id == id }
            .sorted {
                $0.kickoff == $1.kickoff ? $0.id < $1.id : $0.kickoff < $1.kickoff
            }
    }

    func homeFeed() async throws -> HomeFeed {
        HomeFeed(
            fixtures: MockSportsData.fixtures(),
            articles: MockSportsData.articles()
        )
    }

    func fixtures(on date: Date) async throws -> [Fixture] {
        guard Calendar.current.isDateInToday(date) else { return [] }
        return MockSportsData.fixtures()
    }

    func fixtureDetails(id: String) async throws -> MatchDetails {
        guard let fixture = MockSportsData.allFixtureCatalog().first(where: { $0.id == id }) else {
            throw SportsDataError.fixtureNotFound
        }
        let hasStarted = [.live, .halfTime, .finished].contains(fixture.state)
        let isArchived = MockSportsData.isHistoricalFixture(id: id)

        return MatchDetails(
            fixture: fixture,
            events: hasStarted && !isArchived ? MockSportsData.events : [],
            homeLineup: MockSportsData.homeLineup,
            awayLineup: MockSportsData.awayLineup,
            statistics: hasStarted ? MockSportsData.statistics : [],
            sourceName: "SportsHub Demo Data",
            updatedAt: Date()
        )
    }

    func fixtureContent(id: String) async throws -> FixtureContent {
        guard MockSportsData.allFixtureCatalog().contains(where: { $0.id == id }) else {
            throw SportsDataError.fixtureNotFound
        }
        guard ["fixture-live-1", "fixture-finished-1"].contains(id) else {
            return FixtureContent(fixtureID: id, moments: [], articles: [])
        }
        guard let highlight = MockSportsData.videos.first(where: {
            $0.id == "video-highlight-1"
        }), let replay = MockSportsData.videos.first(where: {
            $0.id == "video-replay-1"
        }) else {
            throw SportsDataError.contractViolation(field: "fixtureContent.videos")
        }
        return FixtureContent(
            fixtureID: id,
            moments: [
                FixtureContentMoment(
                    id: "moment-opening-goal",
                    titleArabic: "هدف التقدم التجريبي",
                    titleEnglish: "Demo opening goal",
                    minute: 27,
                    video: highlight
                ),
                FixtureContentMoment(
                    id: "moment-tactical-turn",
                    titleArabic: "التحول التكتيكي التجريبي",
                    titleEnglish: "Demo tactical turning point",
                    minute: 52,
                    video: replay
                )
            ],
            articles: Array(MockSportsData.articles().prefix(1))
        )
    }

    func fixtureStandings(for fixture: Fixture) async throws -> FixtureStandingsContext {
        let canonical = try canonicalFixture(matching: fixture)
        guard MockSportsData.competitions.contains(where: {
            $0.id == canonical.competition.id
        }) else {
            throw SportsDataError.fixtureNotFound
        }
        let season = MockSportsData.season(forFixtureID: canonical.id)
        return FixtureStandingsContext(
            fixtureID: canonical.id,
            competition: canonical.competition,
            season: season,
            groups: MockSportsData.standings(for: season.id),
            sourceName: "SportsHub Demo Data",
            updatedAt: Date()
        )
    }

    func fixtureHeadToHead(
        for fixture: Fixture,
        limit: Int
    ) async throws -> FixtureHeadToHeadContext {
        guard (1...20).contains(limit) else {
            throw SportsDataError.contractViolation(field: "limit")
        }
        let canonical = try canonicalFixture(matching: fixture)
        let meetings = Array(
            MockSportsData.headToHeadMeetings(
                homeTeam: canonical.homeTeam,
                awayTeam: canonical.awayTeam,
                before: canonical.kickoff
            ).prefix(limit)
        )
        return FixtureHeadToHeadContext(
            fixtureID: canonical.id,
            homeTeam: canonical.homeTeam,
            awayTeam: canonical.awayTeam,
            meetings: meetings,
            sourceName: "SportsHub Demo Data",
            updatedAt: Date()
        )
    }

    private func canonicalFixture(matching fixture: Fixture) throws -> Fixture {
        guard let canonical = MockSportsData.allFixtureCatalog().first(where: { $0.id == fixture.id }),
              canonical.competition.id == fixture.competition.id,
              canonical.homeTeam.id == fixture.homeTeam.id,
              canonical.awayTeam.id == fixture.awayTeam.id else {
            throw SportsDataError.fixtureNotFound
        }
        return canonical
    }

    func fixtureEventUpdates(
        id: String,
        afterRevision: Int
    ) async throws -> FixtureEventBatch {
        guard afterRevision >= 0 else {
            throw SportsDataError.contractViolation(field: "afterRevision")
        }
        guard let snapshotFixture = MockSportsData.allFixtureCatalog().first(where: { $0.id == id }) else {
            throw SportsDataError.fixtureNotFound
        }

        let allEvents: [FixtureEvent]
        let fixture: Fixture
        switch snapshotFixture.state {
        case .live, .halfTime:
            allEvents = MockSportsData.events + [MockSportsData.liveIncrement]
            fixture = MockSportsData.copy(
                snapshotFixture,
                revision: 6,
                minute: 64
            )
        case .upcoming:
            allEvents = []
            fixture = snapshotFixture
        case .finished, .postponed, .cancelled:
            allEvents = MockSportsData.isHistoricalFixture(id: id) ? [] : MockSportsData.events
            fixture = snapshotFixture
        }

        guard afterRevision <= fixture.revision else {
            throw SportsDataError.contractViolation(field: "afterRevision")
        }
        return FixtureEventBatch(
            fixture: fixture,
            fixtureRevision: fixture.revision,
            mutations: allEvents
                .filter { $0.revision > afterRevision }
                .map(FixtureEventMutation.upsert),
            updatedAt: Date()
        )
    }

    func articles() async throws -> [Article] {
        MockSportsData.articles()
    }

    func articleDetails(id: String) async throws -> ArticleDetails {
        guard let article = MockSportsData.articles().first(where: { $0.id == id }),
              let body = MockSportsData.articleBodies[id] else {
            throw SportsDataError.notFound
        }
        return ArticleDetails(
            article: article,
            bodyArabic: body.arabic,
            bodyEnglish: body.english,
            revision: article.isCorrected ? 2 : 1,
            visualBrief: MockSportsData.articleVisualBriefs[id]
        )
    }

    func favoriteArticles() async throws -> [Article] {
        favoriteDatesByArticleID
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .compactMap { favorite in
                MockSportsData.articles().first { $0.id == favorite.key }
            }
    }

    func articleFavorite(articleID: String) async throws -> ArticleFavoriteState {
        guard MockSportsData.articles().contains(where: { $0.id == articleID }) else {
            throw SportsDataError.notFound
        }
        let updatedAt = favoriteDatesByArticleID[articleID]
        return ArticleFavoriteState(
            articleID: articleID,
            isFavorite: updatedAt != nil,
            updatedAt: updatedAt
        )
    }

    func setArticleFavorite(
        articleID: String,
        isFavorite: Bool
    ) async throws -> ArticleFavoriteState {
        guard MockSportsData.articles().contains(where: { $0.id == articleID }) else {
            throw SportsDataError.notFound
        }
        if isFavorite {
            favoriteDatesByArticleID[articleID] = favoriteDatesByArticleID[articleID] ?? Date()
        } else {
            favoriteDatesByArticleID[articleID] = nil
        }
        return try await articleFavorite(articleID: articleID)
    }

    func articleComments(
        articleID: String,
        cursor: String?,
        limit: Int
    ) async throws -> ArticleCommentPage {
        guard MockSportsData.articles().contains(where: { $0.id == articleID }) else {
            throw SportsDataError.notFound
        }
        guard (1...20).contains(limit) else {
            throw SportsDataError.invalidQuery
        }
        let start: Int
        if let cursor {
            guard cursor.hasPrefix("offset-"),
                  let value = Int(cursor.dropFirst("offset-".count)),
                  value >= 0 else {
                throw SportsDataError.invalidQuery
            }
            start = value
        } else {
            start = 0
        }
        let visible = communityCommentCatalog(articleID: articleID)
            .filter { !blockedCommunityAuthorIDs.contains($0.authorID) }
        guard start <= visible.count else {
            throw SportsDataError.invalidQuery
        }
        let end = min(start + limit, visible.count)
        let comments = Array(visible[start..<end])
        let hasMore = end < visible.count
        return ArticleCommentPage(
            comments: comments,
            nextCursor: hasMore ? "offset-\(end)" : nil,
            hasMore: hasMore
        )
    }

    func articleReaction(articleID: String) async throws -> ArticleReactionSummary {
        guard MockSportsData.articles().contains(where: { $0.id == articleID }) else {
            throw SportsDataError.notFound
        }
        var totals: [ArticleReaction: Int] = [
            .like: articleID == "article-1" ? 128 : 24,
            .insightful: articleID == "article-1" ? 41 : 9,
            .celebrate: articleID == "article-1" ? 33 : 5
        ]
        if let selected = reactionByArticleID[articleID] {
            totals[selected, default: 0] += 1
        }
        return ArticleReactionSummary(
            myReaction: reactionByArticleID[articleID],
            totals: totals
        )
    }

    func setArticleReaction(
        articleID: String,
        reaction: ArticleReaction?
    ) async throws -> ArticleReactionSummary {
        guard MockSportsData.articles().contains(where: { $0.id == articleID }) else {
            throw SportsDataError.notFound
        }
        reactionByArticleID[articleID] = reaction
        return try await articleReaction(articleID: articleID)
    }

    func createArticleComment(articleID: String, body: String) async throws -> ArticleComment {
        guard MockSportsData.articles().contains(where: { $0.id == articleID }) else {
            throw SportsDataError.notFound
        }
        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowedControls = CharacterSet(charactersIn: "\n\t")
        guard (1...500).contains(body.count),
              body.unicodeScalars.allSatisfy({ scalar in
                  !CharacterSet.controlCharacters.contains(scalar)
                      || allowedControls.contains(scalar)
              }) else {
            throw SportsDataError.invalidQuery
        }
        submittedCommentSequence += 1
        return ArticleComment(
            id: "comment-submitted-\(submittedCommentSequence)",
            articleID: articleID,
            body: body,
            authorID: "demo-current-author",
            authorDisplayName: "SportsHub Guest",
            moderationState: .pending,
            isMine: true,
            createdAt: now()
        )
    }

    func reportArticleComment(
        commentID: String,
        reason: CommentReportReason,
        details: String?
    ) async throws -> CommunityReportReceipt {
        let allComments = MockSportsData.articles().flatMap {
            communityCommentCatalog(articleID: $0.id)
        }
        guard allComments.contains(where: { $0.id == commentID }),
              !reportedCommunityCommentIDs.contains(commentID),
              details?.count ?? 0 <= 500 else {
            throw SportsDataError.invalidQuery
        }
        reportedCommunityCommentIDs.insert(commentID)
        return CommunityReportReceipt(
            reportID: "report-\(commentID)",
            submittedAt: now()
        )
    }

    func blockCommunityAuthor(authorID: String) async throws {
        let allComments = MockSportsData.articles().flatMap {
            communityCommentCatalog(articleID: $0.id)
        }
        guard let comment = allComments.first(where: { $0.authorID == authorID }) else {
            throw SportsDataError.notFound
        }
        guard !comment.isMine else {
            throw SportsDataError.invalidQuery
        }
        blockedCommunityAuthorIDs.insert(authorID)
    }

    func videoDiscovery() async throws -> VideoDiscoveryFeed {
        MockSportsData.videoDiscovery
    }

    func videoPrograms(
        cursor: String?,
        limit: Int,
        sport: VideoSport?
    ) async throws -> VideoProgramPage {
        guard (1...VideoProgramPaginationContract.maximumPageSize).contains(limit) else {
            throw SportsDataError.invalidQuery
        }
        let programs = MockSportsData.videoPrograms.filter {
            sport == nil || $0.sport == sport
        }
        let prefix = "mock-programs-\(sport?.rawValue ?? "all")"
        let page = try mockPage(
            programs,
            cursor: cursor,
            limit: limit,
            prefix: prefix
        )
        return VideoProgramPage(
            programs: page.items,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }

    func videoProgramDetails(
        id: String,
        cursor: String?,
        limit: Int
    ) async throws -> VideoProgramDetailsPage {
        guard (1...VideoProgramPaginationContract.maximumPageSize).contains(limit) else {
            throw SportsDataError.invalidQuery
        }
        guard let details = MockSportsData.videoProgramDetails(
            id: id,
            publishedAt: now().addingTimeInterval(-3 * 60 * 60)
        ) else {
            throw SportsDataError.notFound
        }
        let page = try mockPage(
            details.episodes,
            cursor: cursor,
            limit: limit,
            prefix: "mock-program-\(id)"
        )
        return VideoProgramDetailsPage(
            program: details.program,
            episodes: page.items,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }

    private func mockPage<Item>(
        _ items: [Item],
        cursor: String?,
        limit: Int,
        prefix: String
    ) throws -> (items: [Item], nextCursor: String?, hasMore: Bool) {
        let offset: Int
        if let cursor {
            let marker = "\(prefix)-offset-"
            guard cursor.hasPrefix(marker),
                  let parsedOffset = Int(cursor.dropFirst(marker.count)),
                  parsedOffset > 0,
                  parsedOffset < items.count else {
                throw SportsDataError.invalidQuery
            }
            offset = parsedOffset
        } else {
            offset = 0
        }
        let end = min(offset + limit, items.count)
        let pageItems = Array(items[offset..<end])
        let hasMore = end < items.count
        return (
            items: pageItems,
            nextCursor: hasMore ? "\(prefix)-offset-\(end)" : nil,
            hasMore: hasMore
        )
    }

    private func communityCommentCatalog(articleID: String) -> [ArticleComment] {
        guard articleID == "article-1" else { return [] }
        return [
            ArticleComment(
                id: "comment-demo-1",
                articleID: articleID,
                body: "تحليل هادئ. نقطة التحول كانت في الضغط بعد الاستراحة.",
                authorID: "author-noura",
                authorDisplayName: "نورة",
                moderationState: .published,
                isMine: false,
                createdAt: now().addingTimeInterval(-18 * 60)
            ),
            ArticleComment(
                id: "comment-demo-2",
                articleID: articleID,
                body: "The shape change explains why the final twenty minutes felt different.",
                authorID: "author-sami",
                authorDisplayName: "Sami",
                moderationState: .published,
                isMine: false,
                createdAt: now().addingTimeInterval(-46 * 60)
            ),
            ArticleComment(
                id: "comment-demo-3",
                articleID: articleID,
                body: "بانتظار أرقام الاستحواذ والفرص في التقرير القادم.",
                authorID: "author-fahad",
                authorDisplayName: "فهد",
                moderationState: .published,
                isMine: false,
                createdAt: now().addingTimeInterval(-72 * 60)
            )
        ]
    }

    func videos() async throws -> [SportsVideo] {
        MockSportsData.videos
    }

    func videoDetails(id: String) async throws -> SportsVideoDetails {
        guard let details = MockSportsData.videoDetails(
            id: id,
            publishedAt: Date().addingTimeInterval(-3 * 60 * 60)
        ) else {
            throw SportsDataError.notFound
        }
        return details
    }

    func continueWatching() async throws -> [ContinueWatchingItem] {
        progressByVideoID.values
            .filter { !$0.completed && $0.positionSeconds > 0 }
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { progress in
                guard let video = MockSportsData.videos.first(where: { $0.id == progress.videoID }),
                      video.type != .live else {
                    return nil
                }
                return ContinueWatchingItem(video: video, progress: progress)
            }
    }

    func watchHistory() async throws -> [WatchHistoryItem] {
        progressByVideoID.values
            .filter { $0.positionSeconds > 0 }
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { progress in
                guard let video = MockSportsData.videos.first(where: {
                    $0.id == progress.videoID
                }), video.type != .live else {
                    return nil
                }
                return WatchHistoryItem(video: video, progress: progress)
            }
    }

    func removeWatchHistoryItem(videoID: String) async throws {
        guard MockSportsData.videos.contains(where: { $0.id == videoID }) else {
            throw SportsDataError.notFound
        }
        progressByVideoID[videoID] = nil
    }

    func clearWatchHistory() async throws {
        progressByVideoID.removeAll()
    }

    func watchProgress(videoID: String) async throws -> WatchProgress? {
        guard MockSportsData.videos.contains(where: { $0.id == videoID }) else {
            throw SportsDataError.notFound
        }
        return progressByVideoID[videoID]
    }

    func saveWatchProgress(
        videoID: String,
        positionSeconds: Int,
        completed: Bool
    ) async throws -> WatchProgress {
        guard let video = MockSportsData.videos.first(where: { $0.id == videoID }) else {
            throw SportsDataError.notFound
        }
        guard positionSeconds >= 0 else {
            throw SportsDataError.contractViolation(field: "positionSeconds")
        }
        let progress = WatchProgress(
            videoID: videoID,
            positionSeconds: min(positionSeconds, video.durationSeconds),
            completed: completed,
            updatedAt: Date()
        )
        progressByVideoID[videoID] = progress
        return progress
    }

    func favoriteVideos() async throws -> [SportsVideo] {
        favoriteDatesByVideoID
            .sorted { $0.value > $1.value }
            .compactMap { favorite in
                MockSportsData.videos.first { $0.id == favorite.key }
            }
    }

    func videoFavorite(videoID: String) async throws -> VideoFavoriteState {
        guard MockSportsData.videos.contains(where: { $0.id == videoID }) else {
            throw SportsDataError.notFound
        }
        let updatedAt = favoriteDatesByVideoID[videoID]
        return VideoFavoriteState(
            videoID: videoID,
            isFavorite: updatedAt != nil,
            updatedAt: updatedAt
        )
    }

    func setVideoFavorite(videoID: String, isFavorite: Bool) async throws -> VideoFavoriteState {
        guard MockSportsData.videos.contains(where: { $0.id == videoID }) else {
            throw SportsDataError.notFound
        }
        if isFavorite {
            favoriteDatesByVideoID[videoID] = favoriteDatesByVideoID[videoID] ?? Date()
        } else {
            favoriteDatesByVideoID[videoID] = nil
        }
        return try await videoFavorite(videoID: videoID)
    }

    func follows() async throws -> [SportsFollow] {
        followsByTargetKey.values.canonicalFollowOrder
    }

    func follows(forAccountID _: String?) async throws -> [SportsFollow] {
        try await follows()
    }

    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool
    ) async throws -> SportsFollow? {
        if let nextFollowMutationError {
            self.nextFollowMutationError = nil
            throw nextFollowMutationError
        }
        let entityID = entityID.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\?#")
        guard !entityID.isEmpty,
              entityID.count <= 128,
              entityID.rangeOfCharacter(from: forbidden) == nil,
              entityID.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw SportsDataError.notFound
        }
        guard entity == nil || (entity?.type == type && entity?.entityID == entityID) else {
            throw SportsDataError.contractViolation(field: "entity")
        }
        let key = "\(type.rawValue):\(entityID)"
        if !isFollowing {
            followsByTargetKey[key] = nil
            return nil
        }
        let existing = followsByTargetKey[key]
        guard existing != nil || followsByTargetKey.count < 500 else {
            throw SportsDataError.contractViolation(field: "follows")
        }
        let follow = SportsFollow(
            id: existing?.id ?? "mock:\(key)",
            type: type,
            entityID: entityID,
            createdAt: existing?.createdAt ?? Date(),
            entity: entity ?? existing?.entity
        )
        followsByTargetKey[key] = follow
        return follow
    }

    func setFollow(
        type: FollowEntityType,
        entityID: String,
        entity: FollowEntitySnapshot?,
        isFollowing: Bool,
        forAccountID _: String?
    ) async throws -> SportsFollow? {
        try await setFollow(
            type: type,
            entityID: entityID,
            entity: entity,
            isFollowing: isFollowing
        )
    }

    func failNextFollowMutation(with error: SportsDataError) {
        nextFollowMutationError = error
    }

    func notificationPreferences() async throws -> NotificationPreferences {
        notificationPreferencesState
    }

    func setNotificationPreference(
        _ type: NotificationPreferenceType,
        enabled: Bool
    ) async throws -> NotificationPreferences {
        notificationPreferencesState = notificationPreferencesState.setting(
            type,
            enabled: enabled
        )
        return notificationPreferencesState
    }

    func registerNotificationDevice(_ registration: PushDeviceRegistration) async throws {
        notificationDevicesByInstallationID[registration.installationID] = registration
    }

    func predictionGames() async throws -> [PredictionGame] {
        MockSportsData.predictionGames
    }

    func predictionEntry(for game: PredictionGame) async throws -> PredictionEntry? {
        guard MockSportsData.predictionGames.contains(game) else {
            throw SportsDataError.notFound
        }
        return predictionEntriesByGameID[game.id]
    }

    func predictionEntry(
        for game: PredictionGame,
        forAccountID accountID: String
    ) async throws -> PredictionEntry? {
        guard MockSportsData.predictionGames.contains(game) else {
            throw SportsDataError.notFound
        }
        return predictionEntriesByAccountID[accountID]?[game.id]
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking]
    ) async throws -> PredictionEntry {
        guard MockSportsData.predictionGames.contains(game) else {
            throw SportsDataError.notFound
        }
        guard game.isEditable(at: now()) else {
            throw SportsDataError.forbidden
        }
        try PredictionEntryContract.validate(rankings, for: game)
        let entry = PredictionEntry(
            gameID: game.id,
            rankings: rankings,
            updatedAt: now()
        )
        predictionEntriesByGameID[game.id] = entry
        return entry
    }

    func savePredictionEntry(
        for game: PredictionGame,
        rankings: [PredictionGroupRanking],
        forAccountID accountID: String
    ) async throws -> PredictionEntry {
        guard MockSportsData.predictionGames.contains(game) else {
            throw SportsDataError.notFound
        }
        guard game.isEditable(at: now()) else {
            throw SportsDataError.forbidden
        }
        try PredictionEntryContract.validate(rankings, for: game)
        let entry = PredictionEntry(
            gameID: game.id,
            rankings: rankings,
            updatedAt: now()
        )
        predictionEntriesByAccountID[accountID, default: [:]][game.id] = entry
        return entry
    }

    func registeredNotificationDevice(
        installationID: String
    ) -> PushDeviceRegistration? {
        notificationDevicesByInstallationID[installationID]
    }

    func createPlaybackSession(
        videoID: String,
        deviceID: String,
        capabilities: PlaybackCapabilities
    ) async throws -> PlaybackSession {
        guard MockSportsData.videos.contains(where: { $0.id == videoID }) else {
            throw SportsDataError.notFound
        }
        throw SportsDataError.forbidden
    }

    func search(query: String) async throws -> [SearchResultItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= GlobalSearchContract.minimumQueryLength else { return [] }
        guard GlobalSearchContract.validQueryLength.contains(query.count) else {
            throw SportsDataError.invalidQuery
        }
        return Array(
            MockSportsData.search(query: query)
                .prefix(GlobalSearchContract.maximumResultCount)
        )
    }
}

enum MockSportsData {
    static let teams: [Team] = [
        Team(
            id: "riyadh-falcons",
            nameArabic: "صقور الرياض",
            nameEnglish: "Riyadh Falcons",
            monogram: "RF",
            colorHex: "0AA9C0"
        ),
        Team(
            id: "jeddah-waves",
            nameArabic: "أمواج جدة",
            nameEnglish: "Jeddah Waves",
            monogram: "JW",
            colorHex: "F2AB33"
        ),
        Team(
            id: "dammam-harbor",
            nameArabic: "ميناء الدمام",
            nameEnglish: "Dammam Harbor",
            monogram: "DH",
            colorHex: "4E65D6"
        ),
        Team(
            id: "capital-stars",
            nameArabic: "نجوم العاصمة",
            nameEnglish: "Capital Stars",
            monogram: "CS",
            colorHex: "9B59B6"
        )
    ]

    static let season = Season(
        id: "demo-season-2026-27",
        nameArabic: "موسم 2026–27",
        nameEnglish: "2026–27 season",
        startDate: Date(timeIntervalSince1970: 1_785_542_400),
        endDate: Date(timeIntervalSince1970: 1_811_721_600),
        isCurrent: true
    )

    static let historicalSeason = Season(
        id: "demo-season-2025-26",
        nameArabic: "موسم 2025–26",
        nameEnglish: "2025–26 season",
        startDate: Date(timeIntervalSince1970: 1_754_006_400),
        endDate: Date(timeIntervalSince1970: 1_780_185_600),
        isCurrent: false
    )

    static let competition = Competition(
        id: "demo-premier-league",
        nameArabic: "الدوري التجريبي الممتاز",
        nameEnglish: "Demo Premier League",
        currentSeasonID: season.id,
        seasons: [season, historicalSeason]
    )

    static let cup = Competition(
        id: "demo-cup",
        nameArabic: "كأس التجربة",
        nameEnglish: "Demo Cup",
        currentSeasonID: season.id,
        seasons: [season, historicalSeason]
    )

    static let competitions = [competition, cup]

    static let predictionGames: [PredictionGame] = [
        PredictionGame(
            id: "demo-global-cup-groups",
            titleArabic: "تحدي ترتيب مجموعات الكأس التجريبي",
            titleEnglish: "Demo Cup group-order challenge",
            summaryArabic: "رتّب الفرق كما تتوقع أن تنهي المجموعة قبل موعد الإغلاق.",
            summaryEnglish: "Rank the teams in your predicted finishing order before entries lock.",
            lockAt: Date(timeIntervalSince1970: 1_893_456_000),
            state: .open,
            rulesURL: nil,
            groups: [
                PredictionGroup(
                    id: "demo-group-a",
                    nameArabic: "المجموعة أ",
                    nameEnglish: "Group A",
                    teams: teams,
                    qualifyingPositions: 2
                )
            ]
        ),
        PredictionGame(
            id: "demo-past-groups",
            titleArabic: "تحدي المجموعات السابق",
            titleEnglish: "Previous group challenge",
            summaryArabic: "تحدٍ تجريبي مكتمل للعرض فقط.",
            summaryEnglish: "A completed fictional challenge shown for demonstration.",
            lockAt: Date(timeIntervalSince1970: 1_735_689_600),
            state: .settled,
            rulesURL: nil,
            groups: [
                PredictionGroup(
                    id: "demo-past-group-a",
                    nameArabic: "المجموعة أ",
                    nameEnglish: "Group A",
                    teams: teams,
                    qualifyingPositions: 2
                )
            ]
        )
    ]

    static let players: [PlayerProfile] = [
        PlayerProfile(id: "player-omar", name: "Omar Fahad", position: "Midfielder"),
        PlayerProfile(id: "player-salem", name: "Salem Nasser", position: "Defender"),
        PlayerProfile(id: "player-tariq", name: "Tariq Saad", position: "Forward"),
        PlayerProfile(id: "player-khalid", name: "Khalid Amin", position: "Goalkeeper")
    ]

    static func transferCatalog(now: Date) -> [PlayerTransfer] {
        [
            PlayerTransfer(
                id: "transfer-player-tariq",
                player: players[2],
                fromTeam: teams[2],
                toTeam: teams[0],
                transferDate: now.addingTimeInterval(-24 * 60 * 60),
                status: .completed
            ),
            PlayerTransfer(
                id: "transfer-player-omar",
                player: players[0],
                fromTeam: teams[0],
                toTeam: teams[1],
                transferDate: now.addingTimeInterval(-2 * 24 * 60 * 60),
                status: .agreed
            ),
            PlayerTransfer(
                id: "transfer-player-salem",
                player: players[1],
                fromTeam: teams[3],
                toTeam: teams[2],
                transferDate: now.addingTimeInterval(-3 * 24 * 60 * 60),
                status: .rumored
            ),
            PlayerTransfer(
                id: "transfer-player-khalid",
                player: players[3],
                fromTeam: nil,
                toTeam: teams[3],
                transferDate: now.addingTimeInterval(-4 * 24 * 60 * 60),
                status: .completed
            )
        ]
    }

    static func seasonCalendar(now: Date) -> SeasonCalendarSnapshot {
        let day: TimeInterval = 24 * 60 * 60
        return SeasonCalendarSnapshot(
            rangeStart: now.addingTimeInterval(-60 * day),
            rangeEnd: now.addingTimeInterval(300 * day),
            updatedAt: now,
            sourceName: "SportsHub Demo Calendar",
            events: [
                SeasonCalendarEvent(
                    id: "calendar-season-kickoff",
                    titleArabic: "انطلاق الموسم التجريبي",
                    titleEnglish: "Demo season kickoff",
                    detailArabic: "بداية نافذة الموسم في البيانات التجريبية.",
                    detailEnglish: "The fictional season window begins.",
                    startsAt: now.addingTimeInterval(-30 * day),
                    endsAt: nil,
                    kind: .competitionMilestone,
                    competition: competition
                ),
                SeasonCalendarEvent(
                    id: "calendar-cup-draw",
                    titleArabic: "قرعة الكأس التجريبية",
                    titleEnglish: "Demo cup draw",
                    detailArabic: "موعد تجريبي للقرعة، وليس حدثاً حقيقياً.",
                    detailEnglish: "A fictional draw date, not a real event.",
                    startsAt: now.addingTimeInterval(10 * day),
                    endsAt: nil,
                    kind: .draw,
                    competition: cup
                ),
                SeasonCalendarEvent(
                    id: "calendar-transfer-window",
                    titleArabic: "نافذة الانتقالات التجريبية",
                    titleEnglish: "Demo transfer window",
                    detailArabic: "فترة تجريبية توضح عرض الأحداث الممتدة.",
                    detailEnglish: "A fictional range demonstrating multi-day events.",
                    startsAt: now.addingTimeInterval(20 * day),
                    endsAt: now.addingTimeInterval(50 * day),
                    kind: .transferWindow,
                    competition: nil
                ),
                SeasonCalendarEvent(
                    id: "calendar-international-break",
                    titleArabic: "فترة دولية تجريبية",
                    titleEnglish: "Demo international break",
                    detailArabic: nil,
                    detailEnglish: nil,
                    startsAt: now.addingTimeInterval(80 * day),
                    endsAt: now.addingTimeInterval(90 * day),
                    kind: .internationalBreak,
                    competition: nil
                )
            ]
        )
    }

    static let standings: [StandingGroup] = [
        StandingGroup(
            groupNameArabic: "الترتيب العام",
            groupNameEnglish: "Overall",
            rows: [
                StandingRow(rank: 1, team: teams[0], played: 24, won: 17, drawn: 4, lost: 3, goalsFor: 48, goalsAgainst: 20, points: 55, form: [.win, .win, .draw, .win, .loss]),
                StandingRow(rank: 2, team: teams[1], played: 24, won: 15, drawn: 5, lost: 4, goalsFor: 41, goalsAgainst: 24, points: 50, form: [.win, .draw, .win, .win, .win]),
                StandingRow(rank: 3, team: teams[2], played: 24, won: 11, drawn: 7, lost: 6, goalsFor: 34, goalsAgainst: 29, points: 40, form: [.loss, .win, .draw, .draw, .win]),
                StandingRow(rank: 4, team: teams[3], played: 24, won: 8, drawn: 6, lost: 10, goalsFor: 30, goalsAgainst: 35, points: 30, form: [.draw, .loss, .win, .loss, .draw])
            ]
        )
    ]

    static let historicalStandings: [StandingGroup] = [
        StandingGroup(
            groupNameArabic: "الترتيب النهائي",
            groupNameEnglish: "Final table",
            rows: [
                StandingRow(rank: 1, team: teams[1], played: 30, won: 21, drawn: 6, lost: 3, goalsFor: 61, goalsAgainst: 24, points: 69, form: [.win, .win, .win, .draw, .win]),
                StandingRow(rank: 2, team: teams[0], played: 30, won: 20, drawn: 5, lost: 5, goalsFor: 58, goalsAgainst: 27, points: 65, form: [.win, .loss, .win, .win, .draw]),
                StandingRow(rank: 3, team: teams[3], played: 30, won: 14, drawn: 8, lost: 8, goalsFor: 45, goalsAgainst: 36, points: 50, form: [.draw, .win, .loss, .win, .win]),
                StandingRow(rank: 4, team: teams[2], played: 30, won: 10, drawn: 7, lost: 13, goalsFor: 37, goalsAgainst: 44, points: 37, form: [.loss, .draw, .win, .loss, .draw])
            ]
        )
    ]

    static func standings(for seasonID: String) -> [StandingGroup] {
        seasonID == historicalSeason.id ? historicalStandings : standings
    }

    static func leaders(
        category: CompetitionLeaderCategory,
        seasonID: String = season.id
    ) -> [CompetitionLeader] {
        let values: [Double]
        switch category {
        case .goals: values = seasonID == historicalSeason.id ? [19, 16] : [14, 11]
        case .assists: values = seasonID == historicalSeason.id ? [12, 10] : [9, 7]
        case .yellowCards: values = seasonID == historicalSeason.id ? [8, 7] : [6, 5]
        case .redCards: values = seasonID == historicalSeason.id ? [2, 1] : [1, 1]
        }
        let leaderPlayers = seasonID == historicalSeason.id
            ? [players[0], players[2]]
            : [players[2], players[0]]
        return [
            CompetitionLeader(rank: 1, player: leaderPlayers[0], team: teams[0], value: values[0]),
            CompetitionLeader(rank: 2, player: leaderPlayers[1], team: teams[0], value: values[1])
        ]
    }

    static func fixtures(now: Date = Date()) -> [Fixture] {
        [
            Fixture(
                id: "fixture-live-1",
                competition: competition,
                homeTeam: teams[0],
                awayTeam: teams[1],
                kickoff: now.addingTimeInterval(-62 * 60),
                state: .live,
                minute: 62,
                homeScore: 1,
                awayScore: 0,
                venueArabic: "ملعب المدينة",
                venueEnglish: "City Arena",
                broadcasts: demoBroadcasts,
                revision: 5
            ),
            Fixture(
                id: "fixture-upcoming-1",
                competition: competition,
                homeTeam: teams[2],
                awayTeam: teams[3],
                kickoff: now.addingTimeInterval(2 * 60 * 60),
                state: .upcoming,
                minute: nil,
                homeScore: nil,
                awayScore: nil,
                venueArabic: "ملعب الساحل",
                venueEnglish: "Coast Stadium",
                broadcasts: [demoBroadcasts[0]],
                revision: 0
            ),
            Fixture(
                id: "fixture-finished-1",
                competition: competition,
                homeTeam: teams[3],
                awayTeam: teams[0],
                kickoff: now.addingTimeInterval(-5 * 60 * 60),
                state: .finished,
                minute: 90,
                homeScore: 2,
                awayScore: 2,
                venueArabic: "ملعب العاصمة",
                venueEnglish: "Capital Ground",
                revision: 5
            ),
            Fixture(
                id: "fixture-cup-upcoming-1",
                competition: cup,
                homeTeam: teams[1],
                awayTeam: teams[2],
                kickoff: now.addingTimeInterval(4 * 60 * 60),
                state: .upcoming,
                minute: nil,
                homeScore: nil,
                awayScore: nil,
                venueArabic: "ملعب الكأس التجريبي",
                venueEnglish: "Demo Cup Stadium",
                revision: 0
            )
        ]
    }

    static let demoBroadcasts = [
        FixtureBroadcast(
            regionCode: "SA",
            channelArabic: "قناة الملعب التجريبية",
            channelEnglish: "Demo Stadium Channel",
            commentatorArabic: "المعلق التجريبي سامر",
            commentatorEnglish: "Demo commentator Samir",
            audioLanguageCode: "ar"
        ),
        FixtureBroadcast(
            regionCode: "SA",
            channelArabic: "الرياضة العالمية التجريبية",
            channelEnglish: "Demo World Sports",
            commentatorArabic: "تعليق إنجليزي تجريبي",
            commentatorEnglish: "Demo English commentary",
            audioLanguageCode: "en-GB"
        )
    ]

    /// A full season fixture reachable from the team channel but intentionally
    /// outside the mock "today" feed, so the channel can demonstrate both a
    /// previous and a next match without changing today's discovery fixtures.
    static func teamChannelFixture(now: Date = Date()) -> Fixture {
        Fixture(
            id: "fixture-team-next-1",
            competition: competition,
            homeTeam: teams[0],
            awayTeam: teams[2],
            kickoff: now.addingTimeInterval(26 * 60 * 60),
            state: .upcoming,
            minute: nil,
            homeScore: nil,
            awayScore: nil,
            venueArabic: "ملعب المدينة",
            venueEnglish: "City Arena",
            revision: 0
        )
    }

    static func fixtureCatalog(now: Date = Date()) -> [Fixture] {
        fixtures(now: now) + [teamChannelFixture(now: now)]
    }

    static let historicalFixtures: [Fixture] = [
        Fixture(
            id: "fixture-history-season-2025-26-final",
            competition: competition,
            homeTeam: teams[1],
            awayTeam: teams[0],
            kickoff: Date(timeIntervalSince1970: 1_779_559_200),
            state: .finished,
            minute: 90,
            homeScore: 2,
            awayScore: 1,
            venueArabic: "ملعب الساحل",
            venueEnglish: "Coast Stadium",
            revision: 1
        )
    ]

    static func fixtures(forCompetitionID id: String, seasonID: String) -> [Fixture] {
        let catalog = seasonID == historicalSeason.id
            ? historicalFixtures
            : fixtureCatalog()
        return catalog.filter { $0.competition.id == id }
    }

    static func allFixtureCatalog(now: Date = Date()) -> [Fixture] {
        fixtureCatalog(now: now) + historicalFixtures
    }

    static func isHistoricalFixture(id: String) -> Bool {
        historicalFixtures.contains(where: { $0.id == id })
    }

    static func season(forFixtureID id: String) -> Season {
        isHistoricalFixture(id: id) ? historicalSeason : season
    }

    static func headToHeadMeetings(
        homeTeam: Team,
        awayTeam: Team,
        before kickoff: Date
    ) -> [Fixture] {
        return [
            Fixture(
                id: "h2h-\(homeTeam.id)-\(awayTeam.id)-3",
                competition: cup,
                homeTeam: awayTeam,
                awayTeam: homeTeam,
                kickoff: kickoff.addingTimeInterval(-31 * 24 * 60 * 60),
                state: .finished,
                minute: 90,
                homeScore: 1,
                awayScore: 2,
                venueArabic: "ملعب الكأس التجريبي",
                venueEnglish: "Demo Cup Stadium",
                revision: 1
            ),
            Fixture(
                id: "h2h-\(homeTeam.id)-\(awayTeam.id)-2",
                competition: competition,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                kickoff: kickoff.addingTimeInterval(-96 * 24 * 60 * 60),
                state: .finished,
                minute: 90,
                homeScore: 1,
                awayScore: 1,
                venueArabic: "ملعب المدينة",
                venueEnglish: "City Arena",
                revision: 1
            ),
            Fixture(
                id: "h2h-\(homeTeam.id)-\(awayTeam.id)-1",
                competition: competition,
                homeTeam: awayTeam,
                awayTeam: homeTeam,
                kickoff: kickoff.addingTimeInterval(-181 * 24 * 60 * 60),
                state: .finished,
                minute: 90,
                homeScore: 3,
                awayScore: 1,
                venueArabic: "ملعب الساحل",
                venueEnglish: "Coast Stadium",
                revision: 1
            )
        ]
    }

    static func articles(now: Date = Date()) -> [Article] {
        [
            Article(
                id: "article-1",
                titleArabic: "صقور الرياض يستعدون لمواجهة جديدة بعد أسبوع قوي",
                titleEnglish: "Riyadh Falcons prepare for a new test after a strong week",
                summaryArabic: "تقرير تجريبي يوضح شكل بطاقة الخبر من دون استخدام محتوى أو صور محمية.",
                summaryEnglish: "A fictional report demonstrating the news card without protected text or imagery.",
                source: "SportsHub Demo Desk",
                publishedAt: now.addingTimeInterval(-42 * 60),
                categoryKey: "category.analysis",
                isCorrected: false,
                engagement: ArticleEngagementSummary(
                    totalReactions: 202,
                    publishedComments: 3
                ),
                heroMedia: nil
            ),
            Article(
                id: "article-2",
                titleArabic: "خمسة أرقام قبل مباريات الليلة",
                titleEnglish: "Five numbers to know before tonight's matches",
                summaryArabic: "بيانات محلية مؤقتة لاختبار القراءة والمشاركة والحفظ.",
                summaryEnglish: "Local placeholder data for testing reading, sharing, and saving.",
                source: "SportsHub Demo Desk",
                publishedAt: now.addingTimeInterval(-95 * 60),
                categoryKey: "category.statistics",
                format: .visualBrief,
                isCorrected: true,
                engagement: ArticleEngagementSummary(
                    totalReactions: 38,
                    publishedComments: 0
                ),
                heroMedia: nil
            )
        ]
    }

    static let articleBodies: [String: (arabic: String, english: String)] = [
        "article-1": (
            arabic: "يدخل صقور الرياض المباراة بخطة متوازنة بعد أسبوع تدريبي ركّز على التحولات السريعة. هذا محتوى تجريبي مكتوب خصيصاً لاختبار القراءة واتجاه النص، ولا ينقل خبراً حقيقياً.",
            english: "Riyadh Falcons enter the match with a balanced plan after a training week focused on quick transitions. This fictional copy exists only to test reading and layout; it is not a real report."
        ),
        "article-2": (
            arabic: "تعرض هذه المادة خمسة مؤشرات تجريبية في موجز بصري منظم. تم تحديث النص لتوضيح أن جميع الأرقام مصطنعة ولا تصف مباراة حقيقية.",
            english: "This demo story presents five fictional indicators in a structured visual brief. It was corrected to make clear that every number is synthetic and does not describe a real match."
        )
    ]

    static let articleVisualBriefs: [String: ArticleVisualBrief] = [
        "article-2": ArticleVisualBrief(
            titleArabic: "خمس إشارات في نظرة واحدة",
            titleEnglish: "Five signals at a glance",
            sourceNoteArabic: "بيانات توضيحية مصطنعة — وليست من مباراة حقيقية.",
            sourceNoteEnglish: "Fictional demonstration data — not a real match.",
            sections: [
                ArticleVisualSection(
                    id: "match-pulse",
                    kind: .metricGrid,
                    titleArabic: "نبض المباراة",
                    titleEnglish: "Match pulse",
                    items: [
                        ArticleVisualItem(
                            id: "metric-shots",
                            valueArabic: "١٤",
                            valueEnglish: "14",
                            labelArabic: "تسديدة",
                            labelEnglish: "Shots",
                            detailArabic: "ثمانٍ منها من داخل المنطقة",
                            detailEnglish: "Eight from inside the box"
                        ),
                        ArticleVisualItem(
                            id: "metric-possession",
                            valueArabic: "٥٨٪",
                            valueEnglish: "58%",
                            labelArabic: "استحواذ",
                            labelEnglish: "Possession",
                            detailArabic: "حصة صقور الرياض التجريبية",
                            detailEnglish: "Fictional Riyadh Falcons share"
                        ),
                        ArticleVisualItem(
                            id: "metric-recoveries",
                            valueArabic: "٣١",
                            valueEnglish: "31",
                            labelArabic: "استرجاعاً للكرة",
                            labelEnglish: "Ball recoveries",
                            detailArabic: "إحدى عشرة في الثلث الأوسط",
                            detailEnglish: "Eleven in the middle third"
                        )
                    ]
                ),
                ArticleVisualSection(
                    id: "set-piece-comparison",
                    kind: .comparison,
                    titleArabic: "مقارنة الكرات الثابتة",
                    titleEnglish: "Set-piece comparison",
                    items: [
                        ArticleVisualItem(
                            id: "comparison-falcons",
                            valueArabic: "٦",
                            valueEnglish: "6",
                            labelArabic: "صقور الرياض",
                            labelEnglish: "Riyadh Falcons",
                            detailArabic: "ركنيات وضربات حرة هجومية",
                            detailEnglish: "Corners and attacking free kicks"
                        ),
                        ArticleVisualItem(
                            id: "comparison-waves",
                            valueArabic: "٤",
                            valueEnglish: "4",
                            labelArabic: "أمواج جدة",
                            labelEnglish: "Jeddah Waves",
                            detailArabic: "ركنيات وضربات حرة هجومية",
                            detailEnglish: "Corners and attacking free kicks"
                        )
                    ]
                )
            ]
        )
    ]

    static let videos: [SportsVideo] = [
        SportsVideo(
            id: "video-live-1",
            type: .live,
            titleArabic: "استوديو المباراة المباشر — نموذج تجريبي",
            titleEnglish: "Live match studio — demo listing",
            descriptionArabic: "بيانات وصفية خيالية فقط؛ لا تتضمن بثاً أو لقطات محمية.",
            descriptionEnglish: "Fictional metadata only; no protected stream or footage is included.",
            durationSeconds: 0,
            isPlayable: false,
            availabilityReason: .notStarted
        ),
        SportsVideo(
            id: "video-highlight-1",
            type: .highlight,
            titleArabic: "ملخص تجريبي لمباراة صقور الرياض",
            titleEnglish: "Demo highlights: Riyadh Falcons",
            descriptionArabic: "بطاقة فيديو خيالية لا تتضمن أي لقطات أو بث محمي.",
            descriptionEnglish: "A fictional video card containing no protected footage or stream. This longer demo synopsis exists only to verify the user-controlled Show more and Show less layout at large text sizes. It describes no real match, league, athlete, score, broadcast, or licensed event.",
            durationSeconds: 312,
            isPlayable: false,
            availabilityReason: .entitlementRequired
        ),
        SportsVideo(
            id: "video-replay-1",
            type: .replay,
            titleArabic: "إعادة تجريبية للمباراة الكاملة",
            titleEnglish: "Demo full-match replay",
            descriptionArabic: "نموذج بيانات لإعادة مباراة قبل إضافة محتوى مرخص.",
            descriptionEnglish: "Replay metadata for testing before licensed media is added.",
            durationSeconds: 5_580,
            isPlayable: false,
            availabilityReason: .regionBlocked
        ),
        SportsVideo(
            id: "video-original-1",
            type: .original,
            titleArabic: "الاستوديو التكتيكي — الحلقة التجريبية",
            titleEnglish: "Tactics Studio — demo episode",
            descriptionArabic: "نموذج لبرنامج أصلي قبل إضافة أصول مرخصة.",
            descriptionEnglish: "A model for an original show before licensed assets are added.",
            durationSeconds: 1_428,
            isPlayable: false,
            availabilityReason: .notStarted
        ),
        SportsVideo(
            id: "video-interview-1",
            type: .interview,
            titleArabic: "مقابلة ما بعد المباراة — نموذج تجريبي",
            titleEnglish: "Post-match interview — demo listing",
            descriptionArabic: "بطاقة مقابلة خيالية بلا صوت أو صورة محمية.",
            descriptionEnglish: "A fictional interview card with no protected audio or video.",
            durationSeconds: 684,
            isPlayable: false,
            availabilityReason: .entitlementRequired
        ),
        SportsVideo(
            id: "video-basketball-1",
            type: .highlight,
            titleArabic: "قراءة تجريبية لأبرز لقطات السلة",
            titleEnglish: "Demo basketball highlights breakdown",
            descriptionArabic: "بطاقة تجريبية مصطنعة لا تتضمن لقطات دوري أو فريق حقيقي.",
            descriptionEnglish: "Fictional metadata with no footage from a real league or team.",
            durationSeconds: 248,
            isPlayable: false,
            availabilityReason: .regionBlocked
        ),
        SportsVideo(
            id: "video-esports-1",
            type: .original,
            titleArabic: "مختبر الرياضات الإلكترونية — حلقة تجريبية",
            titleEnglish: "Esports Lab — demo episode",
            descriptionArabic: "برنامج تجريبي مصطنع من دون بث أو علامات تجارية محمية.",
            descriptionEnglish: "A fictional demo show with no protected stream or branding.",
            durationSeconds: 906,
            isPlayable: false,
            availabilityReason: .notStarted
        )
    ]

    private struct VideoEditorialContext {
        let program: VideoProgram
        let relatedVideoIDs: [String]
    }

    private static let demoPublisherArabic = "منصة سبورتس هب التجريبية"
    private static let demoPublisherEnglish = "SportsHub Demo Desk"

    private static let videoEditorialContexts: [String: VideoEditorialContext] = [
        "video-live-1": VideoEditorialContext(
            program: VideoProgram(
                id: "program-match-desk",
                titleArabic: "استوديو المباراة",
                titleEnglish: "Match Desk"
            ),
            relatedVideoIDs: ["video-highlight-1", "video-interview-1"]
        ),
        "video-highlight-1": VideoEditorialContext(
            program: VideoProgram(
                id: "program-match-desk",
                titleArabic: "استوديو المباراة",
                titleEnglish: "Match Desk"
            ),
            relatedVideoIDs: ["video-replay-1", "video-interview-1"]
        ),
        "video-replay-1": VideoEditorialContext(
            program: VideoProgram(
                id: "program-match-desk",
                titleArabic: "استوديو المباراة",
                titleEnglish: "Match Desk"
            ),
            relatedVideoIDs: ["video-highlight-1", "video-interview-1"]
        ),
        "video-original-1": VideoEditorialContext(
            program: VideoProgram(
                id: "program-tactics-studio",
                titleArabic: "الاستوديو التكتيكي",
                titleEnglish: "Tactics Studio"
            ),
            relatedVideoIDs: ["video-highlight-1", "video-replay-1"]
        ),
        "video-interview-1": VideoEditorialContext(
            program: VideoProgram(
                id: "program-match-desk",
                titleArabic: "استوديو المباراة",
                titleEnglish: "Match Desk"
            ),
            relatedVideoIDs: ["video-highlight-1", "video-replay-1"]
        ),
        "video-basketball-1": VideoEditorialContext(
            program: VideoProgram(
                id: "program-court-review",
                titleArabic: "مراجعة الملعب",
                titleEnglish: "Court Review"
            ),
            relatedVideoIDs: []
        ),
        "video-esports-1": VideoEditorialContext(
            program: VideoProgram(
                id: "program-esports-lab",
                titleArabic: "مختبر الرياضات الإلكترونية",
                titleEnglish: "Esports Lab"
            ),
            relatedVideoIDs: []
        )
    ]

    static func videoDetails(id: String, publishedAt: Date) -> SportsVideoDetails? {
        guard let video = videos.first(where: { $0.id == id }),
              let context = videoEditorialContexts[id] else {
            return nil
        }
        let relatedVideos = context.relatedVideoIDs.compactMap { relatedID in
            videos.first(where: { $0.id == relatedID })
        }
        guard relatedVideos.count == context.relatedVideoIDs.count else { return nil }
        return SportsVideoDetails(
            video: video,
            publishedAt: publishedAt,
            audioLanguages: ["ar", "en"],
            subtitleLanguages: ["ar", "en"],
            publisherArabic: demoPublisherArabic,
            publisherEnglish: demoPublisherEnglish,
            program: context.program,
            relatedVideos: relatedVideos
        )
    }

    static let videoDiscovery: VideoDiscoveryFeed = {
        let sportByVideoID: [String: VideoSport] = [
            "video-live-1": .football,
            "video-highlight-1": .football,
            "video-replay-1": .football,
            "video-original-1": .football,
            "video-interview-1": .football,
            "video-basketball-1": .basketball,
            "video-esports-1": .esports
        ]
        let items = videos.compactMap { video in
            sportByVideoID[video.id].map { sport in
                VideoDiscoveryItem(video: video, sport: sport)
            }
        }
        return VideoDiscoveryFeed(
            items: items,
            featuredVideoID: "video-original-1",
            trendingVideoIDs: [
                "video-highlight-1",
                "video-esports-1",
                "video-basketball-1"
            ]
        )
    }()

    static let videoPrograms: [VideoProgramSummary] = [
        VideoProgramSummary(
            program: VideoProgram(
                id: "program-tactics-studio",
                titleArabic: "الاستوديو التكتيكي",
                titleEnglish: "Tactics Studio"
            ),
            descriptionArabic: "برنامج تحليلي خيالي يختبر شرح الأفكار التكتيكية دون فرق أو مسابقات حقيقية.",
            descriptionEnglish: "A fictional analysis show for testing tactical explanations without real teams or competitions.",
            sport: .football,
            featuredVideo: videos.first { $0.id == "video-original-1" }
        ),
        VideoProgramSummary(
            program: VideoProgram(
                id: "program-match-desk",
                titleArabic: "استوديو المباراة",
                titleEnglish: "Match Desk"
            ),
            descriptionArabic: "رف تجريبي خيالي يجمع الاستوديو والملخص والإعادة والمقابلة من دون بث مرخص.",
            descriptionEnglish: "A fictional demo shelf linking studio, highlights, replay and interview metadata without licensed media.",
            sport: .football,
            featuredVideo: videos.first { $0.id == "video-highlight-1" }
        ),
        VideoProgramSummary(
            program: VideoProgram(
                id: "program-court-review",
                titleArabic: "مراجعة الملعب",
                titleEnglish: "Court Review"
            ),
            descriptionArabic: "برنامج سلة خيالي للعرض التجريبي ولا يشير إلى دوري أو نادٍ حقيقي.",
            descriptionEnglish: "A fictional basketball programme used for demo presentation and tied to no real league or club.",
            sport: .basketball,
            featuredVideo: videos.first { $0.id == "video-basketball-1" }
        ),
        VideoProgramSummary(
            program: VideoProgram(
                id: "program-esports-lab",
                titleArabic: "مختبر الرياضات الإلكترونية",
                titleEnglish: "Esports Lab"
            ),
            descriptionArabic: "برنامج خيالي عن الرياضات الإلكترونية بلا لعبة أو علامة تجارية أو بث محمي.",
            descriptionEnglish: "A fictional esports show with no protected game, brand or broadcast content.",
            sport: .esports,
            featuredVideo: videos.first { $0.id == "video-esports-1" }
        )
    ]

    private static let videoIDsByProgramID: [String: [String]] = [
        "program-tactics-studio": ["video-original-1"],
        "program-match-desk": [
            "video-live-1",
            "video-highlight-1",
            "video-replay-1",
            "video-interview-1"
        ],
        "program-court-review": ["video-basketball-1"],
        "program-esports-lab": ["video-esports-1"]
    ]

    static func videoProgramDetails(
        id: String,
        publishedAt: Date
    ) -> VideoProgramDetailsPage? {
        guard let program = videoPrograms.first(where: { $0.id == id }),
              let videoIDs = videoIDsByProgramID[id] else {
            return nil
        }
        let episodes = videoIDs.enumerated().compactMap { index, videoID in
            videos.first(where: { $0.id == videoID }).map { video in
                VideoProgramEpisode(
                    video: video,
                    publishedAt: video.type == .live
                        ? nil
                        : publishedAt.addingTimeInterval(-Double(index) * 24 * 60 * 60)
                )
            }
        }
        guard episodes.count == videoIDs.count else { return nil }
        return VideoProgramDetailsPage(
            program: program,
            episodes: episodes,
            nextCursor: nil,
            hasMore: false
        )
    }

    static func search(query: String) -> [SearchResultItem] {
        let query = ArabicSearchNormalizer.normalize(query)
        guard query.count >= GlobalSearchContract.minimumQueryLength else { return [] }

        var candidates: [MockSearchCandidate] = []
        var ordinal = 0

        func append(
            result: SearchResultItem,
            primaryValues: [String],
            secondaryValues: [String] = []
        ) {
            defer { ordinal += 1 }
            guard let priority = ArabicSearchNormalizer.matchPriority(
                query: query,
                primaryValues: primaryValues,
                secondaryValues: secondaryValues
            ) else { return }
            candidates.append(
                MockSearchCandidate(result: result, priority: priority, ordinal: ordinal)
            )
        }

        for article in articles() {
            append(
                result: SearchResultItem(
                    type: .article,
                    entityID: article.id,
                    titleArabic: article.titleArabic,
                    titleEnglish: article.titleEnglish,
                    subtitleArabic: article.source,
                    subtitleEnglish: article.source
                ),
                primaryValues: [article.titleArabic, article.titleEnglish],
                secondaryValues: [article.summaryArabic, article.summaryEnglish]
            )
        }

        for video in videos {
            append(
                result: SearchResultItem(
                    type: .video,
                    entityID: video.id,
                    titleArabic: video.titleArabic,
                    titleEnglish: video.titleEnglish,
                    subtitleArabic: video.descriptionArabic,
                    subtitleEnglish: video.descriptionEnglish
                ),
                primaryValues: [video.titleArabic, video.titleEnglish],
                secondaryValues: [video.descriptionArabic, video.descriptionEnglish]
            )
        }

        for player in players {
            append(
                result: SearchResultItem(
                    type: .player,
                    entityID: player.id,
                    titleArabic: player.name,
                    titleEnglish: player.name,
                    subtitleArabic: player.position,
                    subtitleEnglish: player.position
                ),
                primaryValues: [player.name],
                secondaryValues: [player.position]
            )
        }

        for team in teams {
            append(
                result: SearchResultItem(
                    type: .team,
                    entityID: team.id,
                    titleArabic: team.nameArabic,
                    titleEnglish: team.nameEnglish,
                    subtitleArabic: "فريق",
                    subtitleEnglish: "Team"
                ),
                primaryValues: [team.nameArabic, team.nameEnglish, team.monogram]
            )
        }

        for competition in competitions {
            append(
                result: SearchResultItem(
                    type: .competition,
                    entityID: competition.id,
                    titleArabic: competition.nameArabic,
                    titleEnglish: competition.nameEnglish,
                    subtitleArabic: "بطولة",
                    subtitleEnglish: "Competition"
                ),
                primaryValues: [competition.nameArabic, competition.nameEnglish]
            )
        }

        return candidates
            .sorted { lhs, rhs in
                lhs.priority == rhs.priority
                    ? lhs.ordinal < rhs.ordinal
                    : lhs.priority < rhs.priority
            }
            .map(\.result)
    }

    private struct MockSearchCandidate {
        let result: SearchResultItem
        let priority: Int
        let ordinal: Int
    }

    static let events: [FixtureEvent] = [
        FixtureEvent(
            id: "event-kickoff",
            revision: 1,
            minute: 0,
            kind: .kickoff,
            titleArabic: "بداية المباراة",
            titleEnglish: "Kick-off",
            detailArabic: "بدأت المباراة في ملعب المدينة.",
            detailEnglish: "The match started at City Arena."
        ),
        FixtureEvent(
            id: "event-yellow",
            revision: 2,
            minute: 18,
            kind: .yellowCard,
            titleArabic: "بطاقة صفراء",
            titleEnglish: "Yellow card",
            detailArabic: "سالم ناصر — صقور الرياض",
            detailEnglish: "Salem Nasser — Riyadh Falcons"
        ),
        FixtureEvent(
            id: "event-goal",
            revision: 3,
            minute: 37,
            kind: .goal,
            titleArabic: "هدف لصقور الرياض",
            titleEnglish: "Goal for Riyadh Falcons",
            detailArabic: "عمر فهد، صناعة سالم ناصر",
            detailEnglish: "Omar Fahad, assisted by Salem Nasser"
        ),
        FixtureEvent(
            id: "event-halftime",
            revision: 4,
            minute: 45,
            kind: .halfTime,
            titleArabic: "نهاية الشوط الأول",
            titleEnglish: "Half-time",
            detailArabic: "صقور الرياض 1 – 0 أمواج جدة",
            detailEnglish: "Riyadh Falcons 1 – 0 Jeddah Waves"
        ),
        FixtureEvent(
            id: "event-substitution",
            revision: 5,
            minute: 58,
            kind: .substitution,
            titleArabic: "تبديل لأمواج جدة",
            titleEnglish: "Jeddah Waves substitution",
            detailArabic: "دخول ياسر علي وخروج فهد حسن",
            detailEnglish: "Yasser Ali replaces Fahad Hassan"
        )
    ]

    static let liveIncrement = FixtureEvent(
        id: "event-var-demo",
        revision: 6,
        minute: 64,
        kind: .varReview,
        titleArabic: "مراجعة فيديو تجريبية",
        titleEnglish: "Fictional VAR review",
        detailArabic: "حدث خيالي لا يمثل مباراة حقيقية.",
        detailEnglish: "A fictional update that does not represent a real match."
    )

    static func copy(
        _ fixture: Fixture,
        revision: Int,
        minute: Int?
    ) -> Fixture {
        Fixture(
            id: fixture.id,
            competition: fixture.competition,
            homeTeam: fixture.homeTeam,
            awayTeam: fixture.awayTeam,
            kickoff: fixture.kickoff,
            state: fixture.state,
            minute: minute,
            homeScore: fixture.homeScore,
            awayScore: fixture.awayScore,
            venueArabic: fixture.venueArabic,
            venueEnglish: fixture.venueEnglish,
            revision: revision
        )
    }

    static let homeLineup = TeamLineup(
        formation: "4-3-3",
        players: [
            lineupPlayer("home", 1, "Khalid Amin", .goalkeeper, line: 0, order: 0),
            lineupPlayer("home", 2, "Adel Hamad", .defender, line: 1, order: 0),
            lineupPlayer("home", 4, "Rami Saleh", .defender, line: 1, order: 1),
            lineupPlayer("home", 5, "Salem Nasser", .defender, line: 1, order: 2),
            lineupPlayer("home", 3, "Ziyad Majed", .defender, line: 1, order: 3),
            lineupPlayer("home", 6, "Bader Sami", .midfielder, line: 2, order: 0),
            lineupPlayer("home", 8, "Omar Fahad", .midfielder, line: 2, order: 1),
            lineupPlayer("home", 14, "Nasser Ali", .midfielder, line: 2, order: 2),
            lineupPlayer("home", 7, "Faisal Saad", .forward, line: 3, order: 0),
            lineupPlayer("home", 10, "Tariq Saad", .forward, line: 3, order: 1),
            lineupPlayer("home", 11, "Yousef Ahmed", .forward, line: 3, order: 2),
            lineupPlayer("home", 12, "Mansour Khaled", .goalkeeper, isStarter: false),
            lineupPlayer("home", 16, "Hassan Waleed", .defender, isStarter: false),
            lineupPlayer("home", 20, "Abdullah Rashed", .forward, isStarter: false)
        ]
    )

    static let awayLineup = TeamLineup(
        formation: "4-2-3-1",
        players: [
            lineupPlayer("away", 1, "Nawaf Adel", .goalkeeper, line: 0, order: 0),
            lineupPlayer("away", 2, "Khaled Omar", .defender, line: 1, order: 0),
            lineupPlayer("away", 4, "Majed Sami", .defender, line: 1, order: 1),
            lineupPlayer("away", 5, "Saad Nasser", .defender, line: 1, order: 2),
            lineupPlayer("away", 3, "Rashed Amin", .defender, line: 1, order: 3),
            lineupPlayer("away", 6, "Waleed Tariq", .midfielder, line: 2, order: 0),
            lineupPlayer("away", 8, "Hamad Ziyad", .midfielder, line: 2, order: 1),
            lineupPlayer("away", 7, "Fahad Hassan", .midfielder, line: 3, order: 0),
            lineupPlayer("away", 10, "Sultan Bader", .midfielder, line: 3, order: 1),
            lineupPlayer("away", 11, "Ahmed Faisal", .midfielder, line: 3, order: 2),
            lineupPlayer("away", 9, "Yasser Ali", .forward, line: 4, order: 0),
            lineupPlayer("away", 12, "Mohammed Salem", .goalkeeper, isStarter: false),
            lineupPlayer("away", 15, "Ali Mansour", .defender, isStarter: false),
            lineupPlayer("away", 19, "Sami Abdullah", .forward, isStarter: false)
        ]
    )

    static let statistics: [MatchStatistic] = [
        MatchStatistic(id: "possession", titleKey: "stat.possession", homeValue: 56, awayValue: 44, unit: "%"),
        MatchStatistic(id: "shots", titleKey: "stat.shots", homeValue: 9, awayValue: 6, unit: ""),
        MatchStatistic(id: "shots-on-target", titleKey: "stat.shotsOnTarget", homeValue: 4, awayValue: 2, unit: ""),
        MatchStatistic(id: "corners", titleKey: "stat.corners", homeValue: 5, awayValue: 3, unit: "")
    ]

    private enum MockPosition {
        case goalkeeper
        case defender
        case midfielder
        case forward

        var key: String {
            switch self {
            case .goalkeeper: "position.goalkeeper"
            case .defender: "position.defender"
            case .midfielder: "position.midfielder"
            case .forward: "position.forward"
            }
        }
    }

    private static func lineupPlayer(
        _ team: String,
        _ number: Int,
        _ name: String,
        _ position: MockPosition,
        line: Int? = nil,
        order: Int? = nil,
        isStarter: Bool = true
    ) -> LineupPlayer {
        LineupPlayer(
            id: "\(team)-\(number)",
            number: number,
            name: name,
            positionKey: position.key,
            isStarter: isStarter,
            formationPosition: line.flatMap { line in
                order.map { FormationPosition(line: line, order: $0) }
            }
        )
    }
}
