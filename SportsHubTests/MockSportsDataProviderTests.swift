import XCTest
@testable import SportsHub

final class MockSportsDataProviderTests: XCTestCase {
    func testHomeFeedContainsFixturesAndArticles() async throws {
        let provider = MockSportsDataProvider()

        let feed = try await provider.homeFeed()

        XCTAssertFalse(feed.fixtures.isEmpty)
        XCTAssertFalse(feed.articles.isEmpty)
    }

    func testEveryFixtureCompetitionIsDiscoverableAndSupportsCompetitionData() async throws {
        let provider = MockSportsDataProvider()

        let competitions = try await provider.competitions()
        let fixtures = try await provider.fixtures(on: Date())
        let competitionIDs = competitions.map(\.id)

        XCTAssertEqual(competitionIDs, ["demo-premier-league", "demo-cup"])
        XCTAssertEqual(
            Set(fixtures.map(\.competition.id)),
            Set(competitionIDs)
        )
        let cupStandings = try await provider.competitionStandings(
            id: MockSportsData.cup.id,
            seasonID: MockSportsData.season.id
        )
        let cupLeaders = try await provider.competitionLeaders(
            id: MockSportsData.cup.id,
            seasonID: MockSportsData.season.id,
            category: .goals
        )
        XCTAssertFalse(cupStandings.isEmpty)
        XCTAssertFalse(cupLeaders.isEmpty)
    }

    func testCompetitionFixturesAreSeasonScopedCompleteAndStablyOrdered() async throws {
        let provider = MockSportsDataProvider()

        let league = try await provider.competitionFixtures(
            id: MockSportsData.competition.id,
            seasonID: MockSportsData.season.id
        )
        let cup = try await provider.competitionFixtures(
            id: MockSportsData.cup.id,
            seasonID: MockSportsData.season.id
        )

        XCTAssertEqual(league.count, 4)
        XCTAssertTrue(league.allSatisfy { $0.competition.id == MockSportsData.competition.id })
        XCTAssertEqual(cup.map(\.id), ["fixture-cup-upcoming-1"])
        XCTAssertEqual(league.map(\.id), league.sorted {
            $0.kickoff == $1.kickoff ? $0.id < $1.id : $0.kickoff < $1.kickoff
        }.map(\.id))

        do {
            _ = try await provider.competitionFixtures(
                id: MockSportsData.competition.id,
                seasonID: "another-season"
            )
            XCTFail("Expected an unknown season to fail closed")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .notFound)
        }
    }

    func testHistoricalSeasonArchiveIsDistinctAndMatchCenterAddressable() async throws {
        let provider = MockSportsDataProvider()

        let competitions = try await provider.competitions()
        let league = try XCTUnwrap(
            competitions.first(where: { $0.id == MockSportsData.competition.id })
        )
        let currentStandings = try await provider.competitionStandings(
            id: league.id,
            seasonID: MockSportsData.season.id
        )
        let archivedStandings = try await provider.competitionStandings(
            id: league.id,
            seasonID: MockSportsData.historicalSeason.id
        )
        let currentLeaders = try await provider.competitionLeaders(
            id: league.id,
            seasonID: MockSportsData.season.id,
            category: .goals
        )
        let archivedLeaders = try await provider.competitionLeaders(
            id: league.id,
            seasonID: MockSportsData.historicalSeason.id,
            category: .goals
        )
        let archivedFixtures = try await provider.competitionFixtures(
            id: league.id,
            seasonID: MockSportsData.historicalSeason.id
        )

        XCTAssertEqual(
            league.seasons.map(\.id),
            [MockSportsData.season.id, MockSportsData.historicalSeason.id]
        )
        XCTAssertEqual(league.currentSeason?.id, MockSportsData.season.id)
        XCTAssertNotEqual(
            currentStandings.first?.rows.first?.team.id,
            archivedStandings.first?.rows.first?.team.id
        )
        XCTAssertNotEqual(currentLeaders.first?.player.id, archivedLeaders.first?.player.id)
        XCTAssertEqual(
            archivedFixtures.map(\.id),
            ["fixture-history-season-2025-26-final"]
        )
        XCTAssertTrue(archivedFixtures.allSatisfy { fixture in
            fixture.state == .finished
                && fixture.kickoff >= MockSportsData.historicalSeason.startDate
                && fixture.kickoff <= MockSportsData.historicalSeason.endDate
        })

        let details = try await provider.fixtureDetails(
            id: try XCTUnwrap(archivedFixtures.first?.id)
        )
        let context = try await provider.fixtureStandings(for: details.fixture)
        XCTAssertEqual(details.fixture.id, archivedFixtures.first?.id)
        XCTAssertEqual(context.season.id, MockSportsData.historicalSeason.id)
        XCTAssertEqual(context.groups, archivedStandings)
    }

    func testTeamChannelHasStrictPreviousNextWindowsAndAuthoritativeContent() async throws {
        let provider = MockSportsDataProvider()
        let teamID = MockSportsData.teams[0].id

        let details = try await provider.teamDetails(id: teamID)
        let content = try await provider.teamContent(id: teamID)

        XCTAssertEqual(details.team.id, teamID)
        XCTAssertEqual(details.recentFixtures.map(\.id), ["fixture-finished-1"])
        XCTAssertEqual(details.nextFixtures.map(\.id), ["fixture-team-next-1"])
        XCTAssertTrue(details.recentFixtures.allSatisfy { fixture in
            fixture.state == .finished
                && [fixture.homeTeam.id, fixture.awayTeam.id].contains(teamID)
        })
        XCTAssertTrue(details.nextFixtures.allSatisfy { fixture in
            fixture.state == .upcoming
                && [fixture.homeTeam.id, fixture.awayTeam.id].contains(teamID)
        })
        XCTAssertEqual(content.teamID, teamID)
        XCTAssertEqual(content.articles.map(\.id), ["article-1"])
        XCTAssertEqual(
            content.videos.map(\.id),
            ["video-highlight-1", "video-interview-1"]
        )

        let nextDetails = try await provider.fixtureDetails(id: "fixture-team-next-1")
        XCTAssertEqual(nextDetails.fixture.state, .upcoming)
        XCTAssertTrue(nextDetails.events.isEmpty)
        XCTAssertTrue(nextDetails.statistics.isEmpty)
    }

    func testPlayerAndCompetitionChannelsUseExplicitBoundedDemoAssociations() async throws {
        let provider = MockSportsDataProvider()
        let playerID = MockSportsData.players[0].id
        let competitionID = MockSportsData.competitions[0].id

        let playerContent = try await provider.playerContent(id: playerID)
        let competitionContent = try await provider.competitionContent(id: competitionID)
        let emptyPlayer = try await provider.playerContent(id: MockSportsData.players[1].id)
        let emptyCompetition = try await provider.competitionContent(
            id: MockSportsData.competitions[1].id
        )

        XCTAssertEqual(playerContent.playerID, playerID)
        XCTAssertEqual(playerContent.articles.map(\.id), ["article-2"])
        XCTAssertEqual(playerContent.videos.map(\.id), ["video-interview-1"])
        XCTAssertEqual(competitionContent.competitionID, competitionID)
        XCTAssertEqual(competitionContent.articles.map(\.id), ["article-1", "article-2"])
        XCTAssertEqual(
            competitionContent.videos.map(\.id),
            ["video-highlight-1", "video-original-1"]
        )
        XCTAssertTrue(emptyPlayer.articles.isEmpty)
        XCTAssertTrue(emptyCompetition.videos.isEmpty)

        do {
            _ = try await provider.playerContent(id: "unknown-player")
            XCTFail("Expected an unknown player to fail closed")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .notFound)
        }
    }

    func testTeamMatchDashboardPreservesRequestedOrderAndStrictSlots() async throws {
        let provider = MockSportsDataProvider()
        let ids = [MockSportsData.teams[1].id, MockSportsData.teams[0].id]

        let snapshots = try await provider.teamMatchSnapshots(ids: ids)

        XCTAssertEqual(snapshots.map(\.team.id), ids)
        for snapshot in snapshots {
            if let previous = snapshot.previousFixture {
                XCTAssertEqual(previous.state, .finished)
                XCTAssertEqual(
                    [previous.homeTeam.id, previous.awayTeam.id]
                        .filter { $0 == snapshot.team.id }
                        .count,
                    1
                )
            }
            if let next = snapshot.nextFixture {
                XCTAssertEqual(next.state, .upcoming)
                XCTAssertEqual(
                    [next.homeTeam.id, next.awayTeam.id]
                        .filter { $0 == snapshot.team.id }
                        .count,
                    1
                )
            }
        }
    }

    func testFixtureDetailsReturnTimelineAndStatistics() async throws {
        let provider = MockSportsDataProvider()

        let details = try await provider.fixtureDetails(id: "fixture-live-1")

        XCTAssertEqual(details.fixture.id, "fixture-live-1")
        XCTAssertTrue(details.events.contains { $0.kind == .goal })
        XCTAssertTrue(details.statistics.contains { $0.id == "possession" })
    }

    func testFixtureContentIsAuthoritativeRightsFilteredAndStateAppropriate() async throws {
        let provider = MockSportsDataProvider()

        let live = try await provider.fixtureContent(id: "fixture-live-1")
        let upcoming = try await provider.fixtureContent(id: "fixture-upcoming-1")

        XCTAssertEqual(live.fixtureID, "fixture-live-1")
        XCTAssertEqual(
            live.moments.map(\.id),
            ["moment-opening-goal", "moment-tactical-turn"]
        )
        XCTAssertEqual(live.articles.map(\.id), ["article-1"])
        XCTAssertTrue(live.moments.allSatisfy {
            !$0.video.isPlayable && $0.video.availabilityReason != nil
        })
        XCTAssertEqual(upcoming.fixtureID, "fixture-upcoming-1")
        XCTAssertTrue(upcoming.moments.isEmpty)
        XCTAssertTrue(upcoming.articles.isEmpty)
    }

    func testUpcomingFixtureNeverReceivesInventedInMatchStatisticsOrEvents() async throws {
        let provider = MockSportsDataProvider()

        let details = try await provider.fixtureDetails(id: "fixture-upcoming-1")

        XCTAssertEqual(details.fixture.state, .upcoming)
        XCTAssertTrue(details.events.isEmpty)
        XCTAssertTrue(details.statistics.isEmpty)
    }

    func testFixtureContextReturnsConfirmedSeasonAndCrossCompetitionHistory() async throws {
        let provider = MockSportsDataProvider()
        let details = try await provider.fixtureDetails(id: "fixture-live-1")

        let standings = try await provider.fixtureStandings(for: details.fixture)
        let headToHead = try await provider.fixtureHeadToHead(
            for: details.fixture,
            limit: 10
        )

        XCTAssertEqual(standings.fixtureID, details.fixture.id)
        XCTAssertEqual(standings.season.id, MockSportsData.season.id)
        XCTAssertTrue(standings.groups.flatMap(\.rows).contains {
            $0.team.id == details.fixture.homeTeam.id
        })
        XCTAssertEqual(headToHead.meetings.count, 3)
        XCTAssertTrue(headToHead.meetings.contains {
            $0.competition.id != details.fixture.competition.id
        })
        XCTAssertEqual(
            headToHead.record(for: details.fixture.homeTeam.id).total,
            headToHead.meetings.count
        )
    }

    func testLiveFixtureExposesOneClearlyFictionalIncrementThenBecomesIdempotent() async throws {
        let provider = MockSportsDataProvider()
        let details = try await provider.fixtureDetails(id: "fixture-live-1")

        let firstBatch = try await provider.fixtureEventUpdates(
            id: details.fixture.id,
            afterRevision: details.fixture.revision
        )
        let repeatedBatch = try await provider.fixtureEventUpdates(
            id: details.fixture.id,
            afterRevision: firstBatch.fixtureRevision
        )

        XCTAssertEqual(details.fixture.revision, 5)
        XCTAssertEqual(firstBatch.fixtureRevision, 6)
        XCTAssertEqual(firstBatch.mutations.count, 1)
        XCTAssertEqual(firstBatch.mutations.first?.event?.kind, .varReview)
        XCTAssertEqual(firstBatch.mutations.first?.event?.revision, 6)
        XCTAssertTrue(repeatedBatch.mutations.isEmpty)
        XCTAssertEqual(repeatedBatch.fixtureRevision, 6)
    }

    func testUnknownFixtureThrows() async {
        let provider = MockSportsDataProvider()

        do {
            _ = try await provider.fixtureDetails(id: "missing")
            XCTFail("Expected an error for an unknown fixture")
        } catch {
            XCTAssertTrue(error is SportsDataError)
        }
    }

    func testEditorialVideoAndArabicSearchFlows() async throws {
        let provider = MockSportsDataProvider()

        let articles = try await provider.articles()
        let corrected = try await provider.articleDetails(id: "article-2")
        let reactions = try await provider.articleReaction(articleID: "article-1")
        let comments = try await provider.articleComments(
            articleID: "article-1",
            cursor: nil,
            limit: 20
        )
        let discovery = try await provider.videoDiscovery()
        let videos = try await provider.videos()
        let details = try await provider.videoDetails(id: "video-highlight-1")
        let arabicResults = try await provider.search(query: "صقور")
        let normalizedExactResults = try await provider.search(
            query: "  صُقُور الـرِّيَاض  "
        )
        let tooShortResults = try await provider.search(query: "a")

        XCTAssertEqual(articles.count, 2)
        XCTAssertEqual(articles[0].engagement?.totalReactions, 202)
        XCTAssertEqual(articles[0].engagement?.publishedComments, 3)
        XCTAssertEqual(articles[1].engagement?.totalReactions, 38)
        XCTAssertEqual(articles[1].engagement?.publishedComments, 0)
        XCTAssertTrue(articles.allSatisfy { $0.heroMedia == nil })
        XCTAssertEqual(
            articles[0].engagement?.totalReactions,
            ArticleReaction.allCases.reduce(0) { $0 + reactions.total(for: $1) }
        )
        XCTAssertEqual(articles[0].engagement?.publishedComments, comments.comments.count)
        XCTAssertTrue(corrected.article.isCorrected)
        XCTAssertEqual(corrected.revision, 2)
        XCTAssertEqual(corrected.article.format, .visualBrief)
        XCTAssertEqual(corrected.visualBrief?.sections.map(\.id), [
            "match-pulse", "set-piece-comparison"
        ])
        XCTAssertEqual(corrected.visualBrief?.sections.flatMap { $0.items }.count, 5)
        XCTAssertFalse(videos.isEmpty)
        XCTAssertTrue(videos.allSatisfy { !$0.isPlayable && $0.availabilityReason != nil })
        XCTAssertTrue(videos.allSatisfy { $0.poster == nil })
        XCTAssertEqual(
            Set(videos.map(\.type)),
            Set<SportsVideoType>([.live, .replay, .highlight, .original, .interview])
        )
        XCTAssertEqual(discovery.items.map(\.video), videos)
        XCTAssertEqual(discovery.featuredVideoID, "video-original-1")
        XCTAssertEqual(discovery.trendingVideoIDs, [
            "video-highlight-1", "video-esports-1", "video-basketball-1"
        ])
        XCTAssertEqual(Set(discovery.items.map(\.sport)), [.football, .basketball, .esports])
        XCTAssertTrue(discovery.items.allSatisfy { !$0.video.isPlayable })
        XCTAssertEqual(details.publisher(in: .english), "SportsHub Demo Desk")
        XCTAssertEqual(details.program?.id, "program-match-desk")
        XCTAssertEqual(
            details.relatedVideos.map(\.id),
            ["video-replay-1", "video-interview-1"]
        )
        XCTAssertTrue(details.relatedVideos.allSatisfy { !$0.isPlayable })
        XCTAssertTrue(arabicResults.contains { $0.type == .article })
        XCTAssertTrue(arabicResults.contains { $0.type == .team })
        XCTAssertEqual(normalizedExactResults.first?.id, "team:riyadh-falcons")
        XCTAssertTrue(tooShortResults.isEmpty)

        do {
            _ = try await provider.search(query: String(repeating: "a", count: 101))
            XCTFail("Oversized mock search queries must obey the shared contract")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }

        do {
            _ = try await provider.createPlaybackSession(
                videoID: "video-highlight-1",
                deviceID: "test-device-identifier-1234",
                capabilities: .nativeHLS
            )
            XCTFail("Demo metadata must not manufacture licensed playback")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .forbidden)
        }
    }

    func testVideoProgramLibraryFiltersPaginatesAndPreservesEpisodeMembership() async throws {
        let provider = MockSportsDataProvider()

        let allPrograms = try await provider.videoPrograms(
            cursor: nil,
            limit: 50,
            sport: nil
        )
        let football = try await provider.videoPrograms(
            cursor: nil,
            limit: 50,
            sport: .football
        )
        let firstPage = try await provider.videoPrograms(
            cursor: nil,
            limit: 1,
            sport: nil
        )
        let secondPage = try await provider.videoPrograms(
            cursor: try XCTUnwrap(firstPage.nextCursor),
            limit: 1,
            sport: nil
        )
        let details = try await provider.videoProgramDetails(
            id: "program-match-desk",
            cursor: nil,
            limit: 50
        )

        XCTAssertEqual(allPrograms.programs.map(\.id), [
            "program-tactics-studio",
            "program-match-desk",
            "program-court-review",
            "program-esports-lab"
        ])
        XCTAssertEqual(football.programs.map(\.id), [
            "program-tactics-studio", "program-match-desk"
        ])
        XCTAssertTrue(football.programs.allSatisfy { $0.sport == .football })
        XCTAssertTrue(firstPage.hasMore)
        XCTAssertNotEqual(firstPage.programs.first?.id, secondPage.programs.first?.id)
        XCTAssertEqual(details.program.id, "program-match-desk")
        XCTAssertEqual(details.episodes.map(\.id), [
            "video-live-1",
            "video-highlight-1",
            "video-replay-1",
            "video-interview-1"
        ])
        XCTAssertNil(details.episodes.first?.publishedAt)
        XCTAssertTrue(details.episodes.allSatisfy { !$0.video.isPlayable })
        XCTAssertTrue(details.episodes.allSatisfy { $0.video.poster == nil })

        do {
            _ = try await provider.videoProgramDetails(
                id: "program-match-desk",
                cursor: nil,
                limit: 0
            )
            XCTFail("Expected an invalid page limit to fail as an invalid query")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }
    }

    func testVideoProgramFallbackIsFirstPageOnlyAndTerminatesPagination() async throws {
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .serverUnavailable),
            fallback: MockSportsDataProvider()
        )

        let programs = try await provider.videoPrograms(
            cursor: nil,
            limit: 1,
            sport: .football
        )
        let details = try await provider.videoProgramDetails(
            id: "program-match-desk",
            cursor: nil,
            limit: 1
        )

        XCTAssertEqual(programs.programs.count, 1)
        XCTAssertFalse(programs.hasMore)
        XCTAssertNil(programs.nextCursor)
        XCTAssertEqual(details.episodes.count, 1)
        XCTAssertFalse(details.hasMore)
        XCTAssertNil(details.nextCursor)

        do {
            _ = try await provider.videoPrograms(
                cursor: "real-later-page",
                limit: 1,
                sport: .football
            )
            XCTFail("A later real page must never fall back to Mock programs")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .serverUnavailable)
        }
        do {
            _ = try await provider.videoProgramDetails(
                id: "program-match-desk",
                cursor: "real-later-page",
                limit: 1
            )
            XCTFail("A later real detail page must never fall back to Mock episodes")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .serverUnavailable)
        }
    }

    func testDeepSportsEntityFlows() async throws {
        let provider = MockSportsDataProvider()
        let competitions = try await provider.competitions()
        let competition = try XCTUnwrap(competitions.first)
        let seasonID = try XCTUnwrap(competition.currentSeasonID)

        let team = try await provider.teamDetails(id: "riyadh-falcons")
        let squad = try await provider.teamSquad(id: "riyadh-falcons", seasonID: seasonID)
        let player = try await provider.playerDetails(id: "player-tariq")
        let transfers = try await provider.playerTransfers(id: "player-tariq")
        let standings = try await provider.competitionStandings(id: competition.id, seasonID: seasonID)
        let leaders = try await provider.competitionLeaders(
            id: competition.id,
            seasonID: seasonID,
            category: .goals
        )

        XCTAssertEqual(team.team.id, "riyadh-falcons")
        XCTAssertFalse(squad.isEmpty)
        XCTAssertEqual(player.currentTeam?.id, "riyadh-falcons")
        XCTAssertEqual(transfers.first?.status, .completed)
        XCTAssertEqual(standings.first?.rows.first?.rank, 1)
        XCTAssertEqual(leaders.first?.value, 14)
    }

    func testTransferCenterFiltersAndPaginatesDeterministically() async throws {
        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let provider = MockSportsDataProvider(now: { now })

        let first = try await provider.transferUpdates(cursor: nil, limit: 2, status: nil)
        let cursor = try XCTUnwrap(first.nextCursor)
        let second = try await provider.transferUpdates(cursor: cursor, limit: 2, status: nil)
        let rumors = try await provider.transferUpdates(cursor: nil, limit: 30, status: .rumored)

        XCTAssertEqual(first.transfers.count, 2)
        XCTAssertEqual(cursor, "offset-2")
        XCTAssertTrue(first.hasMore)
        XCTAssertEqual(second.transfers.count, 2)
        XCTAssertFalse(second.hasMore)
        XCTAssertEqual(Set((first.transfers + second.transfers).map(\.id)).count, 4)
        XCTAssertEqual(rumors.transfers.map(\.status), [.rumored])
        XCTAssertTrue(
            zip(first.transfers, first.transfers.dropFirst()).allSatisfy {
                $0.0.transferDate > $0.1.transferDate
            }
        )
    }

    func testTransferCenterRejectsInvalidLimitAndCursor() async throws {
        let provider = MockSportsDataProvider()
        do {
            _ = try await provider.transferUpdates(cursor: nil, limit: 0, status: nil)
            XCTFail("Expected an invalid page size to fail")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }

        do {
            _ = try await provider.transferUpdates(cursor: "offset-999", limit: 30, status: nil)
            XCTFail("Expected an invalid cursor to fail")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .invalidQuery)
        }
    }

    func testTransferFallbackIsMarkedDemoAndCannotMixLaterLivePages() async throws {
        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let freshness = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .serverUnavailable),
            fallback: MockSportsDataProvider(now: { now }),
            freshnessReporter: freshness,
            now: { now }
        )

        let page = try await provider.transferUpdates(cursor: nil, limit: 2, status: nil)
        let status = await freshness.status(for: .transfers(status: nil))

        XCTAssertEqual(page.transfers.count, 2)
        XCTAssertFalse(page.hasMore)
        XCTAssertNil(page.nextCursor)
        XCTAssertEqual(status, .demoFallback(checkedAt: now))
    }

    func testTransferFallbackRejectsLaterPageInsteadOfMixingSources() async throws {
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .serverUnavailable),
            fallback: MockSportsDataProvider()
        )

        do {
            _ = try await provider.transferUpdates(
                cursor: "offset-2",
                limit: 2,
                status: nil
            )
            XCTFail("A failed live page must not append fictional records")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .serverUnavailable)
        }
    }

    func testSeasonCalendarIsAtomicOrderedAndBounded() async throws {
        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let provider = MockSportsDataProvider(now: { now })

        let snapshot = try await provider.seasonCalendar()

        XCTAssertEqual(snapshot.sourceName, "SportsHub Demo Calendar")
        XCTAssertLessThan(snapshot.rangeStart, snapshot.rangeEnd)
        XCTAssertTrue(snapshot.events.allSatisfy {
            $0.startsAt >= snapshot.rangeStart && $0.startsAt <= snapshot.rangeEnd
        })
        XCTAssertTrue(zip(snapshot.events, snapshot.events.dropFirst()).allSatisfy {
            $0.0.startsAt < $0.1.startsAt
        })
    }

    func testSeasonCalendarFallbackMarksWholeSnapshotAsDemo() async throws {
        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let freshness = PublicContentFreshnessStore()
        let provider = FallbackSportsDataProvider(
            primary: FailingSportsDataProvider(error: .serverUnavailable),
            fallback: MockSportsDataProvider(now: { now }),
            freshnessReporter: freshness,
            now: { now }
        )

        let snapshot = try await provider.seasonCalendar()
        let status = await freshness.status(for: .seasonCalendar)

        XCTAssertEqual(snapshot.events.count, 4)
        XCTAssertEqual(status, .demoFallback(checkedAt: now))
    }

    func testWatchProgressAndFavoriteStateRoundTrip() async throws {
        let provider = MockSportsDataProvider()

        let initialProgress = try await provider.watchProgress(videoID: "video-highlight-1")
        let initialFavorite = try await provider.videoFavorite(videoID: "video-highlight-1")
        XCTAssertNil(initialProgress)
        XCTAssertFalse(initialFavorite.isFavorite)

        let progress = try await provider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 125,
            completed: false
        )
        let favorite = try await provider.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )
        let continuing = try await provider.continueWatching()
        let favorites = try await provider.favoriteVideos()

        XCTAssertEqual(progress.positionSeconds, 125)
        XCTAssertTrue(favorite.isFavorite)
        XCTAssertEqual(continuing.first?.video.id, "video-highlight-1")
        XCTAssertEqual(continuing.first?.progress.positionSeconds, 125)
        XCTAssertEqual(favorites.first?.id, "video-highlight-1")

        _ = try await provider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 312,
            completed: true
        )
        _ = try await provider.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: false
        )

        let finalContinuing = try await provider.continueWatching()
        let finalFavorites = try await provider.favoriteVideos()
        XCTAssertTrue(finalContinuing.isEmpty)
        XCTAssertTrue(finalFavorites.isEmpty)
    }

    func testArticleFavoriteStateIsIdempotentOrderedAndIndependentFromVideoFavorites() async throws {
        let provider = MockSportsDataProvider()

        let initial = try await provider.articleFavorite(articleID: "article-1")
        let firstSave = try await provider.setArticleFavorite(
            articleID: "article-1",
            isFavorite: true
        )
        let repeatedSave = try await provider.setArticleFavorite(
            articleID: "article-1",
            isFavorite: true
        )
        _ = try await provider.setArticleFavorite(articleID: "article-2", isFavorite: true)
        _ = try await provider.setVideoFavorite(videoID: "video-highlight-1", isFavorite: true)
        let savedArticles = try await provider.favoriteArticles()
        let savedVideos = try await provider.favoriteVideos()

        XCTAssertFalse(initial.isFavorite)
        XCTAssertTrue(firstSave.isFavorite)
        XCTAssertEqual(repeatedSave.updatedAt, firstSave.updatedAt)
        XCTAssertEqual(Set(savedArticles.map(\.id)), Set(["article-1", "article-2"]))
        XCTAssertEqual(savedVideos.map(\.id), ["video-highlight-1"])

        _ = try await provider.setArticleFavorite(articleID: "article-1", isFavorite: false)
        _ = try await provider.setArticleFavorite(articleID: "article-1", isFavorite: false)
        let remainingArticles = try await provider.favoriteArticles()
        let remainingVideos = try await provider.favoriteVideos()
        XCTAssertEqual(remainingArticles.map(\.id), ["article-2"])
        XCTAssertEqual(remainingVideos.map(\.id), ["video-highlight-1"])
    }

    func testSingleHistoryRemovalPreservesOtherHistoryAndFavorite() async throws {
        let provider = MockSportsDataProvider()
        _ = try await provider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 125,
            completed: false
        )
        _ = try await provider.saveWatchProgress(
            videoID: "video-original-1",
            positionSeconds: 180,
            completed: true
        )
        _ = try await provider.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )

        try await provider.removeWatchHistoryItem(videoID: "video-highlight-1")

        let history = try await provider.watchHistory()
        let favorite = try await provider.videoFavorite(videoID: "video-highlight-1")
        XCTAssertEqual(history.map(\.video.id), ["video-original-1"])
        XCTAssertTrue(favorite.isFavorite)
    }

    func testAllFollowTypesRetainTypedSnapshotsAndRemoveIndependently() async throws {
        let provider = MockSportsDataProvider()
        let team = MockSportsData.teams[0]
        let player = MockSportsData.players[0]
        let competition = MockSportsData.competition

        _ = try await provider.setFollow(
            type: .team,
            entityID: team.id,
            entity: .team(team),
            isFollowing: true
        )
        _ = try await provider.setFollow(
            type: .player,
            entityID: player.id,
            entity: .player(player),
            isFollowing: true
        )
        _ = try await provider.setFollow(
            type: .competition,
            entityID: competition.id,
            entity: .competition(competition),
            isFollowing: true
        )

        let followed = try await provider.follows()
        XCTAssertEqual(Set(followed.map(\.type)), Set(FollowEntityType.allCases))
        XCTAssertTrue(followed.allSatisfy(\.hasMatchingEntitySnapshot))

        _ = try await provider.setFollow(
            type: .player,
            entityID: player.id,
            entity: .player(player),
            isFollowing: false
        )
        let remaining = try await provider.follows()
        XCTAssertEqual(Set(remaining.map(\.type)), Set([.team, .competition]))
    }

    func testPlayerCatalogReturnsStableProfiles() async throws {
        let players = try await MockSportsDataProvider().players()

        XCTAssertEqual(players, MockSportsData.players)
        XCTAssertEqual(Set(players.map(\.id)).count, players.count)
        XCTAssertTrue(players.allSatisfy { !$0.position.isEmpty })
    }
}
