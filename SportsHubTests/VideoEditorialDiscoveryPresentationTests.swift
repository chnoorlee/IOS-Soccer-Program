import XCTest
@testable import SportsHub

final class VideoEditorialDiscoveryPresentationTests: XCTestCase {
    func testEmptyFeedHasOnlyAllTypeAndNoEditorialOrLibraryContent() {
        let result = VideoEditorialDiscoveryPresentation(
            feed: .empty,
            selectedSport: .football,
            selectedFilter: .interview
        )

        XCTAssertNil(result.featuredItem)
        XCTAssertTrue(result.trendingItems.isEmpty)
        XCTAssertTrue(result.availableSports.isEmpty)
        XCTAssertNil(result.selectedSport)
        XCTAssertEqual(result.availableFilters, [.all])
        XCTAssertEqual(result.selectedFilter, .all)
        XCTAssertTrue(result.libraryItems.isEmpty)
    }

    func testEditorialHeroAndTrendingUseExplicitIdentifiersAndRankOrder() throws {
        let feed = VideoDiscoveryFeed(
            items: [
                item("hero", sport: .football, type: .original),
                item("third-in-payload", sport: .basketball, type: .highlight),
                item("second-in-payload", sport: .esports, type: .interview)
            ],
            featuredVideoID: "hero",
            trendingVideoIDs: ["second-in-payload", "third-in-payload"]
        )

        let result = VideoEditorialDiscoveryPresentation(
            feed: feed,
            selectedSport: nil,
            selectedFilter: .all
        )

        XCTAssertEqual(result.featuredItem?.id, "hero")
        XCTAssertFalse(try XCTUnwrap(result.featuredItem).video.isPlayable)
        XCTAssertEqual(result.trendingItems.map(\.rank), [1, 2])
        XCTAssertEqual(
            result.trendingItems.map(\.item.id),
            ["second-in-payload", "third-in-payload"]
        )
    }

    func testLibraryFiltersDoNotRewriteGlobalEditorialSurfaces() {
        let feed = VideoDiscoveryFeed(
            items: [
                item("hero", sport: .football, type: .original),
                item("football-highlight", sport: .football, type: .highlight),
                item("esports-original", sport: .esports, type: .original)
            ],
            featuredVideoID: "hero",
            trendingVideoIDs: ["esports-original", "football-highlight"]
        )

        let result = VideoEditorialDiscoveryPresentation(
            feed: feed,
            selectedSport: .football,
            selectedFilter: .highlight
        )

        XCTAssertEqual(result.libraryItems.map(\.id), ["football-highlight"])
        XCTAssertEqual(result.featuredItem?.id, "hero")
        XCTAssertEqual(
            result.trendingItems.map(\.item.id),
            ["esports-original", "football-highlight"]
        )
    }

    func testSportsUseCanonicalOrderAndOnlyIncludePresentValues() {
        let feed = VideoDiscoveryFeed(
            items: [
                item("esports", sport: .esports, type: .original),
                item("football", sport: .football, type: .live),
                item("basketball", sport: .basketball, type: .highlight)
            ],
            featuredVideoID: nil,
            trendingVideoIDs: []
        )

        let result = VideoEditorialDiscoveryPresentation(
            feed: feed,
            selectedSport: nil,
            selectedFilter: .all
        )

        XCTAssertEqual(result.availableSports, [.football, .basketball, .esports])
        XCTAssertEqual(result.libraryItems.map(\.id), ["esports", "football", "basketball"])
    }

    func testUnavailableSportAndTypeSelectionsNormalizeToAll() {
        let source = item("football-highlight", sport: .football, type: .highlight)
        let result = VideoEditorialDiscoveryPresentation(
            feed: VideoDiscoveryFeed(
                items: [source],
                featuredVideoID: nil,
                trendingVideoIDs: []
            ),
            selectedSport: .archery,
            selectedFilter: .live
        )

        XCTAssertNil(result.selectedSport)
        XCTAssertEqual(result.selectedFilter, .all)
        XCTAssertEqual(result.availableFilters, [.all, .highlight])
        XCTAssertEqual(result.libraryItems, [source])
    }

    func testSportAndTypeIntersectionPreservesProviderOrderAndPlaybackRights() {
        let lockedFirst = item(
            "locked-first",
            sport: .esports,
            type: .original,
            reason: .entitlementRequired
        )
        let otherSport = item("football", sport: .football, type: .original)
        let lockedSecond = item(
            "locked-second",
            sport: .esports,
            type: .original,
            reason: .regionBlocked
        )
        let result = VideoEditorialDiscoveryPresentation(
            feed: VideoDiscoveryFeed(
                items: [lockedFirst, otherSport, lockedSecond],
                featuredVideoID: nil,
                trendingVideoIDs: []
            ),
            selectedSport: .esports,
            selectedFilter: .original
        )

        XCTAssertEqual(result.libraryItems.map(\.id), ["locked-first", "locked-second"])
        XCTAssertEqual(
            result.libraryItems.map(\.video.availabilityReason),
            [.entitlementRequired, .regionBlocked]
        )
        XCTAssertTrue(result.libraryItems.allSatisfy { !$0.video.isPlayable })
    }

    private func item(
        _ id: String,
        sport: VideoSport,
        type: SportsVideoType,
        reason: VideoAvailabilityReason = .notStarted
    ) -> VideoDiscoveryItem {
        VideoDiscoveryItem(
            video: SportsVideo(
                id: id,
                type: type,
                titleArabic: "عنوان \(id)",
                titleEnglish: "Title \(id)",
                descriptionArabic: "وصف تجريبي",
                descriptionEnglish: "Demo description",
                durationSeconds: type == .live ? 0 : 300,
                isPlayable: false,
                availabilityReason: reason
            ),
            sport: sport
        )
    }
}
