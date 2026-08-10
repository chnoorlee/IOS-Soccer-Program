import XCTest
@testable import SportsHub

final class VideoDiscoveryPresentationTests: XCTestCase {
    func testAvailableFiltersUseCanonicalOrderInsteadOfPayloadOrder() {
        let videos = [
            video("interview", type: .interview),
            video("original", type: .original),
            video("live", type: .live),
            video("highlight", type: .highlight),
            video("replay", type: .replay)
        ]

        XCTAssertEqual(
            VideoDiscoveryFilter.availableFilters(in: videos),
            [.all, .live, .replay, .highlight, .original, .interview]
        )
    }

    func testAllFilterPreservesProviderOrderAndExactMetadata() {
        let videos = [
            video("third", type: .original, reason: .notStarted),
            video("first", type: .live, reason: .regionBlocked),
            video("second", type: .highlight, reason: .entitlementRequired)
        ]

        let presentation = VideoDiscoveryPresentation(
            videos: videos,
            selectedFilter: .all
        )

        XCTAssertEqual(presentation.videos, videos)
        XCTAssertEqual(presentation.videos.map(\.id), ["third", "first", "second"])
    }

    func testEveryTypeFilterIsExactCompleteAndPreservesOrder() {
        let videos = [
            video("live-1", type: .live),
            video("highlight-1", type: .highlight),
            video("live-2", type: .live),
            video("replay-1", type: .replay),
            video("original-1", type: .original),
            video("interview-1", type: .interview)
        ]
        let filters: [VideoDiscoveryFilter] = [
            .live, .replay, .highlight, .original, .interview
        ]

        let filtered = filters.flatMap { filter in
            let filtered = VideoDiscoveryPresentation(
                videos: videos,
                selectedFilter: filter
            ).videos
            XCTAssertEqual(
                filtered.map(\.id),
                videos.filter { filter.includes($0) }.map(\.id)
            )
            XCTAssertTrue(filtered.allSatisfy { filter.includes($0) })
            return filtered
        }

        XCTAssertEqual(Set(filtered.map(\.id)), Set(videos.map(\.id)))
        XCTAssertEqual(filtered.count, videos.count)
        XCTAssertEqual(
            VideoDiscoveryPresentation(videos: videos, selectedFilter: .live).videos.map(\.id),
            ["live-1", "live-2"]
        )
    }

    func testUnavailableSelectionNormalizesToAllWithoutDroppingVideos() {
        let videos = [video("highlight", type: .highlight)]

        let presentation = VideoDiscoveryPresentation(
            videos: videos,
            selectedFilter: .live
        )

        XCTAssertEqual(presentation.selectedFilter, .all)
        XCTAssertEqual(presentation.videos, videos)
        XCTAssertEqual(presentation.availableFilters, [.all, .highlight])
    }

    func testEmptyInputOffersOnlyAllAndNoVideos() {
        let presentation = VideoDiscoveryPresentation(videos: [], selectedFilter: .interview)

        XCTAssertEqual(presentation.availableFilters, [.all])
        XCTAssertEqual(presentation.selectedFilter, .all)
        XCTAssertTrue(presentation.videos.isEmpty)
    }

    func testFilteringDoesNotManufacturePlaybackRights() throws {
        let source = video(
            "live-locked",
            type: .live,
            isPlayable: false,
            reason: .entitlementRequired
        )

        let result = VideoDiscoveryPresentation(
            videos: [source],
            selectedFilter: .live
        )
        let filtered = try XCTUnwrap(result.videos.first)

        XCTAssertEqual(filtered, source)
        XCTAssertFalse(filtered.isPlayable)
        XCTAssertEqual(filtered.availabilityReason, .entitlementRequired)
    }

    private func video(
        _ id: String,
        type: SportsVideoType,
        isPlayable: Bool = false,
        reason: VideoAvailabilityReason = .notStarted
    ) -> SportsVideo {
        SportsVideo(
            id: id,
            type: type,
            titleArabic: "عنوان \(id)",
            titleEnglish: "Title \(id)",
            descriptionArabic: "وصف تجريبي",
            descriptionEnglish: "Demo description",
            durationSeconds: type == .live ? 0 : 300,
            isPlayable: isPlayable,
            availabilityReason: isPlayable ? nil : reason
        )
    }
}
