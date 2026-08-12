import Foundation
import XCTest
@testable import SportsHub

final class PersonalVideoStateStoreTests: XCTestCase {
    func testGuestArticleFavoritesPersistOfflineRefreshCorrectionsAndRemoveIdempotently() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let savedAt = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z")
        )
        let store = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let availableArticles = try await MockSportsDataProvider().articles()
        let article = try XCTUnwrap(availableArticles.first)
        let saved = try await store.saveArticleFavorite(article: article, updatedAt: savedAt)

        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.updatedAt, savedAt)

        let corrected = Article(
            id: article.id,
            titleArabic: "عنوان مصحح",
            titleEnglish: "Corrected title",
            summaryArabic: article.summaryArabic,
            summaryEnglish: article.summaryEnglish,
            source: article.source,
            publishedAt: article.publishedAt,
            categoryKey: article.categoryKey,
            isCorrected: true
        )
        try await store.recordArticleIfSaved(corrected)

        let reopened = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let offlineArticles = try await reopened.favoriteArticles()
        let offlineState = try await reopened.articleFavorite(articleID: article.id)
        XCTAssertEqual(offlineArticles.first?.titleEnglish, "Corrected title")
        XCTAssertTrue(offlineArticles.first?.isCorrected == true)
        XCTAssertEqual(offlineState.updatedAt, savedAt)

        _ = try await reopened.removeArticleFavorite(articleID: article.id)
        _ = try await reopened.removeArticleFavorite(articleID: article.id)
        let favoritesAfterRemoval = try await reopened.favoriteArticles()
        let exportAfterRemoval = try await reopened.exportGuestPersonalization()
        XCTAssertTrue(favoritesAfterRemoval.isEmpty)
        XCTAssertTrue(exportAfterRemoval.articleFavorites.isEmpty)
    }

    func testUnsavedArticlesAreNotPersistedAndSavedArticlesUseNewestFirstStableOrder() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let store = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let articles = try await MockSportsDataProvider().articles()
        let first = try XCTUnwrap(articles.first { $0.id == "article-1" })
        let second = try XCTUnwrap(articles.first { $0.id == "article-2" })
        let earlier = Date(timeIntervalSince1970: 1_785_931_200)
        let later = earlier.addingTimeInterval(60)

        try await store.recordArticleIfSaved(first)
        let favoritesBeforeSave = try await store.favoriteArticles()
        XCTAssertTrue(favoritesBeforeSave.isEmpty)

        _ = try await store.saveArticleFavorite(article: first, updatedAt: earlier)
        _ = try await store.saveArticleFavorite(article: second, updatedAt: later)
        _ = try await store.saveArticleFavorite(article: second, updatedAt: later.addingTimeInterval(60))

        let saved = try await store.favoriteArticles()
        let secondState = try await store.articleFavorite(articleID: second.id)
        XCTAssertEqual(saved.map(\.id), ["article-2", "article-1"])
        XCTAssertEqual(secondState.updatedAt, later, "Repeated save must retain the original saved time")

        _ = try await store.removeArticleFavorite(articleID: first.id)
        _ = try await store.removeArticleFavorite(articleID: second.id)
        _ = try await store.saveArticleFavorite(article: second, updatedAt: earlier)
        _ = try await store.saveArticleFavorite(article: first, updatedAt: earlier)
        let stableTie = try await store.favoriteArticles()
        XCTAssertEqual(stableTie.map(\.id), ["article-1", "article-2"])
    }

    func testWithdrawnSavedArticleRemainsOfflineAndRemovableButCannotBeNewlySaved() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let online = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        )
        _ = try await online.setArticleFavorite(articleID: "article-1", isFavorite: true)

        let withdrawn = LocalPersonalizationSportsDataProvider(
            base: FailingSportsDataProvider(error: .contentWithdrawn),
            store: FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        )
        do {
            _ = try await withdrawn.articleDetails(id: "article-1")
            XCTFail("The favorite snapshot must not revive authoritative withdrawn content")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .contentWithdrawn)
        }
        let offlineSaved = try await withdrawn.favoriteArticles()
        XCTAssertEqual(offlineSaved.map(\.id), ["article-1"])

        let removed = try await withdrawn.setArticleFavorite(
            articleID: "article-1",
            isFavorite: false
        )
        XCTAssertFalse(removed.isFavorite)

        do {
            _ = try await withdrawn.setArticleFavorite(
                articleID: "article-2",
                isFavorite: true
            )
            XCTFail("An unavailable article must not be newly saved from a snapshot")
        } catch {
            XCTAssertEqual(error as? SportsDataError, .contentWithdrawn)
        }
    }

    func testVersionOneGuestFileMigratesWithoutLosingExistingPersonalization() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let originalStore = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let originalProvider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: originalStore
        )
        _ = try await originalProvider.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )
        _ = try await originalProvider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 90,
            completed: false
        )
        _ = try await originalProvider.setFollow(
            type: .team,
            entityID: "riyadh-falcons",
            isFollowing: true
        )

        let stateURL = rootDirectory.appendingPathComponent("guest-v1.json")
        let versionTwoData = try Data(contentsOf: stateURL)
        var versionOneJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: versionTwoData) as? [String: Any]
        )
        versionOneJSON["schemaVersion"] = 1
        versionOneJSON.removeValue(forKey: "articlesByID")
        versionOneJSON.removeValue(forKey: "favoriteDatesByArticleID")
        try JSONSerialization.data(withJSONObject: versionOneJSON)
            .write(to: stateURL, options: .atomic)

        let store = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let summary = try await store.guestPersonalizationSummary()
        let migratedState = try await store.exportGuestPersonalization()
        let migratedData = try Data(contentsOf: stateURL)
        let migratedJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: migratedData) as? [String: Any]
        )

        XCTAssertEqual(summary.progressCount, 1)
        XCTAssertEqual(summary.favoriteCount, 1)
        XCTAssertEqual(summary.articleFavoriteCount, 0)
        XCTAssertEqual(summary.followCount, 1)
        XCTAssertEqual(migratedState.watchProgress.map(\.videoID), ["video-highlight-1"])
        XCTAssertEqual(migratedState.videoFavorites.map(\.videoID), ["video-highlight-1"])
        XCTAssertEqual(migratedState.follows.map(\.entityID), ["riyadh-falcons"])
        XCTAssertEqual(migratedJSON["schemaVersion"] as? Int, 3)
        XCTAssertNotNil(migratedJSON["articlesByID"])
        XCTAssertNotNil(migratedJSON["favoriteDatesByArticleID"])
    }

    func testGuestProgressAndFavoritesPersistAndRemainAvailableOffline() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z")
        )
        let online = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: FilePersonalVideoStateStore(rootDirectory: rootDirectory),
            now: { now }
        )

        _ = try await online.videoDetails(id: "video-highlight-1")
        _ = try await online.setVideoFavorite(
            videoID: "video-highlight-1",
            isFavorite: true
        )

        let offline = LocalPersonalizationSportsDataProvider(
            base: FailingSportsDataProvider(error: .networkUnavailable),
            store: FilePersonalVideoStateStore(rootDirectory: rootDirectory),
            now: { now }
        )
        _ = try await offline.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 125,
            completed: false
        )
        let favorites = try await offline.favoriteVideos()
        let continuing = try await offline.continueWatching()
        let progress = try await offline.watchProgress(videoID: "video-highlight-1")
        let favorite = try await offline.videoFavorite(videoID: "video-highlight-1")

        XCTAssertEqual(favorites.first?.id, "video-highlight-1")
        XCTAssertEqual(continuing.first?.progress.positionSeconds, 125)
        XCTAssertEqual(progress?.updatedAt, now)
        XCTAssertTrue(favorite.isFavorite)
    }

    func testCompletedProgressLeavesContinueWatchingAndFavoriteCanBeRemoved() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let provider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        )
        _ = try await provider.setVideoFavorite(videoID: "video-highlight-1", isFavorite: true)
        _ = try await provider.setArticleFavorite(articleID: "article-1", isFavorite: true)
        _ = try await provider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 312,
            completed: true
        )
        _ = try await provider.setVideoFavorite(videoID: "video-highlight-1", isFavorite: false)

        let continuing = try await provider.continueWatching()
        let history = try await provider.watchHistory()
        let favorites = try await provider.favoriteVideos()
        let progress = try await provider.watchProgress(videoID: "video-highlight-1")
        XCTAssertTrue(continuing.isEmpty)
        XCTAssertEqual(history.first?.video.id, "video-highlight-1")
        XCTAssertTrue(history.first?.progress.completed == true)
        XCTAssertTrue(favorites.isEmpty)
        XCTAssertTrue(progress?.completed == true)
    }

    func testClearHistoryPreservesSavedVideosAndGuestFollows() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let provider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        )
        _ = try await provider.setVideoFavorite(videoID: "video-highlight-1", isFavorite: true)
        _ = try await provider.setArticleFavorite(articleID: "article-1", isFavorite: true)
        _ = try await provider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 120,
            completed: false
        )
        _ = try await provider.setFollow(
            type: .team,
            entityID: "riyadh-falcons",
            isFollowing: true
        )

        try await provider.clearWatchHistory()

        let history = try await provider.watchHistory()
        let favorites = try await provider.favoriteVideos()
        let articleFavorites = try await provider.favoriteArticles()
        let follows = try await provider.follows()
        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(favorites.map(\.id), ["video-highlight-1"])
        XCTAssertEqual(articleFavorites.map(\.id), ["article-1"])
        XCTAssertEqual(follows.map(\.entityID), ["riyadh-falcons"])
    }

    func testSingleHistoryRemovalIsIdempotentAndPreservesUnrelatedState() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let provider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        )
        _ = try await provider.setVideoFavorite(videoID: "video-highlight-1", isFavorite: true)
        _ = try await provider.setArticleFavorite(articleID: "article-1", isFavorite: true)
        _ = try await provider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 120,
            completed: false
        )
        _ = try await provider.saveWatchProgress(
            videoID: "video-original-1",
            positionSeconds: 180,
            completed: true
        )
        _ = try await provider.setFollow(
            type: .team,
            entityID: "riyadh-falcons",
            isFollowing: true
        )

        try await provider.removeWatchHistoryItem(videoID: "video-highlight-1")
        try await provider.removeWatchHistoryItem(videoID: "video-highlight-1")

        let reopened = LocalPersonalizationSportsDataProvider(
            base: FailingSportsDataProvider(error: .networkUnavailable),
            store: FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        )
        let history = try await reopened.watchHistory()
        let removedProgress = try await reopened.watchProgress(videoID: "video-highlight-1")
        let favorites = try await reopened.favoriteVideos()
        let follows = try await reopened.follows()
        XCTAssertEqual(history.map(\.video.id), ["video-original-1"])
        XCTAssertNil(removedProgress)
        XCTAssertEqual(favorites.map(\.id), ["video-highlight-1"])
        XCTAssertEqual(follows.map(\.entityID), ["riyadh-falcons"])
    }

    func testGuestExportContainsNoVideoMetadataAndClearIsDurable() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let store = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let provider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: store
        )
        _ = try await provider.setVideoFavorite(videoID: "video-highlight-1", isFavorite: true)
        _ = try await provider.setArticleFavorite(articleID: "article-1", isFavorite: true)
        _ = try await provider.saveWatchProgress(
            videoID: "video-highlight-1",
            positionSeconds: 90,
            completed: false
        )

        let exported = try await store.exportGuestPersonalization()
        XCTAssertEqual(exported.watchProgress.map(\.videoID), ["video-highlight-1"])
        XCTAssertEqual(exported.videoFavorites.map(\.videoID), ["video-highlight-1"])
        XCTAssertEqual(exported.articleFavorites.map(\.articleID), ["article-1"])

        try await store.clearGuestPersonalization()
        let reopened = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let emptyExport = try await reopened.exportGuestPersonalization()
        let emptyContinueWatching = try await reopened.continueWatching()
        let emptyFavorites = try await reopened.favoriteVideos()
        let emptyArticleFavorites = try await reopened.favoriteArticles()
        XCTAssertEqual(emptyExport, .empty)
        XCTAssertTrue(emptyContinueWatching.isEmpty)
        XCTAssertTrue(emptyFavorites.isEmpty)
        XCTAssertTrue(emptyArticleFavorites.isEmpty)
    }

    func testUnusedMetadataSnapshotsDoNotGrowWithoutPersonalActivity() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let store = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let provider = LocalPersonalizationSportsDataProvider(
            base: MockSportsDataProvider(),
            store: store
        )
        _ = try await provider.videoDetails(id: "video-highlight-1")
        _ = try await provider.videoDetails(id: "video-original-1")

        let earlier = try await store.video(id: "video-highlight-1")
        let latest = try await store.video(id: "video-original-1")
        XCTAssertNil(earlier)
        XCTAssertEqual(latest?.id, "video-original-1")
    }

    func testAllTypedFollowSnapshotsPersistOfflineAndRefreshPreservesCreatedAt() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let savedAt = Date(timeIntervalSince1970: 1_785_931_200)
        let originalTeam = MockSportsData.teams[0]
        let player = MockSportsData.players[0]
        let competition = MockSportsData.competition
        let correctedTeam = Team(
            id: originalTeam.id,
            nameArabic: originalTeam.nameArabic,
            nameEnglish: "Corrected team name",
            monogram: originalTeam.monogram,
            colorHex: originalTeam.colorHex
        )
        let store = FilePersonalVideoStateStore(rootDirectory: rootDirectory)

        _ = try await store.saveFollow(
            type: .team,
            entityID: originalTeam.id,
            entity: .team(originalTeam),
            updatedAt: savedAt
        )
        _ = try await store.saveFollow(
            type: .player,
            entityID: player.id,
            entity: .player(player),
            updatedAt: savedAt.addingTimeInterval(120)
        )
        _ = try await store.saveFollow(
            type: .competition,
            entityID: competition.id,
            entity: .competition(competition),
            updatedAt: savedAt.addingTimeInterval(60)
        )
        _ = try await store.saveFollow(
            type: .team,
            entityID: correctedTeam.id,
            entity: .team(correctedTeam),
            updatedAt: savedAt.addingTimeInterval(60)
        )

        let reopened = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let reopenedFollows = try await reopened.follows()
        XCTAssertEqual(reopenedFollows.map(\.type), [.player, .competition, .team])
        let savedTeamFollow = try XCTUnwrap(
            reopenedFollows.first { $0.type == .team }
        )
        guard case let .team(team)? = savedTeamFollow.entity else {
            return XCTFail("Expected an offline team snapshot")
        }
        XCTAssertEqual(savedTeamFollow.createdAt, savedAt)
        XCTAssertEqual(team.nameEnglish, "Corrected team name")
        guard case let .player(savedPlayer)? = reopenedFollows.first(where: {
            $0.type == .player
        })?.entity,
              case let .competition(savedCompetition)? = reopenedFollows.first(where: {
                  $0.type == .competition
              })?.entity else {
            return XCTFail("Expected offline player and competition snapshots")
        }
        XCTAssertEqual(savedPlayer, player)
        XCTAssertEqual(savedCompetition, competition)

        try await reopened.removeFollow(type: .team, entityID: originalTeam.id)
        try await reopened.removeFollow(type: .team, entityID: originalTeam.id)
        let followsAfterRemoval = try await reopened.follows()
        XCTAssertEqual(Set(followsAfterRemoval.map(\.type)), [.player, .competition])
    }

    func testFollowStoreRejectsUnsafeIDAndFutureTimestampWithoutPartialWrite() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SportsHubTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let store = FilePersonalVideoStateStore(rootDirectory: rootDirectory)
        let team = MockSportsData.teams[0]

        do {
            _ = try await store.saveFollow(
                type: .team,
                entityID: "unsafe/team",
                entity: nil,
                updatedAt: Date()
            )
            XCTFail("Unsafe follow IDs must be rejected")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .notFound)
        }
        do {
            _ = try await store.saveFollow(
                type: .team,
                entityID: team.id,
                entity: .team(team),
                updatedAt: Date().addingTimeInterval(10 * 60)
            )
            XCTFail("Future follow timestamps must be rejected")
        } catch let error as SportsDataError {
            XCTAssertEqual(error, .contractViolation(field: "updatedAt"))
        }

        let follows = try await store.follows()
        XCTAssertTrue(follows.isEmpty)
    }
}
