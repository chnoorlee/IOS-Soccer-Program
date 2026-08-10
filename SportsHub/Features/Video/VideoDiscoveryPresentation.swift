import Foundation

enum VideoDiscoveryFilter: String, CaseIterable, Hashable, Identifiable, Sendable {
    case all
    case live
    case replay
    case highlight
    case original
    case interview

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .all:
            "video.filter.all"
        case .live, .replay, .highlight, .original, .interview:
            "video.type.\(rawValue)"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "rectangle.grid.1x2.fill"
        case .live: "dot.radiowaves.left.and.right"
        case .replay: "arrow.counterclockwise.circle.fill"
        case .highlight: "star.fill"
        case .original: "play.rectangle.fill"
        case .interview: "person.2.fill"
        }
    }

    func includes(_ video: SportsVideo) -> Bool {
        switch self {
        case .all: true
        case .live: video.type == .live
        case .replay: video.type == .replay
        case .highlight: video.type == .highlight
        case .original: video.type == .original
        case .interview: video.type == .interview
        }
    }

    static func availableFilters(in videos: [SportsVideo]) -> [VideoDiscoveryFilter] {
        allCases.filter { filter in
            filter == .all || videos.contains { filter.includes($0) }
        }
    }
}

struct VideoDiscoveryPresentation: Equatable, Sendable {
    let availableFilters: [VideoDiscoveryFilter]
    let selectedFilter: VideoDiscoveryFilter
    let videos: [SportsVideo]

    init(videos: [SportsVideo], selectedFilter requestedFilter: VideoDiscoveryFilter) {
        let availableFilters = VideoDiscoveryFilter.availableFilters(in: videos)
        let selectedFilter = availableFilters.contains(requestedFilter)
            ? requestedFilter
            : .all

        self.availableFilters = availableFilters
        self.selectedFilter = selectedFilter
        self.videos = videos.filter { selectedFilter.includes($0) }
    }
}

struct RankedVideoDiscoveryItem: Equatable, Identifiable, Sendable {
    let rank: Int
    let item: VideoDiscoveryItem

    var id: String { item.id }
}

struct VideoEditorialDiscoveryPresentation: Equatable, Sendable {
    let featuredItem: VideoDiscoveryItem?
    let trendingItems: [RankedVideoDiscoveryItem]
    let availableSports: [VideoSport]
    let selectedSport: VideoSport?
    let availableFilters: [VideoDiscoveryFilter]
    let selectedFilter: VideoDiscoveryFilter
    let libraryItems: [VideoDiscoveryItem]

    init(
        feed: VideoDiscoveryFeed,
        selectedSport requestedSport: VideoSport?,
        selectedFilter requestedFilter: VideoDiscoveryFilter
    ) {
        featuredItem = feed.featuredVideoID.flatMap { featuredID in
            feed.items.first { $0.id == featuredID }
        }
        trendingItems = feed.trendingVideoIDs.enumerated().compactMap { index, videoID in
            feed.items.first { $0.id == videoID }.map {
                RankedVideoDiscoveryItem(rank: index + 1, item: $0)
            }
        }

        let availableSports = VideoSport.allCases.filter { sport in
            feed.items.contains { $0.sport == sport }
        }
        let selectedSport = requestedSport.flatMap { requested in
            availableSports.contains(requested) ? requested : nil
        }
        let sportItems = feed.items.filter { item in
            selectedSport == nil || item.sport == selectedSport
        }
        let availableFilters = VideoDiscoveryFilter.availableFilters(
            in: sportItems.map(\.video)
        )
        let selectedFilter = availableFilters.contains(requestedFilter)
            ? requestedFilter
            : .all

        self.availableSports = availableSports
        self.selectedSport = selectedSport
        self.availableFilters = availableFilters
        self.selectedFilter = selectedFilter
        libraryItems = sportItems.filter { selectedFilter.includes($0.video) }
    }
}
