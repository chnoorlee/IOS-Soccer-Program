import Foundation

struct Team: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let nameArabic: String
    let nameEnglish: String
    let monogram: String
    let colorHex: String

    func displayName(in language: AppLanguage) -> String {
        language == .arabic ? nameArabic : nameEnglish
    }
}

struct Competition: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let nameArabic: String
    let nameEnglish: String
    let currentSeasonID: String?
    let seasons: [Season]

    func displayName(in language: AppLanguage) -> String {
        language == .arabic ? nameArabic : nameEnglish
    }

    var currentSeason: Season? {
        guard let currentSeasonID else { return nil }
        return seasons.first(where: { $0.id == currentSeasonID })
    }
}

struct Season: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let nameArabic: String
    let nameEnglish: String
    let startDate: Date
    let endDate: Date
    let isCurrent: Bool

    func displayName(in language: AppLanguage) -> String {
        language == .arabic ? nameArabic : nameEnglish
    }
}

enum SeasonCalendarEventKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case competitionMilestone
    case draw
    case transferWindow
    case internationalBreak
    case other

    var id: String { rawValue }

    var localizationKey: String {
        "seasonCalendar.kind.\(rawValue)"
    }
}

struct SeasonCalendarEvent: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let titleArabic: String
    let titleEnglish: String
    let detailArabic: String?
    let detailEnglish: String?
    let startsAt: Date
    let endsAt: Date?
    let kind: SeasonCalendarEventKind
    let competition: Competition?

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }

    func detail(in language: AppLanguage) -> String? {
        language == .arabic ? detailArabic : detailEnglish
    }
}

struct SeasonCalendarSnapshot: Codable, Hashable, Sendable {
    let rangeStart: Date
    let rangeEnd: Date
    let updatedAt: Date
    let sourceName: String
    let events: [SeasonCalendarEvent]
}

enum FixtureState: String, Codable, Hashable, Sendable {
    case upcoming
    case live
    case halfTime
    case finished
    case postponed
    case cancelled

    var localizationKey: String {
        switch self {
        case .upcoming: "match.upcoming"
        case .live: "match.live"
        case .halfTime: "match.halftime"
        case .finished: "match.finished"
        case .postponed: "match.postponed"
        case .cancelled: "match.cancelled"
        }
    }
}

struct FixtureBroadcast: Codable, Hashable, Sendable {
    let regionCode: String
    let channelArabic: String
    let channelEnglish: String
    let commentatorArabic: String?
    let commentatorEnglish: String?
    let audioLanguageCode: String?

    func channel(in language: AppLanguage) -> String {
        language == .arabic ? channelArabic : channelEnglish
    }

    func commentator(in language: AppLanguage) -> String? {
        language == .arabic ? commentatorArabic : commentatorEnglish
    }

    func regionName(in language: AppLanguage) -> String {
        language.locale.localizedString(forRegionCode: regionCode) ?? regionCode
    }

    func audioLanguageName(in language: AppLanguage) -> String? {
        guard let audioLanguageCode else { return nil }
        let languageCode = audioLanguageCode.split(separator: "-").first.map(String.init)
        guard let languageCode else { return audioLanguageCode }
        return language.locale.localizedString(forLanguageCode: languageCode)
            ?? audioLanguageCode
    }
}

struct Fixture: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let competition: Competition
    let homeTeam: Team
    let awayTeam: Team
    let kickoff: Date
    let state: FixtureState
    let minute: Int?
    let homeScore: Int?
    let awayScore: Int?
    let venueArabic: String
    let venueEnglish: String
    let broadcasts: [FixtureBroadcast]
    let revision: Int

    init(
        id: String,
        competition: Competition,
        homeTeam: Team,
        awayTeam: Team,
        kickoff: Date,
        state: FixtureState,
        minute: Int?,
        homeScore: Int?,
        awayScore: Int?,
        venueArabic: String,
        venueEnglish: String,
        broadcasts: [FixtureBroadcast] = [],
        revision: Int = 0
    ) {
        self.id = id
        self.competition = competition
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.kickoff = kickoff
        self.state = state
        self.minute = minute
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.venueArabic = venueArabic
        self.venueEnglish = venueEnglish
        self.broadcasts = broadcasts
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case competition
        case homeTeam
        case awayTeam
        case kickoff
        case state
        case minute
        case homeScore
        case awayScore
        case venueArabic
        case venueEnglish
        case broadcasts
        case revision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        competition = try container.decode(Competition.self, forKey: .competition)
        homeTeam = try container.decode(Team.self, forKey: .homeTeam)
        awayTeam = try container.decode(Team.self, forKey: .awayTeam)
        kickoff = try container.decode(Date.self, forKey: .kickoff)
        state = try container.decode(FixtureState.self, forKey: .state)
        minute = try container.decodeIfPresent(Int.self, forKey: .minute)
        homeScore = try container.decodeIfPresent(Int.self, forKey: .homeScore)
        awayScore = try container.decodeIfPresent(Int.self, forKey: .awayScore)
        venueArabic = try container.decode(String.self, forKey: .venueArabic)
        venueEnglish = try container.decode(String.self, forKey: .venueEnglish)
        broadcasts = try container.decodeIfPresent(
            [FixtureBroadcast].self,
            forKey: .broadcasts
        ) ?? []
        revision = try container.decode(Int.self, forKey: .revision)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(competition, forKey: .competition)
        try container.encode(homeTeam, forKey: .homeTeam)
        try container.encode(awayTeam, forKey: .awayTeam)
        try container.encode(kickoff, forKey: .kickoff)
        try container.encode(state, forKey: .state)
        try container.encodeIfPresent(minute, forKey: .minute)
        try container.encodeIfPresent(homeScore, forKey: .homeScore)
        try container.encodeIfPresent(awayScore, forKey: .awayScore)
        try container.encode(venueArabic, forKey: .venueArabic)
        try container.encode(venueEnglish, forKey: .venueEnglish)
        try container.encode(broadcasts, forKey: .broadcasts)
        try container.encode(revision, forKey: .revision)
    }

    var scoreText: String? {
        guard let homeScore, let awayScore else { return nil }
        return "\(homeScore) – \(awayScore)"
    }

    func venue(in language: AppLanguage) -> String {
        language == .arabic ? venueArabic : venueEnglish
    }
}

enum ArticleFormat: String, Codable, Hashable, Sendable {
    case story
    case visualBrief

    var localizationKey: String {
        switch self {
        case .story: "article.format.story"
        case .visualBrief: "article.format.visualBrief"
        }
    }
}

enum ArticleVisualSectionKind: String, Codable, Hashable, Sendable {
    case metricGrid
    case comparison
    case sequence
}

struct ArticleVisualItem: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let valueArabic: String
    let valueEnglish: String
    let labelArabic: String
    let labelEnglish: String
    let detailArabic: String?
    let detailEnglish: String?

    func value(in language: AppLanguage) -> String {
        language == .arabic ? valueArabic : valueEnglish
    }

    func label(in language: AppLanguage) -> String {
        language == .arabic ? labelArabic : labelEnglish
    }

    func detail(in language: AppLanguage) -> String? {
        language == .arabic ? detailArabic : detailEnglish
    }
}

struct ArticleVisualSection: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let kind: ArticleVisualSectionKind
    let titleArabic: String
    let titleEnglish: String
    let items: [ArticleVisualItem]

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }
}

struct ArticleVisualBrief: Codable, Hashable, Sendable {
    let titleArabic: String
    let titleEnglish: String
    let sourceNoteArabic: String
    let sourceNoteEnglish: String
    let sections: [ArticleVisualSection]

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }

    func sourceNote(in language: AppLanguage) -> String {
        language == .arabic ? sourceNoteArabic : sourceNoteEnglish
    }
}

struct ArticleEngagementSummary: Codable, Hashable, Sendable {
    static let maximumCount = 2_000_000_000

    let totalReactions: Int
    let publishedComments: Int

    init(totalReactions: Int, publishedComments: Int) {
        self.totalReactions = totalReactions
        self.publishedComments = publishedComments
    }

    private enum CodingKeys: String, CodingKey {
        case totalReactions
        case publishedComments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let totalReactions = try container.decode(Int.self, forKey: .totalReactions)
        let publishedComments = try container.decode(Int.self, forKey: .publishedComments)
        guard (0...Self.maximumCount).contains(totalReactions) else {
            throw DecodingError.dataCorruptedError(
                forKey: .totalReactions,
                in: container,
                debugDescription: "Article reaction total is outside the supported range."
            )
        }
        guard (0...Self.maximumCount).contains(publishedComments) else {
            throw DecodingError.dataCorruptedError(
                forKey: .publishedComments,
                in: container,
                debugDescription: "Published comment total is outside the supported range."
            )
        }
        self.totalReactions = totalReactions
        self.publishedComments = publishedComments
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalReactions, forKey: .totalReactions)
        try container.encode(publishedComments, forKey: .publishedComments)
    }
}

enum EditorialImageContentType: String, Hashable, Sendable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case webP = "image/webp"
    case heic = "image/heic"
    case heif = "image/heif"
}

typealias ArticleHeroMediaContentType = EditorialImageContentType

enum EditorialImageMediaPolicy {
    static let maximumByteCount = 8 * 1_024 * 1_024
}

struct ArticleHeroMedia: Hashable, Identifiable, Sendable {
    static let maximumByteCount = EditorialImageMediaPolicy.maximumByteCount

    let id: String
    let url: URL
    let contentType: ArticleHeroMediaContentType
    let width: Int
    let height: Int
    let altArabic: String
    let altEnglish: String
    let creditArabic: String
    let creditEnglish: String

    func altText(in language: AppLanguage) -> String {
        language == .arabic ? altArabic : altEnglish
    }

    func credit(in language: AppLanguage) -> String {
        language == .arabic ? creditArabic : creditEnglish
    }
}

struct VideoPosterMedia: Hashable, Identifiable, Sendable {
    static let maximumByteCount = EditorialImageMediaPolicy.maximumByteCount

    let id: String
    let url: URL
    let contentType: EditorialImageContentType
    let width: Int
    let height: Int
    let altArabic: String
    let altEnglish: String
    let creditArabic: String
    let creditEnglish: String

    func altText(in language: AppLanguage) -> String {
        language == .arabic ? altArabic : altEnglish
    }

    func credit(in language: AppLanguage) -> String {
        language == .arabic ? creditArabic : creditEnglish
    }
}

struct Article: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let titleArabic: String
    let titleEnglish: String
    let summaryArabic: String
    let summaryEnglish: String
    let source: String
    let publishedAt: Date
    let categoryKey: String
    let format: ArticleFormat
    let isCorrected: Bool
    let engagement: ArticleEngagementSummary?
    let heroMedia: ArticleHeroMedia?

    init(
        id: String,
        titleArabic: String,
        titleEnglish: String,
        summaryArabic: String,
        summaryEnglish: String,
        source: String,
        publishedAt: Date,
        categoryKey: String,
        format: ArticleFormat = .story,
        isCorrected: Bool,
        engagement: ArticleEngagementSummary? = nil,
        heroMedia: ArticleHeroMedia? = nil
    ) {
        self.id = id
        self.titleArabic = titleArabic
        self.titleEnglish = titleEnglish
        self.summaryArabic = summaryArabic
        self.summaryEnglish = summaryEnglish
        self.source = source
        self.publishedAt = publishedAt
        self.categoryKey = categoryKey
        self.format = format
        self.isCorrected = isCorrected
        self.engagement = engagement
        self.heroMedia = heroMedia
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case titleArabic
        case titleEnglish
        case summaryArabic
        case summaryEnglish
        case source
        case publishedAt
        case categoryKey
        case format
        case isCorrected
        case engagement
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        titleArabic = try container.decode(String.self, forKey: .titleArabic)
        titleEnglish = try container.decode(String.self, forKey: .titleEnglish)
        summaryArabic = try container.decode(String.self, forKey: .summaryArabic)
        summaryEnglish = try container.decode(String.self, forKey: .summaryEnglish)
        source = try container.decode(String.self, forKey: .source)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        categoryKey = try container.decode(String.self, forKey: .categoryKey)
        format = try container.decodeIfPresent(ArticleFormat.self, forKey: .format) ?? .story
        isCorrected = try container.decode(Bool.self, forKey: .isCorrected)
        engagement = try container.decodeIfPresent(
            ArticleEngagementSummary.self,
            forKey: .engagement
        )
        // Personal saved-article snapshots intentionally omit expiring media URLs.
        heroMedia = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(titleArabic, forKey: .titleArabic)
        try container.encode(titleEnglish, forKey: .titleEnglish)
        try container.encode(summaryArabic, forKey: .summaryArabic)
        try container.encode(summaryEnglish, forKey: .summaryEnglish)
        try container.encode(source, forKey: .source)
        try container.encode(publishedAt, forKey: .publishedAt)
        try container.encode(categoryKey, forKey: .categoryKey)
        try container.encode(format, forKey: .format)
        try container.encode(isCorrected, forKey: .isCorrected)
        try container.encodeIfPresent(engagement, forKey: .engagement)
    }

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }

    func summary(in language: AppLanguage) -> String {
        language == .arabic ? summaryArabic : summaryEnglish
    }
}

struct ArticleDetails: Codable, Hashable, Sendable {
    let article: Article
    let bodyArabic: String
    let bodyEnglish: String
    let revision: Int
    let visualBrief: ArticleVisualBrief?

    init(
        article: Article,
        bodyArabic: String,
        bodyEnglish: String,
        revision: Int,
        visualBrief: ArticleVisualBrief? = nil
    ) {
        self.article = article
        self.bodyArabic = bodyArabic
        self.bodyEnglish = bodyEnglish
        self.revision = revision
        self.visualBrief = visualBrief
    }

    func body(in language: AppLanguage) -> String {
        language == .arabic ? bodyArabic : bodyEnglish
    }
}

enum ArticleReaction: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case like = "LIKE"
    case insightful = "INSIGHTFUL"
    case celebrate = "CELEBRATE"

    var id: String { rawValue }
    var localizationKey: String { "community.reaction.\(rawValue.lowercased())" }

    var systemImage: String {
        switch self {
        case .like: "hand.thumbsup.fill"
        case .insightful: "lightbulb.fill"
        case .celebrate: "sparkles"
        }
    }
}

struct ArticleReactionSummary: Equatable, Sendable {
    let myReaction: ArticleReaction?
    let totals: [ArticleReaction: Int]

    func total(for reaction: ArticleReaction) -> Int {
        totals[reaction, default: 0]
    }

    static let empty = ArticleReactionSummary(
        myReaction: nil,
        totals: Dictionary(uniqueKeysWithValues: ArticleReaction.allCases.map { ($0, 0) })
    )
}

enum CommentModerationState: String, Codable, Hashable, Sendable {
    case pending = "PENDING"
    case published = "PUBLISHED"
    case rejected = "REJECTED"
    case removed = "REMOVED"
}

struct ArticleComment: Equatable, Identifiable, Sendable {
    let id: String
    let articleID: String
    let body: String
    let authorID: String
    let authorDisplayName: String
    let moderationState: CommentModerationState
    let isMine: Bool
    let createdAt: Date
}

struct ArticleCommentPage: Equatable, Sendable {
    let comments: [ArticleComment]
    let nextCursor: String?
    let hasMore: Bool
}

enum CommentReportReason: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case harassment = "HARASSMENT"
    case hate = "HATE"
    case spam = "SPAM"
    case misinformation = "MISINFORMATION"
    case other = "OTHER"

    var id: String { rawValue }
    var localizationKey: String { "community.report.reason.\(rawValue.lowercased())" }
}

struct CommunityReportReceipt: Equatable, Sendable {
    let reportID: String
    let submittedAt: Date
}

enum SportsVideoType: String, Codable, Hashable, Sendable {
    case live
    case replay
    case highlight
    case original
    case interview

    var localizationKey: String {
        "video.type.\(rawValue)"
    }
}

enum VideoSport: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case football
    case basketball
    case esports
    case motorsport
    case combat
    case archery

    var id: String { rawValue }

    var localizationKey: String {
        "video.sport.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .football: "soccerball"
        case .basketball: "basketball.fill"
        case .esports: "gamecontroller.fill"
        case .motorsport: "flag.checkered"
        case .combat: "figure.boxing"
        case .archery: "scope"
        }
    }
}

enum VideoAvailabilityReason: String, Codable, Hashable, Sendable {
    case loginRequired
    case entitlementRequired
    case regionBlocked
    case notStarted
    case expired
    case unavailable

    var localizationKey: String {
        "video.availability.\(rawValue)"
    }
}

struct SportsVideo: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let type: SportsVideoType
    let titleArabic: String
    let titleEnglish: String
    let descriptionArabic: String
    let descriptionEnglish: String
    let poster: VideoPosterMedia?
    let durationSeconds: Int
    let isPlayable: Bool
    let availabilityReason: VideoAvailabilityReason?

    init(
        id: String,
        type: SportsVideoType,
        titleArabic: String,
        titleEnglish: String,
        descriptionArabic: String,
        descriptionEnglish: String,
        poster: VideoPosterMedia? = nil,
        durationSeconds: Int,
        isPlayable: Bool,
        availabilityReason: VideoAvailabilityReason?
    ) {
        self.id = id
        self.type = type
        self.titleArabic = titleArabic
        self.titleEnglish = titleEnglish
        self.descriptionArabic = descriptionArabic
        self.descriptionEnglish = descriptionEnglish
        self.poster = poster
        self.durationSeconds = durationSeconds
        self.isPlayable = isPlayable
        self.availabilityReason = availabilityReason
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case titleArabic
        case titleEnglish
        case descriptionArabic
        case descriptionEnglish
        case durationSeconds
        case isPlayable
        case availabilityReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(SportsVideoType.self, forKey: .type)
        titleArabic = try container.decode(String.self, forKey: .titleArabic)
        titleEnglish = try container.decode(String.self, forKey: .titleEnglish)
        descriptionArabic = try container.decode(String.self, forKey: .descriptionArabic)
        descriptionEnglish = try container.decode(String.self, forKey: .descriptionEnglish)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        isPlayable = try container.decode(Bool.self, forKey: .isPlayable)
        availabilityReason = try container.decodeIfPresent(
            VideoAvailabilityReason.self,
            forKey: .availabilityReason
        )
        // Personal video state intentionally omits expiring poster URLs.
        poster = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(titleArabic, forKey: .titleArabic)
        try container.encode(titleEnglish, forKey: .titleEnglish)
        try container.encode(descriptionArabic, forKey: .descriptionArabic)
        try container.encode(descriptionEnglish, forKey: .descriptionEnglish)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(isPlayable, forKey: .isPlayable)
        try container.encodeIfPresent(availabilityReason, forKey: .availabilityReason)
    }

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }

    func description(in language: AppLanguage) -> String {
        language == .arabic ? descriptionArabic : descriptionEnglish
    }

    var durationText: String {
        let hours = durationSeconds / 3_600
        let minutes = (durationSeconds % 3_600) / 60
        let seconds = durationSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VideoProgram: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let titleArabic: String
    let titleEnglish: String

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }
}

struct VideoProgramSummary: Hashable, Identifiable, Sendable {
    let program: VideoProgram
    let descriptionArabic: String
    let descriptionEnglish: String
    let sport: VideoSport
    let featuredVideo: SportsVideo?

    var id: String { program.id }

    func title(in language: AppLanguage) -> String {
        program.title(in: language)
    }

    func description(in language: AppLanguage) -> String {
        language == .arabic ? descriptionArabic : descriptionEnglish
    }
}

struct VideoProgramPage: Hashable, Sendable {
    let programs: [VideoProgramSummary]
    let nextCursor: String?
    let hasMore: Bool

    func appending(to existing: [VideoProgramSummary]) throws -> [VideoProgramSummary] {
        let existingIDs = Set(existing.map(\.id))
        guard programs.allSatisfy({ !existingIDs.contains($0.id) }) else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        return existing + programs
    }
}

struct VideoProgramEpisode: Hashable, Identifiable, Sendable {
    let video: SportsVideo
    let publishedAt: Date?

    var id: String { video.id }
}

struct VideoProgramDetailsPage: Hashable, Sendable {
    let program: VideoProgramSummary
    let episodes: [VideoProgramEpisode]
    let nextCursor: String?
    let hasMore: Bool

    func appendingEpisodes(
        to existing: [VideoProgramEpisode]
    ) throws -> [VideoProgramEpisode] {
        let existingIDs = Set(existing.map(\.id))
        guard episodes.allSatisfy({ !existingIDs.contains($0.id) }) else {
            throw SportsDataError.contractViolation(field: "data.episodes.id")
        }
        return existing + episodes
    }
}

struct SportsVideoDetails: Codable, Hashable, Sendable {
    let video: SportsVideo
    let publishedAt: Date?
    let audioLanguages: [String]
    let subtitleLanguages: [String]
    let publisherArabic: String?
    let publisherEnglish: String?
    let program: VideoProgram?
    let relatedVideos: [SportsVideo]

    init(
        video: SportsVideo,
        publishedAt: Date?,
        audioLanguages: [String],
        subtitleLanguages: [String],
        publisherArabic: String? = nil,
        publisherEnglish: String? = nil,
        program: VideoProgram? = nil,
        relatedVideos: [SportsVideo] = []
    ) {
        self.video = video
        self.publishedAt = publishedAt
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
        self.publisherArabic = publisherArabic
        self.publisherEnglish = publisherEnglish
        self.program = program
        self.relatedVideos = relatedVideos
    }

    func publisher(in language: AppLanguage) -> String? {
        language == .arabic ? publisherArabic : publisherEnglish
    }
}

struct VideoDiscoveryItem: Hashable, Identifiable, Sendable {
    let video: SportsVideo
    let sport: VideoSport

    var id: String { video.id }
}

struct VideoDiscoveryFeed: Hashable, Sendable {
    let items: [VideoDiscoveryItem]
    let featuredVideoID: String?
    let trendingVideoIDs: [String]

    static let empty = VideoDiscoveryFeed(
        items: [],
        featuredVideoID: nil,
        trendingVideoIDs: []
    )
}

struct WatchProgress: Codable, Hashable, Identifiable, Sendable {
    let videoID: String
    let positionSeconds: Int
    let completed: Bool
    let updatedAt: Date

    var id: String { videoID }
}

struct ContinueWatchingItem: Codable, Hashable, Identifiable, Sendable {
    let video: SportsVideo
    let progress: WatchProgress

    var id: String { video.id }

    var fractionCompleted: Double {
        guard video.durationSeconds > 0 else { return 0 }
        return min(
            max(Double(progress.positionSeconds) / Double(video.durationSeconds), 0),
            1
        )
    }

    var percentageCompleted: Int {
        Int((fractionCompleted * 100).rounded())
    }

    var remainingSeconds: Int {
        max(video.durationSeconds - progress.positionSeconds, 0)
    }
}

struct WatchHistoryItem: Codable, Hashable, Identifiable, Sendable {
    let video: SportsVideo
    let progress: WatchProgress

    var id: String { video.id }

    var fractionCompleted: Double {
        guard video.durationSeconds > 0 else { return 0 }
        return min(
            max(Double(progress.positionSeconds) / Double(video.durationSeconds), 0),
            1
        )
    }

    var percentageCompleted: Int {
        Int((fractionCompleted * 100).rounded())
    }
}

enum FollowEntityType: String, CaseIterable, Codable, Hashable, Sendable {
    case team = "TEAM"
    case player = "PLAYER"
    case competition = "COMPETITION"

    var localizationKey: String {
        "following.type.\(rawValue.lowercased())"
    }
}

enum FollowEntitySnapshot: Codable, Hashable, Sendable {
    case team(Team)
    case player(PlayerProfile)
    case competition(Competition)

    private enum CodingKeys: String, CodingKey {
        case type
        case team
        case player
        case competition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FollowEntityType.self, forKey: .type)
        let team = try container.decodeIfPresent(Team.self, forKey: .team)
        let player = try container.decodeIfPresent(PlayerProfile.self, forKey: .player)
        let competition = try container.decodeIfPresent(Competition.self, forKey: .competition)
        switch type {
        case .team:
            guard let team, player == nil, competition == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "TEAM follow snapshot must contain only team."
                )
            }
            self = .team(team)
        case .player:
            guard team == nil, let player, competition == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "PLAYER follow snapshot must contain only player."
                )
            }
            self = .player(player)
        case .competition:
            guard team == nil, player == nil, let competition else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "COMPETITION follow snapshot must contain only competition."
                )
            }
            self = .competition(competition)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch self {
        case let .team(team):
            try container.encode(team, forKey: .team)
        case let .player(player):
            try container.encode(player, forKey: .player)
        case let .competition(competition):
            try container.encode(competition, forKey: .competition)
        }
    }

    var type: FollowEntityType {
        switch self {
        case .team: .team
        case .player: .player
        case .competition: .competition
        }
    }

    var entityID: String {
        switch self {
        case let .team(team): team.id
        case let .player(player): player.id
        case let .competition(competition): competition.id
        }
    }

    func displayName(in language: AppLanguage) -> String {
        switch self {
        case let .team(team): team.displayName(in: language)
        case let .player(player): player.name
        case let .competition(competition): competition.displayName(in: language)
        }
    }
}

struct SportsFollow: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let type: FollowEntityType
    let entityID: String
    let createdAt: Date
    let entity: FollowEntitySnapshot?

    init(
        id: String,
        type: FollowEntityType,
        entityID: String,
        createdAt: Date,
        entity: FollowEntitySnapshot? = nil
    ) {
        self.id = id
        self.type = type
        self.entityID = entityID
        self.createdAt = createdAt
        self.entity = entity
    }

    var hasMatchingEntitySnapshot: Bool {
        guard let entity else { return true }
        return entity.type == type && entity.entityID == entityID
    }
}

extension Sequence where Element == SportsFollow {
    var canonicalFollowOrder: [SportsFollow] {
        sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            if lhs.type.rawValue != rhs.type.rawValue {
                return lhs.type.rawValue < rhs.type.rawValue
            }
            return lhs.entityID < rhs.entityID
        }
    }
}

enum NotificationPreferenceType: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case breakingNews
    case lineup
    case kickoff
    case goal
    case yellowCard
    case redCard
    case substitution
    case halfTime
    case fullTime

    var id: String { rawValue }

    var localizationKey: String {
        "notifications.event.\(rawValue)"
    }
}

struct NotificationPreferences: Codable, Equatable, Sendable {
    let breakingNews: Bool
    let lineup: Bool
    let kickoff: Bool
    let goal: Bool
    let yellowCard: Bool
    let redCard: Bool
    let substitution: Bool
    let halfTime: Bool
    let fullTime: Bool

    static let allEnabled = NotificationPreferences(
        breakingNews: true,
        lineup: true,
        kickoff: true,
        goal: true,
        yellowCard: true,
        redCard: true,
        substitution: true,
        halfTime: true,
        fullTime: true
    )

    subscript(type: NotificationPreferenceType) -> Bool {
        switch type {
        case .breakingNews: breakingNews
        case .lineup: lineup
        case .kickoff: kickoff
        case .goal: goal
        case .yellowCard: yellowCard
        case .redCard: redCard
        case .substitution: substitution
        case .halfTime: halfTime
        case .fullTime: fullTime
        }
    }

    func setting(_ type: NotificationPreferenceType, enabled: Bool) -> Self {
        NotificationPreferences(
            breakingNews: type == .breakingNews ? enabled : breakingNews,
            lineup: type == .lineup ? enabled : lineup,
            kickoff: type == .kickoff ? enabled : kickoff,
            goal: type == .goal ? enabled : goal,
            yellowCard: type == .yellowCard ? enabled : yellowCard,
            redCard: type == .redCard ? enabled : redCard,
            substitution: type == .substitution ? enabled : substitution,
            halfTime: type == .halfTime ? enabled : halfTime,
            fullTime: type == .fullTime ? enabled : fullTime
        )
    }
}

enum PushNotificationEnvironment: String, Codable, Equatable, Sendable {
    case sandbox = "SANDBOX"
    case production = "PRODUCTION"
}

struct PushDeviceRegistration: Codable, Equatable, Sendable {
    let installationID: String
    let token: String
    let environment: PushNotificationEnvironment
    let locale: String
    let timeZone: String
}

struct VideoFavoriteState: Codable, Hashable, Sendable {
    let videoID: String
    let isFavorite: Bool
    let updatedAt: Date?
}

struct ArticleFavoriteState: Codable, Hashable, Sendable {
    let articleID: String
    let isFavorite: Bool
    let updatedAt: Date?
}

struct PlaybackCapabilities: Hashable, Sendable {
    let supportsFairPlay: Bool

    static let nativeHLS = PlaybackCapabilities(supportsFairPlay: false)
}

struct FairPlayConfiguration: Hashable, Sendable {
    let certificateURL: URL
    let licenseURL: URL
}

struct PlaybackSession: Hashable, Identifiable, Sendable {
    let id: String
    let videoID: String
    let hlsURL: URL
    let fairPlay: FairPlayConfiguration?
    let expiresAt: Date
    let allowsAirPlay: Bool
    let allowsPictureInPicture: Bool

    func isExpired(at date: Date = Date()) -> Bool {
        expiresAt <= date
    }
}

enum SearchEntityType: String, Codable, Hashable, Sendable {
    case article
    case video
    case team
    case player
    case competition

    var localizationKey: String {
        "search.type.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .article: "newspaper.fill"
        case .video: "play.rectangle.fill"
        case .team: "person.3.fill"
        case .player: "person.crop.circle.fill"
        case .competition: "trophy.fill"
        }
    }
}

struct SearchResultItem: Codable, Hashable, Identifiable, Sendable {
    let type: SearchEntityType
    let entityID: String
    let titleArabic: String
    let titleEnglish: String
    let subtitleArabic: String?
    let subtitleEnglish: String?

    var id: String { "\(type.rawValue):\(entityID)" }

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }

    func subtitle(in language: AppLanguage) -> String? {
        language == .arabic ? subtitleArabic : subtitleEnglish
    }
}

struct PlayerProfile: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let position: String
}

struct NamedStatistic: Codable, Hashable, Identifiable, Sendable {
    let name: String
    let value: Double

    var id: String { name }
}

struct TeamDetails: Codable, Hashable, Sendable {
    let team: Team
    let competitions: [Competition]
    let nextFixtures: [Fixture]
    let recentFixtures: [Fixture]
}

/// One bounded match-context row for the followed-team dashboard.
/// The service, rather than the client, selects the nearest eligible fixtures.
struct TeamMatchSnapshot: Codable, Hashable, Identifiable, Sendable {
    let team: Team
    let previousFixture: Fixture?
    let nextFixture: Fixture?

    var id: String { team.id }
}

/// Editorial metadata explicitly scoped by the service to one team channel.
/// The client must never infer this association from titles or free text.
struct TeamContent: Codable, Hashable, Sendable {
    let teamID: String
    let articles: [Article]
    let videos: [SportsVideo]
}

/// Editorial metadata explicitly scoped by the service to one player channel.
/// The client must never infer this association from names, teams, or free text.
struct PlayerContent: Codable, Hashable, Sendable {
    let playerID: String
    let articles: [Article]
    let videos: [SportsVideo]
}

/// Editorial metadata explicitly scoped by the service to one competition channel.
/// The association is season-independent and must be authored by the provider.
struct CompetitionContent: Codable, Hashable, Sendable {
    let competitionID: String
    let articles: [Article]
    let videos: [SportsVideo]
}

/// One provider-authored video moment explicitly associated with a fixture.
/// The embedded video remains rights-filtered metadata and grants no playback.
struct FixtureContentMoment: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let titleArabic: String
    let titleEnglish: String
    let minute: Int?
    let video: SportsVideo

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }
}

/// Bounded editorial metadata explicitly scoped by the service to one fixture.
/// Clients must preserve provider order and never infer fixture association from text.
struct FixtureContent: Codable, Hashable, Sendable {
    let fixtureID: String
    let moments: [FixtureContentMoment]
    let articles: [Article]
}

struct PlayerDetails: Codable, Hashable, Sendable {
    let player: PlayerProfile
    let currentTeam: Team?
    let statistics: [NamedStatistic]
}

enum TransferStatus: String, Codable, Hashable, Sendable {
    case rumored
    case agreed
    case completed

    var localizationKey: String {
        "transfer.status.\(rawValue)"
    }
}

struct PlayerTransfer: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let player: PlayerProfile
    let fromTeam: Team?
    let toTeam: Team?
    let transferDate: Date
    let status: TransferStatus
}

struct TransferPage: Equatable, Sendable {
    let transfers: [PlayerTransfer]
    let nextCursor: String?
    let hasMore: Bool
}

enum StandingFormResult: String, Codable, Hashable, Sendable {
    case win
    case draw
    case loss

    var localizationKey: String {
        "standings.form.\(rawValue)"
    }
}

struct StandingRow: Codable, Hashable, Identifiable, Sendable {
    let rank: Int
    let team: Team
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let points: Int
    let form: [StandingFormResult]

    var id: String { team.id }
    var goalDifference: Int { goalsFor - goalsAgainst }
}

struct StandingGroup: Codable, Hashable, Identifiable, Sendable {
    let groupNameArabic: String
    let groupNameEnglish: String
    let rows: [StandingRow]

    var id: String { "\(groupNameEnglish):\(rows.map(\.team.id).joined(separator: ","))" }

    func displayName(in language: AppLanguage) -> String {
        language == .arabic ? groupNameArabic : groupNameEnglish
    }
}

struct FixtureStandingsContext: Codable, Hashable, Sendable {
    let fixtureID: String
    let competition: Competition
    let season: Season
    let groups: [StandingGroup]
    let sourceName: String
    let updatedAt: Date
}

struct HeadToHeadRecord: Codable, Hashable, Sendable {
    let wins: Int
    let draws: Int
    let losses: Int

    var total: Int { wins + draws + losses }
}

struct FixtureHeadToHeadContext: Codable, Hashable, Sendable {
    let fixtureID: String
    let homeTeam: Team
    let awayTeam: Team
    let meetings: [Fixture]
    let sourceName: String
    let updatedAt: Date

    func record(for teamID: String) -> HeadToHeadRecord {
        guard teamID == homeTeam.id || teamID == awayTeam.id else {
            return HeadToHeadRecord(wins: 0, draws: 0, losses: 0)
        }
        return meetings.reduce(into: HeadToHeadRecord(wins: 0, draws: 0, losses: 0)) {
            record, meeting in
            guard let homeScore = meeting.homeScore,
                  let awayScore = meeting.awayScore else {
                return
            }
            if homeScore == awayScore {
                record = HeadToHeadRecord(
                    wins: record.wins,
                    draws: record.draws + 1,
                    losses: record.losses
                )
                return
            }
            let teamWon = (meeting.homeTeam.id == teamID && homeScore > awayScore)
                || (meeting.awayTeam.id == teamID && awayScore > homeScore)
            record = HeadToHeadRecord(
                wins: record.wins + (teamWon ? 1 : 0),
                draws: record.draws,
                losses: record.losses + (teamWon ? 0 : 1)
            )
        }
    }
}

enum CompetitionLeaderCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case goals
    case assists
    case yellowCards
    case redCards

    var id: String { rawValue }
    var localizationKey: String { "leaders.\(rawValue)" }

    var apiValue: String {
        switch self {
        case .goals: "GOALS"
        case .assists: "ASSISTS"
        case .yellowCards: "YELLOW_CARDS"
        case .redCards: "RED_CARDS"
        }
    }
}

struct CompetitionLeader: Codable, Hashable, Identifiable, Sendable {
    let rank: Int
    let player: PlayerProfile
    let team: Team
    let value: Double

    var id: String { "\(rank):\(player.id):\(team.id)" }
}

enum FixtureEventKind: String, Codable, Hashable, Sendable {
    case kickoff
    case goal
    case ownGoal
    case penalty
    case yellowCard
    case redCard
    case substitution
    case halfTime
    case fullTime
    case varReview
}

struct FixtureEvent: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let revision: Int
    let minute: Int
    let addedTime: Int?
    let kind: FixtureEventKind
    let titleArabic: String
    let titleEnglish: String
    let detailArabic: String
    let detailEnglish: String
    let teamID: String?
    let playerID: String?
    let secondaryPlayerID: String?

    init(
        id: String,
        revision: Int = 0,
        minute: Int,
        addedTime: Int? = nil,
        kind: FixtureEventKind,
        titleArabic: String,
        titleEnglish: String,
        detailArabic: String,
        detailEnglish: String,
        teamID: String? = nil,
        playerID: String? = nil,
        secondaryPlayerID: String? = nil
    ) {
        self.id = id
        self.revision = revision
        self.minute = minute
        self.addedTime = addedTime
        self.kind = kind
        self.titleArabic = titleArabic
        self.titleEnglish = titleEnglish
        self.detailArabic = detailArabic
        self.detailEnglish = detailEnglish
        self.teamID = teamID
        self.playerID = playerID
        self.secondaryPlayerID = secondaryPlayerID
    }

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }

    func detail(in language: AppLanguage) -> String {
        language == .arabic ? detailArabic : detailEnglish
    }
}

struct LineupPlayer: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let number: Int
    let name: String
    let positionKey: String
    let isStarter: Bool
    let formationPosition: FormationPosition?

    init(
        id: String,
        number: Int,
        name: String,
        positionKey: String,
        isStarter: Bool = true,
        formationPosition: FormationPosition? = nil
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.positionKey = positionKey
        self.isStarter = isStarter
        self.formationPosition = formationPosition
    }
}

struct FormationPosition: Codable, Hashable, Sendable {
    let line: Int
    let order: Int
}

struct TeamLineup: Codable, Hashable, Sendable {
    let formation: String?
    let players: [LineupPlayer]

    var isEmpty: Bool { players.isEmpty }

    var starters: [LineupPlayer] {
        players
            .filter(\.isStarter)
            .sorted(by: Self.playerOrder)
    }

    var substitutes: [LineupPlayer] {
        players
            .filter { !$0.isStarter }
            .sorted { lhs, rhs in
                if lhs.number != rhs.number { return lhs.number < rhs.number }
                return lhs.id < rhs.id
            }
    }

    var hasCompleteStartingEleven: Bool { starters.count == 11 }

    /// Ordered goalkeeper-to-attack lines for a supplemental visual pitch.
    /// The text lists remain the semantic source of truth.
    var pitchLines: [[LineupPlayer]]? {
        let starters = starters
        guard starters.count == 11,
              let formation,
              let components = Self.formationComponents(for: formation),
              starters.filter({ $0.positionKey == "position.goalkeeper" }).count == 1,
              starters.allSatisfy({ $0.formationPosition != nil }) else {
            return nil
        }

        let grouped = Dictionary(grouping: starters) { $0.formationPosition?.line ?? -1 }
        guard grouped.keys.allSatisfy({ (0...components.count).contains($0) }),
              let goalkeeperLine = grouped[0],
              goalkeeperLine.count == 1,
              goalkeeperLine[0].positionKey == "position.goalkeeper",
              goalkeeperLine[0].formationPosition?.order == 0 else {
            return nil
        }

        var lines = [goalkeeperLine]
        for (index, expectedCount) in components.enumerated() {
            guard let players = grouped[index + 1],
                  players.count == expectedCount else {
                return nil
            }
            let ordered = players.sorted(by: Self.playerOrder)
            guard ordered.compactMap({ $0.formationPosition?.order }) == Array(0..<expectedCount) else {
                return nil
            }
            lines.append(ordered)
        }
        return lines
    }

    static func formationComponents(for value: String) -> [Int]? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard (2...4).contains(parts.count) else { return nil }
        let components = parts.compactMap { Int($0) }
        guard components.count == parts.count,
              components.allSatisfy({ (1...5).contains($0) }),
              components.reduce(0, +) == 10 else {
            return nil
        }
        return components
    }

    private static func playerOrder(_ lhs: LineupPlayer, _ rhs: LineupPlayer) -> Bool {
        switch (lhs.formationPosition, rhs.formationPosition) {
        case let (.some(left), .some(right)):
            if left.line != right.line { return left.line < right.line }
            if left.order != right.order { return left.order < right.order }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }
        if lhs.number != rhs.number { return lhs.number < rhs.number }
        return lhs.id < rhs.id
    }
}

struct MatchStatistic: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let titleKey: String
    let homeValue: Double
    let awayValue: Double
    let unit: String
}

struct MatchDetails: Codable, Hashable, Sendable {
    let fixture: Fixture
    let events: [FixtureEvent]
    let homeLineup: TeamLineup
    let awayLineup: TeamLineup
    let statistics: [MatchStatistic]
    let sourceName: String
    let updatedAt: Date
}

struct HomeFeed: Codable, Hashable, Sendable {
    let fixtures: [Fixture]
    let articles: [Article]
}

enum PredictionGameState: String, Codable, Hashable, Sendable {
    case open
    case locked
    case settled
    case cancelled

    var localizationKey: String {
        "predictions.state.\(rawValue)"
    }
}

struct PredictionGroup: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let nameArabic: String
    let nameEnglish: String
    let teams: [Team]
    let qualifyingPositions: Int

    func displayName(in language: AppLanguage) -> String {
        language == .arabic ? nameArabic : nameEnglish
    }
}

struct PredictionGame: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let titleArabic: String
    let titleEnglish: String
    let summaryArabic: String
    let summaryEnglish: String
    let lockAt: Date
    let state: PredictionGameState
    let rulesURL: URL?
    let groups: [PredictionGroup]

    func title(in language: AppLanguage) -> String {
        language == .arabic ? titleArabic : titleEnglish
    }

    func summary(in language: AppLanguage) -> String {
        language == .arabic ? summaryArabic : summaryEnglish
    }

    func isEditable(at date: Date) -> Bool {
        effectiveState(at: date) == .open
    }

    func effectiveState(at date: Date) -> PredictionGameState {
        state == .open && date >= lockAt ? .locked : state
    }
}

struct PredictionGroupRanking: Codable, Hashable, Sendable {
    let groupID: String
    let orderedTeamIDs: [String]
}

struct PredictionEntry: Codable, Hashable, Sendable {
    let gameID: String
    let rankings: [PredictionGroupRanking]
    let updatedAt: Date
}

enum PredictionEntryContract {
    static func validate(
        _ rankings: [PredictionGroupRanking],
        for game: PredictionGame
    ) throws {
        guard rankings.count == game.groups.count,
              Set(rankings.map(\.groupID)).count == rankings.count else {
            throw SportsDataError.contractViolation(field: "predictionEntry.rankings")
        }
        for (index, group) in game.groups.enumerated() {
            let ranking = rankings[index]
            let expectedTeamIDs = group.teams.map(\.id)
            guard ranking.groupID == group.id,
                  ranking.orderedTeamIDs.count == expectedTeamIDs.count,
                  Set(ranking.orderedTeamIDs).count == ranking.orderedTeamIDs.count,
                  Set(ranking.orderedTeamIDs) == Set(expectedTeamIDs) else {
                throw SportsDataError.contractViolation(
                    field: "predictionEntry.rankings[\(index)]"
                )
            }
        }
    }
}
