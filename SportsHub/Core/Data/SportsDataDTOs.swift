import Foundation

struct LocalizedTextDTO: Decodable, Sendable {
    let ar: String
    let en: String

    func validated(field: String) throws -> (arabic: String, english: String) {
        let arabic = ar.trimmingCharacters(in: .whitespacesAndNewlines)
        let english = en.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !arabic.isEmpty else {
            throw SportsDataError.contractViolation(field: "\(field).ar")
        }
        guard !english.isEmpty else {
            throw SportsDataError.contractViolation(field: "\(field).en")
        }
        return (arabic, english)
    }
}

struct PageInfoDTO: Decodable, Sendable {
    let nextCursor: String?
    let hasMore: Bool
}

enum SportDTO: String, Decodable, Sendable {
    case football = "FOOTBALL"
    case basketball = "BASKETBALL"
    case esports = "ESPORTS"
    case motorsport = "MOTORSPORT"
    case combat = "COMBAT"
    case archery = "ARCHERY"

    var videoDomain: VideoSport {
        switch self {
        case .football: .football
        case .basketball: .basketball
        case .esports: .esports
        case .motorsport: .motorsport
        case .combat: .combat
        case .archery: .archery
        }
    }
}

struct TeamDTO: Decodable, Sendable {
    let id: String
    let name: LocalizedTextDTO
    let monogram: String
    let accentColorHex: String?

    func domain(field: String) throws -> Team {
        let id = try validatedIdentifier(id, field: "\(field).id")
        let names = try name.validated(field: "\(field).name")
        let monogram = monogram.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...5).contains(monogram.count) else {
            throw SportsDataError.contractViolation(field: "\(field).monogram")
        }

        let color = accentColorHex ?? "455A64"
        guard color.count == 6, color.allSatisfy({ $0.isHexDigit }) else {
            throw SportsDataError.contractViolation(field: "\(field).accentColorHex")
        }

        return Team(
            id: id,
            nameArabic: names.arabic,
            nameEnglish: names.english,
            monogram: monogram,
            colorHex: color.uppercased()
        )
    }
}

struct CompetitionDTO: Decodable, Sendable {
    let id: String
    let name: LocalizedTextDTO
    let sport: SportDTO
    let currentSeasonId: String?
    let seasons: [SeasonDTO]?

    func domain(field: String) throws -> Competition {
        let id = try validatedIdentifier(id, field: "\(field).id")
        let names = try name.validated(field: "\(field).name")
        let seasonDTOs = seasons ?? []
        guard seasonDTOs.count <= CompetitionSeasonCatalogContract.maximumSeasonCount else {
            throw SportsDataError.contractViolation(field: "\(field).seasons")
        }
        let seasons = try seasonDTOs.enumerated().map {
            try $0.element.domain(field: "\(field).seasons[\($0.offset)]")
        }
        let currentSeasonID: String?
        if let currentSeasonId {
            currentSeasonID = try validatedIdentifier(
                currentSeasonId,
                field: "\(field).currentSeasonId"
            )
        } else {
            currentSeasonID = nil
        }
        try CompetitionSeasonCatalogContract.validate(
            seasons: seasons,
            currentSeasonID: currentSeasonID,
            field: field
        )
        return Competition(
            id: id,
            nameArabic: names.arabic,
            nameEnglish: names.english,
            currentSeasonID: currentSeasonID,
            seasons: seasons
        )
    }
}

struct SeasonDTO: Decodable, Sendable {
    let id: String
    let name: LocalizedTextDTO
    let startDate: Date
    let endDate: Date
    let isCurrent: Bool

    func domain(field: String) throws -> Season {
        let id = try validatedIdentifier(id, field: "\(field).id")
        let name = try name.validated(field: "\(field).name")
        guard startDate < endDate else {
            throw SportsDataError.contractViolation(field: "\(field).startDate")
        }
        return Season(
            id: id,
            nameArabic: name.arabic,
            nameEnglish: name.english,
            startDate: startDate,
            endDate: endDate,
            isCurrent: isCurrent
        )
    }
}

enum FixtureStateDTO: String, Decodable, Sendable {
    case scheduled = "SCHEDULED"
    case live = "LIVE"
    case halfTime = "HALF_TIME"
    case finished = "FINISHED"
    case postponed = "POSTPONED"
    case cancelled = "CANCELLED"

    var domain: FixtureState {
        switch self {
        case .scheduled: .upcoming
        case .live: .live
        case .halfTime: .halfTime
        case .finished: .finished
        case .postponed: .postponed
        case .cancelled: .cancelled
        }
    }
}

struct ScoreDTO: Decodable, Sendable {
    let home: Int
    let away: Int
}

struct FixtureBroadcastDTO: Decodable, Sendable {
    let regionCode: String
    let channel: LocalizedTextDTO
    let commentator: LocalizedTextDTO?
    let audioLanguageCode: String?

    func domain(field: String) throws -> FixtureBroadcast {
        let trimmedRegionCode = regionCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard regionCode == trimmedRegionCode,
              regionCode.utf8.count == 2,
              regionCode.utf8.allSatisfy({ (65...90).contains($0) }) else {
            throw SportsDataError.contractViolation(field: "\(field).regionCode")
        }
        let channel = try validatedBroadcastText(channel, field: "\(field).channel")
        let commentator = try commentator.map {
            try validatedBroadcastText($0, field: "\(field).commentator")
        }
        let audioLanguageCode = try validatedBroadcastLanguageCode(
            audioLanguageCode,
            field: "\(field).audioLanguageCode"
        )
        return FixtureBroadcast(
            regionCode: regionCode,
            channelArabic: channel.arabic,
            channelEnglish: channel.english,
            commentatorArabic: commentator?.arabic,
            commentatorEnglish: commentator?.english,
            audioLanguageCode: audioLanguageCode
        )
    }
}

struct FixtureDTO: Decodable, Sendable {
    let id: String
    let competition: CompetitionDTO
    let homeTeam: TeamDTO
    let awayTeam: TeamDTO
    let kickoffAt: Date
    let state: FixtureStateDTO
    let minute: Int?
    let score: ScoreDTO?
    let venue: LocalizedTextDTO
    let broadcasts: [FixtureBroadcastDTO]?
    let revision: Int

    func domain(field: String) throws -> Fixture {
        let id = try validatedIdentifier(id, field: "\(field).id")
        guard revision >= 0 else {
            throw SportsDataError.contractViolation(field: "\(field).revision")
        }
        if let minute, !(0...200).contains(minute) {
            throw SportsDataError.contractViolation(field: "\(field).minute")
        }
        if let score, score.home < 0 || score.away < 0 {
            throw SportsDataError.contractViolation(field: "\(field).score")
        }

        let venue = try venue.validated(field: "\(field).venue")
        let fixtureState = state.domain
        let broadcasts = try validatedFixtureBroadcasts(
            broadcasts ?? [],
            fixtureState: fixtureState,
            field: "\(field).broadcasts"
        )
        return Fixture(
            id: id,
            competition: try competition.domain(field: "\(field).competition"),
            homeTeam: try homeTeam.domain(field: "\(field).homeTeam"),
            awayTeam: try awayTeam.domain(field: "\(field).awayTeam"),
            kickoff: kickoffAt,
            state: fixtureState,
            minute: minute,
            homeScore: score?.home,
            awayScore: score?.away,
            venueArabic: venue.arabic,
            venueEnglish: venue.english,
            broadcasts: broadcasts,
            revision: revision
        )
    }
}

private func validatedFixtureBroadcasts(
    _ broadcasts: [FixtureBroadcastDTO],
    fixtureState: FixtureState,
    field: String
) throws -> [FixtureBroadcast] {
    guard broadcasts.count <= 12,
          !([FixtureState.postponed, .cancelled].contains(fixtureState) && !broadcasts.isEmpty)
    else {
        throw SportsDataError.contractViolation(field: field)
    }
    var identities = Set<String>()
    return try broadcasts.enumerated().map { index, broadcast in
        let domain = try broadcast.domain(field: "\(field)[\(index)]")
        let identity = [
            domain.regionCode,
            domain.channelArabic,
            domain.channelEnglish,
            domain.commentatorArabic ?? "",
            domain.commentatorEnglish ?? "",
            domain.audioLanguageCode ?? ""
        ]
        .map {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .lowercased(with: Locale(identifier: "en_US_POSIX"))
        }
        .joined(separator: "\u{1F}")
        guard identities.insert(identity).inserted else {
            throw SportsDataError.contractViolation(field: "\(field)[\(index)]")
        }
        return domain
    }
}

private func validatedBroadcastText(
    _ text: LocalizedTextDTO,
    field: String
) throws -> (arabic: String, english: String) {
    let text = try text.validated(field: field)
    guard text.arabic.count <= 100,
          text.english.count <= 100,
          text.arabic.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }),
          text.english.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }) else {
        throw SportsDataError.contractViolation(field: field)
    }
    return text
}

private func validatedBroadcastLanguageCode(
    _ value: String?,
    field: String
) throws -> String? {
    guard let value else { return nil }
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value == trimmedValue else {
        throw SportsDataError.contractViolation(field: field)
    }
    let components = value.split(separator: "-", omittingEmptySubsequences: false)
    guard (1...2).contains(components.count),
          (2...3).contains(components[0].utf8.count),
          components[0].utf8.allSatisfy({ (97...122).contains($0) }) else {
        throw SportsDataError.contractViolation(field: field)
    }
    if components.count == 2 {
        guard components[1].utf8.count == 2,
              components[1].utf8.allSatisfy({ (65...90).contains($0) }) else {
            throw SportsDataError.contractViolation(field: field)
        }
    }
    return value
}

enum ArticleCategoryDTO: String, Decodable, Sendable {
    case breaking = "BREAKING"
    case analysis = "ANALYSIS"
    case statistics = "STATISTICS"
    case transfers = "TRANSFERS"
    case interview = "INTERVIEW"
    case matchReport = "MATCH_REPORT"

    var localizationKey: String {
        switch self {
        case .breaking: "category.breaking"
        case .analysis: "category.analysis"
        case .statistics: "category.statistics"
        case .transfers: "category.transfers"
        case .interview: "category.interview"
        case .matchReport: "category.matchReport"
        }
    }
}

enum ArticleCorrectionStatusDTO: String, Decodable, Sendable {
    case original = "ORIGINAL"
    case corrected = "CORRECTED"
}

enum ArticleFormatDTO: String, Decodable, Sendable {
    case story = "STORY"
    case visualBrief = "VISUAL_BRIEF"

    var domain: ArticleFormat {
        switch self {
        case .story: .story
        case .visualBrief: .visualBrief
        }
    }
}

enum ArticleVisualSectionKindDTO: String, Decodable, Sendable {
    case metricGrid = "METRIC_GRID"
    case comparison = "COMPARISON"
    case sequence = "SEQUENCE"

    var domain: ArticleVisualSectionKind {
        switch self {
        case .metricGrid: .metricGrid
        case .comparison: .comparison
        case .sequence: .sequence
        }
    }
}

struct ArticleVisualItemDTO: Decodable, Sendable {
    let id: String
    let value: LocalizedTextDTO
    let label: LocalizedTextDTO
    let detail: LocalizedTextDTO?

    func domain(field: String) throws -> ArticleVisualItem {
        let id = try validatedFollowIdentifier(id, field: "\(field).id")
        let value = try validatedArticleVisualText(
            value,
            maximumLength: 32,
            field: "\(field).value"
        )
        let label = try validatedArticleVisualText(
            label,
            maximumLength: 80,
            field: "\(field).label"
        )
        let detail = try detail.map {
            try validatedArticleVisualText($0, maximumLength: 160, field: "\(field).detail")
        }
        return ArticleVisualItem(
            id: id,
            valueArabic: value.arabic,
            valueEnglish: value.english,
            labelArabic: label.arabic,
            labelEnglish: label.english,
            detailArabic: detail?.arabic,
            detailEnglish: detail?.english
        )
    }
}

struct ArticleVisualSectionDTO: Decodable, Sendable {
    let id: String
    let kind: ArticleVisualSectionKindDTO
    let title: LocalizedTextDTO
    let items: [ArticleVisualItemDTO]

    func domain(field: String) throws -> ArticleVisualSection {
        let id = try validatedFollowIdentifier(id, field: "\(field).id")
        let title = try validatedArticleVisualText(
            title,
            maximumLength: 100,
            field: "\(field).title"
        )
        let validItemCount: Bool
        switch kind {
        case .comparison:
            validItemCount = items.count == 2
        case .metricGrid, .sequence:
            validItemCount = (2...6).contains(items.count)
        }
        guard validItemCount else {
            throw SportsDataError.contractViolation(field: "\(field).items")
        }
        let items = try items.enumerated().map {
            try $0.element.domain(field: "\(field).items[\($0.offset)]")
        }
        return ArticleVisualSection(
            id: id,
            kind: kind.domain,
            titleArabic: title.arabic,
            titleEnglish: title.english,
            items: items
        )
    }
}

struct ArticleVisualBriefDTO: Decodable, Sendable {
    let title: LocalizedTextDTO
    let sourceNote: LocalizedTextDTO
    let sections: [ArticleVisualSectionDTO]

    func domain(field: String) throws -> ArticleVisualBrief {
        guard (1...4).contains(sections.count) else {
            throw SportsDataError.contractViolation(field: "\(field).sections")
        }
        let title = try validatedArticleVisualText(
            title,
            maximumLength: 100,
            field: "\(field).title"
        )
        let sourceNote = try validatedArticleVisualText(
            sourceNote,
            maximumLength: 200,
            field: "\(field).sourceNote"
        )
        let sections = try sections.enumerated().map {
            try $0.element.domain(field: "\(field).sections[\($0.offset)]")
        }
        guard Set(sections.map(\.id)).count == sections.count else {
            throw SportsDataError.contractViolation(field: "\(field).sections.id")
        }
        let itemIDs = sections.flatMap { $0.items.map(\.id) }
        guard Set(itemIDs).count == itemIDs.count else {
            throw SportsDataError.contractViolation(field: "\(field).sections.items.id")
        }
        return ArticleVisualBrief(
            titleArabic: title.arabic,
            titleEnglish: title.english,
            sourceNoteArabic: sourceNote.arabic,
            sourceNoteEnglish: sourceNote.english,
            sections: sections
        )
    }
}

private func validatedArticleVisualText(
    _ text: LocalizedTextDTO,
    maximumLength: Int,
    field: String
) throws -> (arabic: String, english: String) {
    let text = try text.validated(field: field)
    guard text.arabic.unicodeScalars.count <= maximumLength,
          text.english.unicodeScalars.count <= maximumLength,
          text.arabic.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }),
          text.english.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }) else {
        throw SportsDataError.contractViolation(field: field)
    }
    return text
}

private func validatedEditorialMediaIdentifier(_ value: String, field: String) throws -> String {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1...128).contains(value.unicodeScalars.count),
          value.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }) else {
        throw SportsDataError.contractViolation(field: field)
    }
    return value
}

private func validatedEditorialMediaText(
    _ text: LocalizedTextDTO,
    maximumLength: Int,
    field: String
) throws -> (arabic: String, english: String) {
    let text = try text.validated(field: field)
    guard text.arabic.unicodeScalars.count <= maximumLength,
          text.english.unicodeScalars.count <= maximumLength,
          text.arabic.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }),
          text.english.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }) else {
        throw SportsDataError.contractViolation(field: field)
    }
    return text
}

private func validatedEditorialMediaURL(_ url: URL, field: String) throws -> URL {
    guard url.absoluteString.unicodeScalars.count <= 2_048,
          url.scheme?.lowercased() == "https",
          let host = url.host,
          !host.isEmpty,
          url.user == nil,
          url.password == nil,
          url.port == nil,
          url.fragment == nil,
          !url.path.isEmpty,
          url.path != "/" else {
        throw SportsDataError.contractViolation(field: field)
    }
    return url
}

struct ArticleEngagementSummaryDTO: Decodable, Sendable {
    let totalReactions: Int
    let publishedComments: Int

    func domain(field: String) throws -> ArticleEngagementSummary {
        guard (0...ArticleEngagementSummary.maximumCount).contains(totalReactions) else {
            throw SportsDataError.contractViolation(field: "\(field).totalReactions")
        }
        guard (0...ArticleEngagementSummary.maximumCount).contains(publishedComments) else {
            throw SportsDataError.contractViolation(field: "\(field).publishedComments")
        }
        return ArticleEngagementSummary(
            totalReactions: totalReactions,
            publishedComments: publishedComments
        )
    }
}

struct ArticleHeroMediaDTO: Decodable, Sendable {
    let id: String
    let url: URL
    let contentType: String
    let width: Int
    let height: Int
    let altText: LocalizedTextDTO
    let credit: LocalizedTextDTO

    func domain(field: String) throws -> ArticleHeroMedia {
        let id = try validatedEditorialMediaIdentifier(id, field: "\(field).id")
        let url = try validatedEditorialMediaURL(url, field: "\(field).url")
        guard let contentType = ArticleHeroMediaContentType(rawValue: contentType) else {
            throw SportsDataError.contractViolation(field: "\(field).contentType")
        }
        guard (640...4_096).contains(width) else {
            throw SportsDataError.contractViolation(field: "\(field).width")
        }
        guard (360...4_096).contains(height) else {
            throw SportsDataError.contractViolation(field: "\(field).height")
        }
        let pixels = width.multipliedReportingOverflow(by: height)
        guard !pixels.overflow, pixels.partialValue <= 16_000_000 else {
            throw SportsDataError.contractViolation(field: "\(field).dimensions")
        }
        let aspectRatio = Double(width) / Double(height)
        guard (1.2...2.4).contains(aspectRatio) else {
            throw SportsDataError.contractViolation(field: "\(field).aspectRatio")
        }
        let altText = try validatedEditorialMediaText(
            altText,
            maximumLength: 180,
            field: "\(field).altText"
        )
        let credit = try validatedEditorialMediaText(
            credit,
            maximumLength: 120,
            field: "\(field).credit"
        )
        return ArticleHeroMedia(
            id: id,
            url: url,
            contentType: contentType,
            width: width,
            height: height,
            altArabic: altText.arabic,
            altEnglish: altText.english,
            creditArabic: credit.arabic,
            creditEnglish: credit.english
        )
    }
}

struct ArticleDTO: Decodable, Sendable {
    let id: String
    let title: LocalizedTextDTO
    let summary: LocalizedTextDTO
    let source: String
    let publishedAt: Date
    let category: ArticleCategoryDTO
    let format: ArticleFormatDTO?
    let correctionStatus: ArticleCorrectionStatusDTO?
    let engagement: ArticleEngagementSummaryDTO?
    let heroMedia: ArticleHeroMediaDTO?

    func domain(field: String) throws -> Article {
        let id = try validatedIdentifier(id, field: "\(field).id")
        let titles = try title.validated(field: "\(field).title")
        let summaries = try summary.validated(field: "\(field).summary")
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            throw SportsDataError.contractViolation(field: "\(field).source")
        }

        return Article(
            id: id,
            titleArabic: titles.arabic,
            titleEnglish: titles.english,
            summaryArabic: summaries.arabic,
            summaryEnglish: summaries.english,
            source: source,
            publishedAt: publishedAt,
            categoryKey: category.localizationKey,
            format: (format ?? .story).domain,
            isCorrected: correctionStatus == .corrected,
            engagement: try engagement?.domain(field: "\(field).engagement"),
            heroMedia: try heroMedia?.domain(field: "\(field).heroMedia")
        )
    }
}

struct ArticleListResponseDTO: Decodable, Sendable {
    let data: [ArticleDTO]
    let page: PageInfoDTO

    func domain() throws -> [Article] {
        try data.enumerated().map { try $0.element.domain(field: "data[\($0.offset)]") }
    }
}

struct ArticleDetailResponseDTO: Decodable, Sendable {
    let data: ArticleDetailDataDTO
}

struct ArticleDetailDataDTO: Decodable, Sendable {
    let id: String
    let title: LocalizedTextDTO
    let summary: LocalizedTextDTO
    let source: String
    let publishedAt: Date
    let category: ArticleCategoryDTO
    let format: ArticleFormatDTO?
    let correctionStatus: ArticleCorrectionStatusDTO?
    let engagement: ArticleEngagementSummaryDTO?
    let heroMedia: ArticleHeroMediaDTO?
    let body: LocalizedTextDTO
    let revision: Int
    let visualBrief: ArticleVisualBriefDTO?

    func domain() throws -> ArticleDetails {
        guard revision >= 1 else {
            throw SportsDataError.contractViolation(field: "data.revision")
        }
        let article = try ArticleDTO(
            id: id,
            title: title,
            summary: summary,
            source: source,
            publishedAt: publishedAt,
            category: category,
            format: format,
            correctionStatus: correctionStatus,
            engagement: engagement,
            heroMedia: heroMedia
        ).domain(field: "data")
        let body = try body.validated(field: "data.body")
        let visualBrief: ArticleVisualBrief?
        switch article.format {
        case .story:
            guard self.visualBrief == nil else {
                throw SportsDataError.contractViolation(field: "data.visualBrief")
            }
            visualBrief = nil
        case .visualBrief:
            guard let payload = self.visualBrief else {
                throw SportsDataError.contractViolation(field: "data.visualBrief")
            }
            visualBrief = try payload.domain(field: "data.visualBrief")
        }
        return ArticleDetails(
            article: article,
            bodyArabic: body.arabic,
            bodyEnglish: body.english,
            revision: revision,
            visualBrief: visualBrief
        )
    }
}

struct ArticleCommentDTO: Decodable, Sendable {
    let id: String
    let articleId: String
    let body: String
    let authorId: String
    let authorDisplayName: String
    let moderationState: CommentModerationState
    let isMine: Bool
    let createdAt: Date

    func domain(
        field: String,
        expectedArticleID: String,
        publishedOnly: Bool,
        now: Date
    ) throws -> ArticleComment {
        let id = try validatedIdentifier(id, field: "\(field).id")
        let articleID = try validatedIdentifier(articleId, field: "\(field).articleId")
        let authorID = try validatedIdentifier(authorId, field: "\(field).authorId")
        guard articleID == expectedArticleID else {
            throw SportsDataError.contractViolation(field: "\(field).articleId")
        }
        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorDisplayName = authorDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowedBodyControls = CharacterSet(charactersIn: "\n\t")
        guard (1...500).contains(body.count),
              body.unicodeScalars.allSatisfy({ scalar in
                  !CharacterSet.controlCharacters.contains(scalar)
                      || allowedBodyControls.contains(scalar)
              }),
              (1...80).contains(authorDisplayName.count),
              authorDisplayName.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }),
              createdAt <= now.addingTimeInterval(5 * 60),
              !publishedOnly || moderationState == .published else {
            throw SportsDataError.contractViolation(field: field)
        }
        return ArticleComment(
            id: id,
            articleID: articleID,
            body: body,
            authorID: authorID,
            authorDisplayName: authorDisplayName,
            moderationState: moderationState,
            isMine: isMine,
            createdAt: createdAt
        )
    }
}

struct ArticleCommentListResponseDTO: Decodable, Sendable {
    let data: [ArticleCommentDTO]
    let page: PageInfoDTO

    func domain(
        expectedArticleID: String,
        limit: Int,
        now: Date
    ) throws -> ArticleCommentPage {
        guard data.count <= limit else {
            throw SportsDataError.contractViolation(field: "data")
        }
        let comments = try data.enumerated().map {
            try $0.element.domain(
                field: "data[\($0.offset)]",
                expectedArticleID: expectedArticleID,
                publishedOnly: true,
                now: now
            )
        }
        guard Set(comments.map(\.id)).count == comments.count else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        guard zip(comments, comments.dropFirst()).allSatisfy({ current, next in
            current.createdAt >= next.createdAt
        }) else {
            throw SportsDataError.contractViolation(field: "data.createdAt")
        }
        return ArticleCommentPage(
            comments: comments,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }
}

struct ArticleCommentResponseDTO: Decodable, Sendable {
    let data: ArticleCommentDTO
}

struct CreateArticleCommentInputDTO: Encodable, Sendable {
    let body: String
}

struct ArticleReactionResponseDTO: Decodable, Sendable {
    let data: ArticleReactionDataDTO
}

struct ArticleReactionDataDTO: Decodable, Sendable {
    let myReaction: ArticleReaction?
    let totals: [String: Int]

    func domain() throws -> ArticleReactionSummary {
        let expected = Set(ArticleReaction.allCases.map(\.rawValue))
        guard Set(totals.keys) == expected,
              totals.values.allSatisfy({ $0 >= 0 }) else {
            throw SportsDataError.contractViolation(field: "data.totals")
        }
        let mapped = Dictionary(uniqueKeysWithValues: try totals.map { key, value in
            guard let reaction = ArticleReaction(rawValue: key) else {
                throw SportsDataError.contractViolation(field: "data.totals")
            }
            return (reaction, value)
        })
        return ArticleReactionSummary(myReaction: myReaction, totals: mapped)
    }
}

struct ArticleReactionInputDTO: Encodable, Sendable {
    let type: ArticleReaction
}

struct CommentReportInputDTO: Encodable, Sendable {
    let reason: CommentReportReason
    let details: String?
}

struct CommunityReportResponseDTO: Decodable, Sendable {
    let data: CommunityReportDataDTO
}

struct CommunityReportDataDTO: Decodable, Sendable {
    let reportId: String
    let status: String
    let submittedAt: Date

    func domain(now: Date) throws -> CommunityReportReceipt {
        let reportID = try validatedIdentifier(reportId, field: "data.reportId")
        guard status == "RECEIVED",
              submittedAt <= now.addingTimeInterval(5 * 60) else {
            throw SportsDataError.contractViolation(field: "data.status")
        }
        return CommunityReportReceipt(reportID: reportID, submittedAt: submittedAt)
    }
}

enum VideoTypeDTO: String, Decodable, Sendable {
    case live = "LIVE"
    case replay = "REPLAY"
    case highlight = "HIGHLIGHT"
    case original = "ORIGINAL"
    case interview = "INTERVIEW"

    var domain: SportsVideoType {
        switch self {
        case .live: .live
        case .replay: .replay
        case .highlight: .highlight
        case .original: .original
        case .interview: .interview
        }
    }
}

enum VideoAvailabilityReasonDTO: String, Decodable, Sendable {
    case loginRequired = "LOGIN_REQUIRED"
    case entitlementRequired = "ENTITLEMENT_REQUIRED"
    case regionBlocked = "REGION_BLOCKED"
    case notStarted = "NOT_STARTED"
    case expired = "EXPIRED"

    var domain: VideoAvailabilityReason {
        switch self {
        case .loginRequired: .loginRequired
        case .entitlementRequired: .entitlementRequired
        case .regionBlocked: .regionBlocked
        case .notStarted: .notStarted
        case .expired: .expired
        }
    }
}

struct VideoPosterMediaDTO: Decodable, Sendable {
    let id: String
    let url: URL
    let contentType: String
    let width: Int
    let height: Int
    let altText: LocalizedTextDTO
    let credit: LocalizedTextDTO

    func domain(field: String) throws -> VideoPosterMedia {
        let id = try validatedEditorialMediaIdentifier(id, field: "\(field).id")
        let url = try validatedEditorialMediaURL(url, field: "\(field).url")
        guard let contentType = EditorialImageContentType(rawValue: contentType) else {
            throw SportsDataError.contractViolation(field: "\(field).contentType")
        }
        guard (640...4_096).contains(width) else {
            throw SportsDataError.contractViolation(field: "\(field).width")
        }
        guard (360...4_096).contains(height) else {
            throw SportsDataError.contractViolation(field: "\(field).height")
        }
        let pixels = width.multipliedReportingOverflow(by: height)
        guard !pixels.overflow, pixels.partialValue <= 16_000_000 else {
            throw SportsDataError.contractViolation(field: "\(field).dimensions")
        }
        let aspectRatio = Double(width) / Double(height)
        guard (1.2...2.4).contains(aspectRatio) else {
            throw SportsDataError.contractViolation(field: "\(field).aspectRatio")
        }
        let altText = try validatedEditorialMediaText(
            altText,
            maximumLength: 180,
            field: "\(field).altText"
        )
        let credit = try validatedEditorialMediaText(
            credit,
            maximumLength: 120,
            field: "\(field).credit"
        )
        return VideoPosterMedia(
            id: id,
            url: url,
            contentType: contentType,
            width: width,
            height: height,
            altArabic: altText.arabic,
            altEnglish: altText.english,
            creditArabic: credit.arabic,
            creditEnglish: credit.english
        )
    }
}

struct VideoDTO: Decodable, Sendable {
    let id: String
    let type: VideoTypeDTO
    let title: LocalizedTextDTO
    let description: LocalizedTextDTO?
    let poster: VideoPosterMediaDTO?
    let durationSeconds: Int
    let isPlayable: Bool
    let availabilityReason: VideoAvailabilityReasonDTO?

    init(
        id: String,
        type: VideoTypeDTO,
        title: LocalizedTextDTO,
        description: LocalizedTextDTO?,
        poster: VideoPosterMediaDTO? = nil,
        durationSeconds: Int,
        isPlayable: Bool,
        availabilityReason: VideoAvailabilityReasonDTO?
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.poster = poster
        self.durationSeconds = durationSeconds
        self.isPlayable = isPlayable
        self.availabilityReason = availabilityReason
    }

    func domain(field: String) throws -> SportsVideo {
        let id = try validatedIdentifier(id, field: "\(field).id")
        let title = try title.validated(field: "\(field).title")
        guard durationSeconds >= 0 else {
            throw SportsDataError.contractViolation(field: "\(field).durationSeconds")
        }
        switch (isPlayable, availabilityReason) {
        case (true, nil), (false, .some):
            break
        default:
            throw SportsDataError.contractViolation(field: "\(field).availabilityReason")
        }
        let description = try description?.validated(field: "\(field).description")
        return SportsVideo(
            id: id,
            type: type.domain,
            titleArabic: title.arabic,
            titleEnglish: title.english,
            descriptionArabic: description?.arabic ?? "",
            descriptionEnglish: description?.english ?? "",
            poster: try poster?.domain(field: "\(field).poster"),
            durationSeconds: durationSeconds,
            isPlayable: isPlayable,
            availabilityReason: availabilityReason?.domain
        )
    }
}

struct VideoDiscoveryResponseDTO: Decodable, Sendable {
    let data: VideoDiscoveryDataDTO

    func domain() throws -> VideoDiscoveryFeed {
        try data.domain()
    }
}

struct VideoDiscoveryDataDTO: Decodable, Sendable {
    private static let maximumItemCount = 100
    private static let maximumTrendingCount = 10

    let items: [VideoDiscoveryItemDTO]
    let featuredVideoId: String?
    let trendingVideoIds: [String]

    func domain() throws -> VideoDiscoveryFeed {
        guard items.count <= Self.maximumItemCount else {
            throw SportsDataError.contractViolation(field: "data.items")
        }

        let domainItems = try items.enumerated().map {
            try $0.element.domain(field: "data.items[\($0.offset)]")
        }
        let itemIDs = Set(domainItems.map(\.id))
        guard itemIDs.count == domainItems.count else {
            throw SportsDataError.contractViolation(field: "data.items.id")
        }

        let featuredVideoID = try featuredVideoId.map {
            try validatedIdentifier($0, field: "data.featuredVideoId")
        }
        if let featuredVideoID, !itemIDs.contains(featuredVideoID) {
            throw SportsDataError.contractViolation(field: "data.featuredVideoId")
        }

        guard trendingVideoIds.count <= Self.maximumTrendingCount else {
            throw SportsDataError.contractViolation(field: "data.trendingVideoIds")
        }
        let trendingVideoIDs = try trendingVideoIds.enumerated().map {
            try validatedIdentifier(
                $0.element,
                field: "data.trendingVideoIds[\($0.offset)]"
            )
        }
        guard Set(trendingVideoIDs).count == trendingVideoIDs.count else {
            throw SportsDataError.contractViolation(field: "data.trendingVideoIds")
        }
        guard trendingVideoIDs.allSatisfy(itemIDs.contains) else {
            throw SportsDataError.contractViolation(field: "data.trendingVideoIds")
        }
        if let featuredVideoID, trendingVideoIDs.contains(featuredVideoID) {
            throw SportsDataError.contractViolation(field: "data.featuredVideoId")
        }

        return VideoDiscoveryFeed(
            items: domainItems,
            featuredVideoID: featuredVideoID,
            trendingVideoIDs: trendingVideoIDs
        )
    }
}

struct VideoDiscoveryItemDTO: Decodable, Sendable {
    let video: VideoDTO
    let sport: SportDTO

    func domain(field: String) throws -> VideoDiscoveryItem {
        VideoDiscoveryItem(
            video: try video.domain(field: "\(field).video"),
            sport: sport.videoDomain
        )
    }
}

struct VideoListResponseDTO: Decodable, Sendable {
    let data: [VideoDTO]
    let page: PageInfoDTO

    func domain() throws -> [SportsVideo] {
        try data.enumerated().map { try $0.element.domain(field: "data[\($0.offset)]") }
    }

    func domainPage() throws -> VideoListPage {
        VideoListPage(
            videos: try domain(),
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }
}

struct VideoListPage: Sendable {
    let videos: [SportsVideo]
    let nextCursor: String?
    let hasMore: Bool
}

struct VideoDetailResponseDTO: Decodable, Sendable {
    let data: VideoDetailDataDTO
}

struct VideoDetailDataDTO: Decodable, Sendable {
    private static let maximumRelatedVideoCount = 10

    let id: String
    let type: VideoTypeDTO
    let title: LocalizedTextDTO
    let description: LocalizedTextDTO?
    let poster: VideoPosterMediaDTO?
    let durationSeconds: Int
    let isPlayable: Bool
    let availabilityReason: VideoAvailabilityReasonDTO?
    let publishedAt: Date?
    let audioLanguages: [String]?
    let subtitleLanguages: [String]?
    let publisher: LocalizedTextDTO?
    let program: VideoProgramDTO?
    let relatedVideos: [VideoDTO]

    func domain(expectedVideoID: String) throws -> SportsVideoDetails {
        let video = try VideoDTO(
            id: id,
            type: type,
            title: title,
            description: description,
            poster: poster,
            durationSeconds: durationSeconds,
            isPlayable: isPlayable,
            availabilityReason: availabilityReason
        ).domain(field: "data")
        guard video.id == expectedVideoID else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        let publisher = try publisher?.validated(field: "data.publisher")
        let program = try program?.domain(field: "data.program")
        guard relatedVideos.count <= Self.maximumRelatedVideoCount else {
            throw SportsDataError.contractViolation(field: "data.relatedVideos")
        }
        let relatedVideos = try relatedVideos.enumerated().map {
            try $0.element.domain(field: "data.relatedVideos[\($0.offset)]")
        }
        let relatedVideoIDs = relatedVideos.map(\.id)
        guard Set(relatedVideoIDs).count == relatedVideoIDs.count else {
            throw SportsDataError.contractViolation(field: "data.relatedVideos.id")
        }
        guard !relatedVideoIDs.contains(video.id) else {
            throw SportsDataError.contractViolation(field: "data.relatedVideos.id")
        }
        return SportsVideoDetails(
            video: video,
            publishedAt: publishedAt,
            audioLanguages: audioLanguages ?? [],
            subtitleLanguages: subtitleLanguages ?? [],
            publisherArabic: publisher?.arabic,
            publisherEnglish: publisher?.english,
            program: program,
            relatedVideos: relatedVideos
        )
    }
}

struct VideoProgramDTO: Decodable, Sendable {
    let id: String
    let title: LocalizedTextDTO

    func domain(field: String) throws -> VideoProgram {
        let id = try validatedVideoProgramIdentifier(id, field: "\(field).id")
        let title = try validatedVideoProgramText(
            title,
            maximumLength: 160,
            field: "\(field).title"
        )
        return VideoProgram(
            id: id,
            titleArabic: title.arabic,
            titleEnglish: title.english
        )
    }
}

struct VideoProgramSummaryDTO: Decodable, Sendable {
    let id: String
    let title: LocalizedTextDTO
    let description: LocalizedTextDTO
    let sport: SportDTO
    let featuredVideo: VideoDTO?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case sport
        case featuredVideo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(LocalizedTextDTO.self, forKey: .title)
        description = try container.decode(LocalizedTextDTO.self, forKey: .description)
        sport = try container.decode(SportDTO.self, forKey: .sport)
        guard container.contains(.featuredVideo) else {
            throw DecodingError.keyNotFound(
                CodingKeys.featuredVideo,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "featuredVideo must be an explicit object or null"
                )
            )
        }
        featuredVideo = try container.decodeIfPresent(VideoDTO.self, forKey: .featuredVideo)
    }

    func domain(field: String) throws -> VideoProgramSummary {
        let program = try VideoProgramDTO(id: id, title: title).domain(field: field)
        let description = try validatedVideoProgramText(
            description,
            maximumLength: VideoProgramPaginationContract.maximumDescriptionLength,
            field: "\(field).description"
        )
        return VideoProgramSummary(
            program: program,
            descriptionArabic: description.arabic,
            descriptionEnglish: description.english,
            sport: sport.videoDomain,
            featuredVideo: try featuredVideo?.domain(field: "\(field).featuredVideo")
        )
    }
}

struct VideoProgramPageInfoDTO: Decodable, Sendable {
    let nextCursor: String?
    let hasMore: Bool

    private enum CodingKeys: String, CodingKey {
        case nextCursor
        case hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.contains(.nextCursor) else {
            throw DecodingError.keyNotFound(
                CodingKeys.nextCursor,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "nextCursor must be an explicit string or null"
                )
            )
        }
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
        hasMore = try container.decode(Bool.self, forKey: .hasMore)
    }
}

struct VideoProgramListResponseDTO: Decodable, Sendable {
    let data: [VideoProgramSummaryDTO]
    let page: VideoProgramPageInfoDTO

    func domain() throws -> VideoProgramPage {
        guard data.count <= VideoProgramPaginationContract.maximumPageSize else {
            throw SportsDataError.contractViolation(field: "data")
        }
        let programs = try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]")
        }
        guard Set(programs.map(\.id)).count == programs.count else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        try validateVideoProgramPage(
            itemCount: programs.count,
            page: page,
            field: "page"
        )
        return VideoProgramPage(
            programs: programs,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }
}

struct VideoProgramEpisodeDTO: Decodable, Sendable {
    let video: VideoDTO
    let publishedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case video
        case publishedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        video = try container.decode(VideoDTO.self, forKey: .video)
        guard container.contains(.publishedAt) else {
            throw DecodingError.keyNotFound(
                CodingKeys.publishedAt,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "publishedAt must be an explicit date or null"
                )
            )
        }
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
    }

    func domain(field: String) throws -> VideoProgramEpisode {
        VideoProgramEpisode(
            video: try video.domain(field: "\(field).video"),
            publishedAt: publishedAt
        )
    }
}

struct VideoProgramDetailResponseDTO: Decodable, Sendable {
    let data: VideoProgramDetailDataDTO

    func domain(expectedProgramID: String) throws -> VideoProgramDetailsPage {
        try data.domain(expectedProgramID: expectedProgramID)
    }
}

struct VideoProgramDetailDataDTO: Decodable, Sendable {
    let program: VideoProgramSummaryDTO
    let episodes: [VideoProgramEpisodeDTO]
    let page: VideoProgramPageInfoDTO

    func domain(expectedProgramID: String) throws -> VideoProgramDetailsPage {
        let program = try program.domain(field: "data.program")
        guard program.id == expectedProgramID else {
            throw SportsDataError.contractViolation(field: "data.program.id")
        }
        guard episodes.count <= VideoProgramPaginationContract.maximumPageSize else {
            throw SportsDataError.contractViolation(field: "data.episodes")
        }
        let episodes = try episodes.enumerated().map {
            try $0.element.domain(field: "data.episodes[\($0.offset)]")
        }
        guard Set(episodes.map(\.id)).count == episodes.count else {
            throw SportsDataError.contractViolation(field: "data.episodes.id")
        }
        try validateVideoProgramPage(
            itemCount: episodes.count,
            page: page,
            field: "data.page"
        )
        return VideoProgramDetailsPage(
            program: program,
            episodes: episodes,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }
}

private func validatedVideoProgramText(
    _ text: LocalizedTextDTO,
    maximumLength: Int,
    field: String
) throws -> (arabic: String, english: String) {
    let text = try text.validated(field: field)
    guard text.arabic.unicodeScalars.count <= maximumLength,
          text.english.unicodeScalars.count <= maximumLength,
          text.arabic.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }),
          text.english.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }) else {
        throw SportsDataError.contractViolation(field: field)
    }
    return text
}

private func validatedVideoProgramIdentifier(
    _ value: String,
    field: String
) throws -> String {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let forbidden = CharacterSet(charactersIn: "/\\?#")
    guard (1...128).contains(value.unicodeScalars.count),
          value.rangeOfCharacter(from: forbidden) == nil,
          value.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }) else {
        throw SportsDataError.contractViolation(field: field)
    }
    return value
}

private func validateVideoProgramPage(
    itemCount: Int,
    page: VideoProgramPageInfoDTO,
    field: String
) throws {
    if page.hasMore {
        guard itemCount > 0,
              let cursor = page.nextCursor,
              (1...VideoProgramPaginationContract.maximumCursorLength).contains(cursor.count),
              cursor.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              cursor.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw SportsDataError.contractViolation(field: "\(field).nextCursor")
        }
    } else if page.nextCursor != nil {
        throw SportsDataError.contractViolation(field: "\(field).nextCursor")
    }
}

struct WatchProgressDTO: Decodable, Sendable {
    let videoId: String
    let positionSeconds: Int
    let completed: Bool
    let updatedAt: Date

    func domain(field: String) throws -> WatchProgress {
        let videoID = try validatedIdentifier(videoId, field: "\(field).videoId")
        guard positionSeconds >= 0 else {
            throw SportsDataError.contractViolation(field: "\(field).positionSeconds")
        }
        return WatchProgress(
            videoID: videoID,
            positionSeconds: positionSeconds,
            completed: completed,
            updatedAt: updatedAt
        )
    }
}

struct WatchProgressResponseDTO: Decodable, Sendable {
    let data: WatchProgressDTO
}

struct ContinueWatchingItemDTO: Decodable, Sendable {
    let video: VideoDTO
    let progress: WatchProgressDTO

    func domain(field: String) throws -> ContinueWatchingItem {
        let video = try video.domain(field: "\(field).video")
        let progress = try progress.domain(field: "\(field).progress")
        guard progress.videoID == video.id else {
            throw SportsDataError.contractViolation(field: "\(field).progress.videoId")
        }
        guard progress.positionSeconds <= video.durationSeconds else {
            throw SportsDataError.contractViolation(field: "\(field).progress.positionSeconds")
        }
        guard !progress.completed else {
            throw SportsDataError.contractViolation(field: "\(field).progress.completed")
        }
        return ContinueWatchingItem(video: video, progress: progress)
    }
}

struct ContinueWatchingResponseDTO: Decodable, Sendable {
    let data: [ContinueWatchingItemDTO]
    let page: PageInfoDTO

    func domain() throws -> [ContinueWatchingItem] {
        try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]")
        }
    }
}

struct WatchHistoryItemDTO: Decodable, Sendable {
    let video: VideoDTO
    let progress: WatchProgressDTO

    func domain(field: String) throws -> WatchHistoryItem {
        let video = try video.domain(field: "\(field).video")
        let progress = try progress.domain(field: "\(field).progress")
        guard progress.videoID == video.id else {
            throw SportsDataError.contractViolation(field: "\(field).progress.videoId")
        }
        guard progress.positionSeconds <= video.durationSeconds else {
            throw SportsDataError.contractViolation(field: "\(field).progress.positionSeconds")
        }
        guard progress.positionSeconds > 0 else {
            throw SportsDataError.contractViolation(field: "\(field).progress.positionSeconds")
        }
        return WatchHistoryItem(video: video, progress: progress)
    }
}

struct WatchHistoryResponseDTO: Decodable, Sendable {
    let data: [WatchHistoryItemDTO]
    let page: PageInfoDTO

    func domain() throws -> [WatchHistoryItem] {
        guard data.count <= 100 else {
            throw SportsDataError.contractViolation(field: "data")
        }
        let items = try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]")
        }
        guard Set(items.map(\.id)).count == items.count else {
            throw SportsDataError.contractViolation(field: "data")
        }
        guard zip(items, items.dropFirst()).allSatisfy({ current, next in
            current.progress.updatedAt >= next.progress.updatedAt
        }) else {
            throw SportsDataError.contractViolation(field: "data")
        }
        return items
    }
}

struct FollowDTO: Decodable, Sendable {
    let id: String
    let type: FollowEntityType
    let entityId: String
    let createdAt: Date
    let entity: FollowEntityDTO

    func domain(field: String, now: Date) throws -> SportsFollow {
        let id = try validatedFollowIdentifier(id, field: "\(field).id")
        let entityID = try validatedFollowIdentifier(entityId, field: "\(field).entityId")
        guard createdAt <= now.addingTimeInterval(5 * 60) else {
            throw SportsDataError.contractViolation(field: "\(field).createdAt")
        }
        let entity = try entity.domain(field: "\(field).entity")
        guard entity.type == type, entity.entityID == entityID else {
            throw SportsDataError.contractViolation(field: "\(field).entity")
        }
        return SportsFollow(
            id: id,
            type: type,
            entityID: entityID,
            createdAt: createdAt,
            entity: entity
        )
    }
}

struct FollowEntityDTO: Decodable, Sendable {
    let type: FollowEntityType
    let team: TeamDTO?
    let player: PlayerDTO?
    let competition: CompetitionDTO?

    func domain(field: String) throws -> FollowEntitySnapshot {
        switch type {
        case .team:
            guard let team, player == nil, competition == nil else {
                throw SportsDataError.contractViolation(field: field)
            }
            return .team(try team.domain(field: "\(field).team"))
        case .player:
            guard team == nil, let player, competition == nil else {
                throw SportsDataError.contractViolation(field: field)
            }
            return .player(try player.domain(field: "\(field).player"))
        case .competition:
            guard team == nil, player == nil, let competition else {
                throw SportsDataError.contractViolation(field: field)
            }
            return .competition(try competition.domain(field: "\(field).competition"))
        }
    }
}

struct FollowResponseDTO: Decodable, Sendable {
    let data: FollowDTO
}

struct FollowListResponseDTO: Decodable, Sendable {
    let data: [FollowDTO]

    func domain(now: Date) throws -> [SportsFollow] {
        guard data.count <= 500 else {
            throw SportsDataError.contractViolation(field: "data")
        }
        let follows = try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]", now: now)
        }
        let targetKeys = follows.map { "\($0.type.rawValue):\($0.entityID)" }
        guard Set(follows.map(\.id)).count == follows.count,
              Set(targetKeys).count == targetKeys.count else {
            throw SportsDataError.contractViolation(field: "data")
        }
        return follows.canonicalFollowOrder
    }
}

struct CreateFollowInputDTO: Encodable, Sendable {
    let type: FollowEntityType
    let entityId: String
}

struct NotificationPreferencesDTO: Decodable, Sendable {
    let breakingNews: Bool
    let lineup: Bool
    let kickoff: Bool
    let goal: Bool
    let card: Bool?
    let yellowCard: Bool?
    let redCard: Bool?
    let substitution: Bool?
    let halfTime: Bool
    let fullTime: Bool

    func domain() -> NotificationPreferences {
        let legacyCardPreference = card ?? false
        return NotificationPreferences(
            breakingNews: breakingNews,
            lineup: lineup,
            kickoff: kickoff,
            goal: goal,
            yellowCard: yellowCard ?? legacyCardPreference,
            redCard: redCard ?? legacyCardPreference,
            substitution: substitution ?? false,
            halfTime: halfTime,
            fullTime: fullTime
        )
    }
}

struct NotificationPreferencesResponseDTO: Decodable, Sendable {
    let data: NotificationPreferencesDTO
}

struct NotificationPreferencesPatchDTO: Encodable, Sendable {
    let breakingNews: Bool?
    let lineup: Bool?
    let kickoff: Bool?
    let goal: Bool?
    let yellowCard: Bool?
    let redCard: Bool?
    let substitution: Bool?
    let halfTime: Bool?
    let fullTime: Bool?

    init(type: NotificationPreferenceType, enabled: Bool) {
        breakingNews = type == .breakingNews ? enabled : nil
        lineup = type == .lineup ? enabled : nil
        kickoff = type == .kickoff ? enabled : nil
        goal = type == .goal ? enabled : nil
        yellowCard = type == .yellowCard ? enabled : nil
        redCard = type == .redCard ? enabled : nil
        substitution = type == .substitution ? enabled : nil
        halfTime = type == .halfTime ? enabled : nil
        fullTime = type == .fullTime ? enabled : nil
    }
}

struct PushDeviceRegistrationInputDTO: Encodable, Sendable {
    let token: String
    let environment: PushNotificationEnvironment
    let locale: String
    let timeZone: String
}

struct VideoFavoriteResponseDTO: Decodable, Sendable {
    let data: VideoFavoriteDataDTO
}

struct ArticleFavoriteResponseDTO: Decodable, Sendable {
    let data: ArticleFavoriteDataDTO
}

struct ArticleFavoriteDataDTO: Decodable, Sendable {
    let articleId: String
    let isFavorite: Bool
    let updatedAt: Date?

    func domain() throws -> ArticleFavoriteState {
        ArticleFavoriteState(
            articleID: try validatedIdentifier(articleId, field: "data.articleId"),
            isFavorite: isFavorite,
            updatedAt: updatedAt
        )
    }
}

struct VideoFavoriteDataDTO: Decodable, Sendable {
    let videoId: String
    let isFavorite: Bool
    let updatedAt: Date?

    func domain() throws -> VideoFavoriteState {
        VideoFavoriteState(
            videoID: try validatedIdentifier(videoId, field: "data.videoId"),
            isFavorite: isFavorite,
            updatedAt: updatedAt
        )
    }
}

struct WatchProgressInputDTO: Encodable, Sendable {
    let positionSeconds: Int
    let completed: Bool
}

struct CreatePlaybackSessionInputDTO: Encodable, Sendable {
    let deviceID: String
    let supportsFairPlay: Bool
}

struct PlaybackSessionResponseDTO: Decodable, Sendable {
    let data: PlaybackSessionDataDTO
}

struct PlaybackSessionDataDTO: Decodable, Sendable {
    let id: String
    let hlsURL: String
    let fairPlayCertificateURL: String?
    let fairPlayLicenseURL: String?
    let expiresAt: Date
    let allowsAirPlay: Bool
    let allowsPictureInPicture: Bool

    func domain(
        videoID: String,
        now: Date,
        capabilities: PlaybackCapabilities
    ) throws -> PlaybackSession {
        let id = try validatedIdentifier(id, field: "data.id")
        let hlsURL = try securePlaybackURL(hlsURL, field: "data.hlsURL")
        guard expiresAt > now else {
            throw SportsDataError.contractViolation(field: "data.expiresAt")
        }

        let fairPlay: FairPlayConfiguration?
        switch (fairPlayCertificateURL, fairPlayLicenseURL) {
        case (nil, nil):
            fairPlay = nil
        case let (.some(certificate), .some(license)):
            guard capabilities.supportsFairPlay else {
                throw SportsDataError.contractViolation(field: "data.fairPlay")
            }
            fairPlay = FairPlayConfiguration(
                certificateURL: try securePlaybackURL(
                    certificate,
                    field: "data.fairPlayCertificateURL"
                ),
                licenseURL: try securePlaybackURL(
                    license,
                    field: "data.fairPlayLicenseURL"
                )
            )
        default:
            throw SportsDataError.contractViolation(field: "data.fairPlay")
        }

        return PlaybackSession(
            id: id,
            videoID: try validatedIdentifier(videoID, field: "videoID"),
            hlsURL: hlsURL,
            fairPlay: fairPlay,
            expiresAt: expiresAt,
            allowsAirPlay: allowsAirPlay,
            allowsPictureInPicture: allowsPictureInPicture
        )
    }

    private func securePlaybackURL(_ value: String, field: String) throws -> URL {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil else {
            throw SportsDataError.contractViolation(field: field)
        }
        return url
    }
}

enum SearchResultTypeDTO: String, Decodable, Sendable {
    case article = "ARTICLE"
    case video = "VIDEO"
    case team = "TEAM"
    case player = "PLAYER"
    case competition = "COMPETITION"

    var domain: SearchEntityType {
        switch self {
        case .article: .article
        case .video: .video
        case .team: .team
        case .player: .player
        case .competition: .competition
        }
    }
}

struct SearchResultDTO: Decodable, Sendable {
    let type: SearchResultTypeDTO
    let entityId: String
    let title: LocalizedTextDTO
    let subtitle: LocalizedTextDTO?

    func domain(field: String) throws -> SearchResultItem {
        let entityID = try validatedFollowIdentifier(entityId, field: "\(field).entityId")
        let title = try title.validated(field: "\(field).title")
        let subtitle = try subtitle?.validated(field: "\(field).subtitle")
        return SearchResultItem(
            type: type.domain,
            entityID: entityID,
            titleArabic: title.arabic,
            titleEnglish: title.english,
            subtitleArabic: subtitle?.arabic,
            subtitleEnglish: subtitle?.english
        )
    }
}

struct SearchResponseDTO: Decodable, Sendable {
    let data: [SearchResultDTO]
    let page: PageInfoDTO

    func domain() throws -> [SearchResultItem] {
        guard data.count <= GlobalSearchContract.maximumResultCount else {
            throw SportsDataError.contractViolation(field: "data")
        }
        let normalizedCursor = page.nextCursor?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if page.hasMore {
            guard !data.isEmpty, let normalizedCursor, !normalizedCursor.isEmpty else {
                throw SportsDataError.contractViolation(field: "page.nextCursor")
            }
        } else if page.nextCursor != nil {
            throw SportsDataError.contractViolation(field: "page.nextCursor")
        }

        let results = try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]")
        }
        guard Set(results.map(\.id)).count == results.count else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        return results
    }
}

struct HomeResponseDTO: Decodable, Sendable {
    let data: HomeDataDTO
}

struct HomeDataDTO: Decodable, Sendable {
    let generatedAt: Date
    let featuredFixtures: [FixtureDTO]
    let articles: [ArticleDTO]

    func domain() throws -> HomeFeed {
        HomeFeed(
            fixtures: try featuredFixtures.enumerated().map {
                try $0.element.domain(field: "data.featuredFixtures[\($0.offset)]")
            },
            articles: try articles.enumerated().map {
                try $0.element.domain(field: "data.articles[\($0.offset)]")
            }
        )
    }
}

struct TeamListResponseDTO: Decodable, Sendable {
    let data: [TeamDTO]
    let page: PageInfoDTO

    func domain() throws -> [Team] {
        try data.enumerated().map { try $0.element.domain(field: "data[\($0.offset)]") }
    }
}

struct CompetitionListResponseDTO: Decodable, Sendable {
    let data: [CompetitionDTO]
    let page: PageInfoDTO

    func domain() throws -> [Competition] {
        try data.enumerated().map { try $0.element.domain(field: "data[\($0.offset)]") }
    }
}

struct PlayerDTO: Decodable, Sendable {
    let id: String
    let name: String
    let position: String

    func domain(field: String) throws -> PlayerProfile {
        let id = try validatedIdentifier(id, field: "\(field).id")
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let position = position.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SportsDataError.contractViolation(field: "\(field).name")
        }
        guard !position.isEmpty else {
            throw SportsDataError.contractViolation(field: "\(field).position")
        }
        return PlayerProfile(id: id, name: name, position: position)
    }
}

struct PlayerListResponseDTO: Decodable, Sendable {
    let data: [PlayerDTO]
    let page: PageInfoDTO

    func domain() throws -> [PlayerProfile] {
        guard data.count <= 100 else {
            throw SportsDataError.contractViolation(field: "data")
        }
        let players = try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]")
        }
        guard Set(players.map(\.id)).count == players.count else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        return players
    }
}

struct TeamDetailResponseDTO: Decodable, Sendable {
    let data: TeamDetailDataDTO
}

struct TeamDetailDataDTO: Decodable, Sendable {
    let team: TeamDTO
    let competitions: [CompetitionDTO]
    let nextFixtures: [FixtureDTO]
    let recentFixtures: [FixtureDTO]

    func domain(expectedTeamID: String) throws -> TeamDetails {
        let team = try team.domain(field: "data.team")
        guard team.id == expectedTeamID else {
            throw SportsDataError.contractViolation(field: "data.team.id")
        }
        guard competitions.count <= 20,
              nextFixtures.count <= 10,
              recentFixtures.count <= 10 else {
            throw SportsDataError.contractViolation(field: "data")
        }

        let competitions = try competitions.enumerated().map {
            try $0.element.domain(field: "data.competitions[\($0.offset)]")
        }
        let nextFixtures = try nextFixtures.enumerated().map {
            try $0.element.domain(field: "data.nextFixtures[\($0.offset)]")
        }
        let recentFixtures = try recentFixtures.enumerated().map {
            try $0.element.domain(field: "data.recentFixtures[\($0.offset)]")
        }

        guard Set(competitions.map(\.id)).count == competitions.count else {
            throw SportsDataError.contractViolation(field: "data.competitions.id")
        }
        let competitionIDs = Set(competitions.map(\.id))
        try validateTeamFixtures(
            nextFixtures,
            expectedTeam: team,
            competitionIDs: competitionIDs,
            expectedState: .upcoming,
            field: "data.nextFixtures",
            isOrdered: { lhs, rhs in
                lhs.kickoff < rhs.kickoff
                    || (lhs.kickoff == rhs.kickoff && lhs.id < rhs.id)
            }
        )
        try validateTeamFixtures(
            recentFixtures,
            expectedTeam: team,
            competitionIDs: competitionIDs,
            expectedState: .finished,
            field: "data.recentFixtures",
            isOrdered: { lhs, rhs in
                lhs.kickoff > rhs.kickoff
                    || (lhs.kickoff == rhs.kickoff && lhs.id < rhs.id)
            }
        )
        guard Set(nextFixtures.map(\.id)).isDisjoint(with: recentFixtures.map(\.id)) else {
            throw SportsDataError.contractViolation(field: "data.fixtures.id")
        }

        return TeamDetails(
            team: team,
            competitions: competitions,
            nextFixtures: nextFixtures,
            recentFixtures: recentFixtures
        )
    }

    private func validateTeamFixtures(
        _ fixtures: [Fixture],
        expectedTeam: Team,
        competitionIDs: Set<String>,
        expectedState: FixtureState,
        field: String,
        isOrdered: (Fixture, Fixture) -> Bool
    ) throws {
        guard Set(fixtures.map(\.id)).count == fixtures.count else {
            throw SportsDataError.contractViolation(field: "\(field).id")
        }
        for fixture in fixtures {
            guard fixture.state == expectedState else {
                throw SportsDataError.contractViolation(field: "\(field).state")
            }
            let isHomeTeam = fixture.homeTeam.id == expectedTeam.id
            let isAwayTeam = fixture.awayTeam.id == expectedTeam.id
            guard isHomeTeam != isAwayTeam else {
                throw SportsDataError.contractViolation(field: "\(field).teamId")
            }
            let fixtureTeam = isHomeTeam ? fixture.homeTeam : fixture.awayTeam
            guard fixtureTeam == expectedTeam else {
                throw SportsDataError.contractViolation(field: "\(field).team")
            }
            guard competitionIDs.contains(fixture.competition.id) else {
                throw SportsDataError.contractViolation(field: "\(field).competition.id")
            }
        }
        for (lhs, rhs) in zip(fixtures, fixtures.dropFirst()) where !isOrdered(lhs, rhs) {
            throw SportsDataError.contractViolation(field: "\(field).order")
        }
    }
}

struct TeamMatchSnapshotListResponseDTO: Decodable, Sendable {
    let data: [TeamMatchSnapshotDTO]

    func domain(expectedTeamIDs: [String]) throws -> [TeamMatchSnapshot] {
        guard (1...TeamMatchSnapshotRequestLimits.maximumTeamsPerHTTPBatch)
            .contains(expectedTeamIDs.count),
              Set(expectedTeamIDs).count == expectedTeamIDs.count else {
            throw SportsDataError.contractViolation(field: "request.teamId")
        }
        guard data.count == expectedTeamIDs.count else {
            throw SportsDataError.contractViolation(field: "data.count")
        }

        return try zip(data, expectedTeamIDs).enumerated().map { index, pair in
            try pair.0.domain(
                expectedTeamID: pair.1,
                field: "data[\(index)]"
            )
        }
    }
}

struct TeamMatchSnapshotDTO: Decodable, Sendable {
    let team: TeamDTO
    let previousFixture: FixtureDTO?
    let nextFixture: FixtureDTO?

    func domain(expectedTeamID: String, field: String) throws -> TeamMatchSnapshot {
        let team = try team.domain(field: "\(field).team")
        guard team.id == expectedTeamID else {
            throw SportsDataError.contractViolation(field: "\(field).team.id")
        }

        let previousFixture = try previousFixture?.domain(
            field: "\(field).previousFixture"
        )
        let nextFixture = try nextFixture?.domain(field: "\(field).nextFixture")

        if let previousFixture {
            try validate(
                previousFixture,
                expectedTeam: team,
                expectedState: .finished,
                field: "\(field).previousFixture"
            )
        }
        if let nextFixture {
            try validate(
                nextFixture,
                expectedTeam: team,
                expectedState: .upcoming,
                field: "\(field).nextFixture"
            )
        }
        if let previousFixture, let nextFixture,
           previousFixture.id == nextFixture.id {
            throw SportsDataError.contractViolation(field: "\(field).fixtures.id")
        }

        return TeamMatchSnapshot(
            team: team,
            previousFixture: previousFixture,
            nextFixture: nextFixture
        )
    }

    private func validate(
        _ fixture: Fixture,
        expectedTeam: Team,
        expectedState: FixtureState,
        field: String
    ) throws {
        guard fixture.state == expectedState else {
            throw SportsDataError.contractViolation(field: "\(field).state")
        }
        let isHomeTeam = fixture.homeTeam.id == expectedTeam.id
        let isAwayTeam = fixture.awayTeam.id == expectedTeam.id
        guard isHomeTeam != isAwayTeam else {
            throw SportsDataError.contractViolation(field: "\(field).teamId")
        }
        let embeddedTeam = isHomeTeam ? fixture.homeTeam : fixture.awayTeam
        guard embeddedTeam == expectedTeam else {
            throw SportsDataError.contractViolation(field: "\(field).team")
        }
    }
}

struct TeamContentResponseDTO: Decodable, Sendable {
    let data: TeamContentDataDTO
}

struct TeamContentDataDTO: Decodable, Sendable {
    let teamId: String
    let articles: [ArticleDTO]
    let videos: [VideoDTO]

    func domain(expectedTeamID: String) throws -> TeamContent {
        let teamID = try validatedIdentifier(teamId, field: "data.teamId")
        guard teamID == expectedTeamID else {
            throw SportsDataError.contractViolation(field: "data.teamId")
        }
        let content = try validatedEntityEditorialContent(articles: articles, videos: videos)
        return TeamContent(teamID: teamID, articles: content.articles, videos: content.videos)
    }
}

struct PlayerContentResponseDTO: Decodable, Sendable {
    let data: PlayerContentDataDTO
}

struct PlayerContentDataDTO: Decodable, Sendable {
    let playerId: String
    let articles: [ArticleDTO]
    let videos: [VideoDTO]

    func domain(expectedPlayerID: String) throws -> PlayerContent {
        let playerID = try validatedIdentifier(playerId, field: "data.playerId")
        guard playerID == expectedPlayerID else {
            throw SportsDataError.contractViolation(field: "data.playerId")
        }
        let content = try validatedEntityEditorialContent(articles: articles, videos: videos)
        return PlayerContent(
            playerID: playerID,
            articles: content.articles,
            videos: content.videos
        )
    }
}

struct CompetitionContentResponseDTO: Decodable, Sendable {
    let data: CompetitionContentDataDTO
}

struct CompetitionContentDataDTO: Decodable, Sendable {
    let competitionId: String
    let articles: [ArticleDTO]
    let videos: [VideoDTO]

    func domain(expectedCompetitionID: String) throws -> CompetitionContent {
        let competitionID = try validatedIdentifier(
            competitionId,
            field: "data.competitionId"
        )
        guard competitionID == expectedCompetitionID else {
            throw SportsDataError.contractViolation(field: "data.competitionId")
        }
        let content = try validatedEntityEditorialContent(articles: articles, videos: videos)
        return CompetitionContent(
            competitionID: competitionID,
            articles: content.articles,
            videos: content.videos
        )
    }
}

private func validatedEntityEditorialContent(
    articles articleDTOs: [ArticleDTO],
    videos videoDTOs: [VideoDTO]
) throws -> (articles: [Article], videos: [SportsVideo]) {
    guard articleDTOs.count <= 10, videoDTOs.count <= 10 else {
        throw SportsDataError.contractViolation(field: "data")
    }
    let articles = try articleDTOs.enumerated().map {
        try $0.element.domain(field: "data.articles[\($0.offset)]")
    }
    let videos = try videoDTOs.enumerated().map {
        try $0.element.domain(field: "data.videos[\($0.offset)]")
    }
    guard Set(articles.map(\.id)).count == articles.count else {
        throw SportsDataError.contractViolation(field: "data.articles.id")
    }
    guard Set(videos.map(\.id)).count == videos.count else {
        throw SportsDataError.contractViolation(field: "data.videos.id")
    }
    for (lhs, rhs) in zip(articles, articles.dropFirst()) {
        guard lhs.publishedAt > rhs.publishedAt
                || (lhs.publishedAt == rhs.publishedAt && lhs.id < rhs.id) else {
            throw SportsDataError.contractViolation(field: "data.articles.order")
        }
    }
    return (articles, videos)
}

struct FixtureContentResponseDTO: Decodable, Sendable {
    let data: FixtureContentDataDTO
}

struct FixtureContentDataDTO: Decodable, Sendable {
    private static let maximumMomentCount = 10
    private static let maximumArticleCount = 10

    let fixtureId: String
    let moments: [FixtureContentMomentDTO]
    let articles: [ArticleDTO]

    func domain(expectedFixtureID: String) throws -> FixtureContent {
        let fixtureID = try validatedIdentifier(fixtureId, field: "data.fixtureId")
        guard fixtureID == expectedFixtureID else {
            throw SportsDataError.contractViolation(field: "data.fixtureId")
        }
        guard moments.count <= Self.maximumMomentCount else {
            throw SportsDataError.contractViolation(field: "data.moments")
        }
        guard articles.count <= Self.maximumArticleCount else {
            throw SportsDataError.contractViolation(field: "data.articles")
        }

        let moments = try moments.enumerated().map {
            try $0.element.domain(field: "data.moments[\($0.offset)]")
        }
        let articles = try articles.enumerated().map {
            try $0.element.domain(field: "data.articles[\($0.offset)]")
        }
        guard Set(moments.map(\.id)).count == moments.count else {
            throw SportsDataError.contractViolation(field: "data.moments.id")
        }
        guard Set(moments.map(\.video.id)).count == moments.count else {
            throw SportsDataError.contractViolation(field: "data.moments.video.id")
        }
        guard Set(articles.map(\.id)).count == articles.count else {
            throw SportsDataError.contractViolation(field: "data.articles.id")
        }
        return FixtureContent(
            fixtureID: fixtureID,
            moments: moments,
            articles: articles
        )
    }
}

struct FixtureContentMomentDTO: Decodable, Sendable {
    let id: String
    let title: LocalizedTextDTO
    let minute: Int?
    let video: VideoDTO

    func domain(field: String) throws -> FixtureContentMoment {
        let id = try validatedIdentifier(id, field: "\(field).id")
        let title = try title.validated(field: "\(field).title")
        if let minute, !(0...200).contains(minute) {
            throw SportsDataError.contractViolation(field: "\(field).minute")
        }
        return FixtureContentMoment(
            id: id,
            titleArabic: title.arabic,
            titleEnglish: title.english,
            minute: minute,
            video: try video.domain(field: "\(field).video")
        )
    }
}

struct NamedStatisticDTO: Decodable, Sendable {
    let name: String
    let value: Double

    func domain(field: String) throws -> NamedStatistic {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, value.isFinite else {
            throw SportsDataError.contractViolation(field: field)
        }
        return NamedStatistic(name: name, value: value)
    }
}

struct PlayerDetailResponseDTO: Decodable, Sendable {
    let data: PlayerDetailDataDTO
}

struct PlayerDetailDataDTO: Decodable, Sendable {
    let player: PlayerDTO
    let currentTeam: TeamDTO?
    let statistics: [NamedStatisticDTO]

    func domain() throws -> PlayerDetails {
        PlayerDetails(
            player: try player.domain(field: "data.player"),
            currentTeam: try currentTeam?.domain(field: "data.currentTeam"),
            statistics: try statistics.enumerated().map {
                try $0.element.domain(field: "data.statistics[\($0.offset)]")
            }
        )
    }
}

enum TransferStatusDTO: String, Decodable, Sendable {
    case rumored = "RUMORED"
    case agreed = "AGREED"
    case completed = "COMPLETED"

    var domain: TransferStatus {
        switch self {
        case .rumored: .rumored
        case .agreed: .agreed
        case .completed: .completed
        }
    }
}

struct TransferDTO: Decodable, Sendable {
    let id: String
    let player: PlayerDTO
    let fromTeam: TeamDTO?
    let toTeam: TeamDTO?
    let transferDate: Date
    let status: TransferStatusDTO

    func domain(field: String) throws -> PlayerTransfer {
        PlayerTransfer(
            id: try validatedIdentifier(id, field: "\(field).id"),
            player: try player.domain(field: "\(field).player"),
            fromTeam: try fromTeam?.domain(field: "\(field).fromTeam"),
            toTeam: try toTeam?.domain(field: "\(field).toTeam"),
            transferDate: transferDate,
            status: status.domain
        )
    }
}

struct TransferListResponseDTO: Decodable, Sendable {
    let data: [TransferDTO]
    let page: PageInfoDTO

    func domain() throws -> [PlayerTransfer] {
        try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]")
        }
    }

    func domainPage(
        maximumCount: Int,
        expectedStatus: TransferStatus?
    ) throws -> TransferPage {
        guard data.count <= maximumCount else {
            throw SportsDataError.contractViolation(field: "data")
        }
        let transfers = try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]")
        }
        guard Set(transfers.map(\.id)).count == transfers.count else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        guard transfers.allSatisfy({ transfer in
            (transfer.fromTeam != nil || transfer.toTeam != nil)
                && transfer.fromTeam?.id != transfer.toTeam?.id
        }) else {
            throw SportsDataError.contractViolation(field: "data.teams")
        }
        if let expectedStatus,
           !transfers.allSatisfy({ $0.status == expectedStatus }) {
            throw SportsDataError.contractViolation(field: "data.status")
        }
        for (current, next) in zip(transfers, transfers.dropFirst()) {
            guard current.transferDate > next.transferDate
                    || (current.transferDate == next.transferDate && current.id < next.id) else {
                throw SportsDataError.contractViolation(field: "data.order")
            }
        }

        let nextCursor = page.nextCursor?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if page.hasMore {
            guard !transfers.isEmpty,
                  let nextCursor,
                  (1...TransferPaginationContract.maximumCursorLength)
                    .contains(nextCursor.count),
                  nextCursor.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
                  nextCursor.unicodeScalars.allSatisfy({
                      !CharacterSet.controlCharacters.contains($0)
                  }) else {
                throw SportsDataError.contractViolation(field: "page.nextCursor")
            }
        } else if page.nextCursor != nil {
            throw SportsDataError.contractViolation(field: "page.nextCursor")
        }
        return TransferPage(
            transfers: transfers,
            nextCursor: nextCursor,
            hasMore: page.hasMore
        )
    }
}

enum SeasonCalendarEventKindDTO: String, Decodable, Sendable {
    case competitionMilestone = "COMPETITION_MILESTONE"
    case draw = "DRAW"
    case transferWindow = "TRANSFER_WINDOW"
    case internationalBreak = "INTERNATIONAL_BREAK"
    case other = "OTHER"

    var domain: SeasonCalendarEventKind {
        switch self {
        case .competitionMilestone: .competitionMilestone
        case .draw: .draw
        case .transferWindow: .transferWindow
        case .internationalBreak: .internationalBreak
        case .other: .other
        }
    }
}

struct SeasonCalendarEventDTO: Decodable, Sendable {
    let id: String
    let title: LocalizedTextDTO
    let detail: LocalizedTextDTO?
    let startsAt: Date
    let endsAt: Date?
    let kind: SeasonCalendarEventKindDTO
    let competition: CompetitionDTO?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case startsAt
        case endsAt
        case kind
        case competition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(LocalizedTextDTO.self, forKey: .title)
        detail = try container.decode(LocalizedTextDTO?.self, forKey: .detail)
        startsAt = try container.decode(Date.self, forKey: .startsAt)
        endsAt = try container.decode(Date?.self, forKey: .endsAt)
        kind = try container.decode(SeasonCalendarEventKindDTO.self, forKey: .kind)
        competition = try container.decode(CompetitionDTO?.self, forKey: .competition)
    }

    func domain(field: String) throws -> SeasonCalendarEvent {
        let title = try title.validated(field: "\(field).title")
        let detail = try detail?.validated(field: "\(field).detail")
        guard title.arabic.count <= SeasonCalendarDataContract.maximumTitleLength,
              title.english.count <= SeasonCalendarDataContract.maximumTitleLength,
              [title.arabic, title.english].allSatisfy({ text in
                  text.unicodeScalars.allSatisfy({
                      !CharacterSet.controlCharacters.contains($0)
                  })
              }) else {
            throw SportsDataError.contractViolation(field: "\(field).title")
        }
        if let detail {
            guard detail.arabic.count <= SeasonCalendarDataContract.maximumDetailLength,
                  detail.english.count <= SeasonCalendarDataContract.maximumDetailLength,
                  [detail.arabic, detail.english].allSatisfy({ text in
                      text.unicodeScalars.allSatisfy({
                          !CharacterSet.controlCharacters.contains($0)
                      })
                  }) else {
                throw SportsDataError.contractViolation(field: "\(field).detail")
            }
        }
        return SeasonCalendarEvent(
            id: try validatedFollowIdentifier(id, field: "\(field).id"),
            titleArabic: title.arabic,
            titleEnglish: title.english,
            detailArabic: detail?.arabic,
            detailEnglish: detail?.english,
            startsAt: startsAt,
            endsAt: endsAt,
            kind: kind.domain,
            competition: try competition?.domain(field: "\(field).competition")
        )
    }
}

struct SeasonCalendarResponseDTO: Decodable, Sendable {
    let data: SeasonCalendarDataDTO
}

struct SeasonCalendarDataDTO: Decodable, Sendable {
    let rangeStart: Date
    let rangeEnd: Date
    let updatedAt: Date
    let sourceName: String
    let events: [SeasonCalendarEventDTO]

    func domain() throws -> SeasonCalendarSnapshot {
        let windowDuration = rangeEnd.timeIntervalSince(rangeStart)
        guard windowDuration.isFinite,
              windowDuration > 0,
              windowDuration <= SeasonCalendarDataContract.maximumWindowDuration else {
            throw SportsDataError.contractViolation(field: "data.range")
        }
        let sourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...SeasonCalendarDataContract.maximumSourceNameLength)
            .contains(sourceName.count),
              sourceName.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw SportsDataError.contractViolation(field: "data.sourceName")
        }
        guard events.count <= SeasonCalendarDataContract.maximumEventCount else {
            throw SportsDataError.contractViolation(field: "data.events")
        }

        let domainEvents = try events.enumerated().map {
            try $0.element.domain(field: "data.events[\($0.offset)]")
        }
        guard Set(domainEvents.map(\.id)).count == domainEvents.count else {
            throw SportsDataError.contractViolation(field: "data.events.id")
        }
        for event in domainEvents {
            guard event.startsAt >= rangeStart,
                  event.startsAt <= rangeEnd else {
                throw SportsDataError.contractViolation(field: "data.events.startsAt")
            }
            if let endsAt = event.endsAt {
                let duration = endsAt.timeIntervalSince(event.startsAt)
                guard duration.isFinite,
                      duration >= 0,
                      duration <= SeasonCalendarDataContract.maximumEventDuration,
                      endsAt <= rangeEnd else {
                    throw SportsDataError.contractViolation(field: "data.events.endsAt")
                }
            }
        }
        for (current, next) in zip(domainEvents, domainEvents.dropFirst()) {
            guard current.startsAt < next.startsAt
                    || (current.startsAt == next.startsAt && current.id < next.id) else {
                throw SportsDataError.contractViolation(field: "data.events.order")
            }
        }

        var competitionByID: [String: Competition] = [:]
        for competition in domainEvents.compactMap(\.competition) {
            if let existing = competitionByID[competition.id], existing != competition {
                throw SportsDataError.contractViolation(field: "data.events.competition")
            }
            competitionByID[competition.id] = competition
        }

        return SeasonCalendarSnapshot(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            updatedAt: updatedAt,
            sourceName: sourceName,
            events: domainEvents
        )
    }
}

enum StandingFormDTO: String, Decodable, Sendable {
    case win = "WIN"
    case draw = "DRAW"
    case loss = "LOSS"

    var domain: StandingFormResult {
        switch self {
        case .win: .win
        case .draw: .draw
        case .loss: .loss
        }
    }
}

struct StandingRowDTO: Decodable, Sendable {
    let rank: Int
    let team: TeamDTO
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let points: Int
    let form: [StandingFormDTO]?

    func domain(field: String) throws -> StandingRow {
        guard rank >= 1 else {
            throw SportsDataError.contractViolation(field: "\(field).rank")
        }
        let nonnegative = [played, won, drawn, lost, goalsFor, goalsAgainst]
        guard nonnegative.allSatisfy({ $0 >= 0 }), (form ?? []).count <= 5 else {
            throw SportsDataError.contractViolation(field: field)
        }
        return StandingRow(
            rank: rank,
            team: try team.domain(field: "\(field).team"),
            played: played,
            won: won,
            drawn: drawn,
            lost: lost,
            goalsFor: goalsFor,
            goalsAgainst: goalsAgainst,
            points: points,
            form: (form ?? []).map { $0.domain }
        )
    }
}

struct StandingGroupDTO: Decodable, Sendable {
    let groupName: LocalizedTextDTO
    let rows: [StandingRowDTO]

    func domain(field: String) throws -> StandingGroup {
        let name = try groupName.validated(field: "\(field).groupName")
        return StandingGroup(
            groupNameArabic: name.arabic,
            groupNameEnglish: name.english,
            rows: try rows.enumerated().map {
                try $0.element.domain(field: "\(field).rows[\($0.offset)]")
            }
        )
    }
}

struct StandingsResponseDTO: Decodable, Sendable {
    let data: [StandingGroupDTO]

    func domain() throws -> [StandingGroup] {
        try data.enumerated().map { try $0.element.domain(field: "data[\($0.offset)]") }
    }
}

struct FixtureStandingsResponseDTO: Decodable, Sendable {
    let data: FixtureStandingsDataDTO

    func domain(expectedFixture: Fixture) throws -> FixtureStandingsContext {
        try data.domain(expectedFixture: expectedFixture)
    }
}

struct FixtureStandingsDataDTO: Decodable, Sendable {
    let fixtureId: String
    let competition: CompetitionDTO
    let season: SeasonDTO
    let standings: [StandingGroupDTO]
    let source: DataSourceDTO
    let updatedAt: Date

    func domain(expectedFixture: Fixture) throws -> FixtureStandingsContext {
        let fixtureID = try validatedIdentifier(fixtureId, field: "data.fixtureId")
        guard fixtureID == expectedFixture.id else {
            throw SportsDataError.contractViolation(field: "data.fixtureId")
        }
        let competition = try competition.domain(field: "data.competition")
        guard competition.id == expectedFixture.competition.id else {
            throw SportsDataError.contractViolation(field: "data.competition.id")
        }
        let season = try season.domain(field: "data.season")
        if !competition.seasons.isEmpty,
           !competition.seasons.contains(where: { $0.id == season.id }) {
            throw SportsDataError.contractViolation(field: "data.season.id")
        }
        let groups = try standings.enumerated().map {
            try $0.element.domain(field: "data.standings[\($0.offset)]")
        }
        try validateFixtureStandings(groups, expectedFixture: expectedFixture)

        return FixtureStandingsContext(
            fixtureID: fixtureID,
            competition: competition,
            season: season,
            groups: groups,
            sourceName: try validatedSourceName(source, field: "data.source.name"),
            updatedAt: updatedAt
        )
    }
}

struct FixtureHeadToHeadResponseDTO: Decodable, Sendable {
    let data: FixtureHeadToHeadDataDTO

    func domain(
        expectedFixture: Fixture,
        limit: Int
    ) throws -> FixtureHeadToHeadContext {
        try data.domain(expectedFixture: expectedFixture, limit: limit)
    }
}

struct FixtureHeadToHeadDataDTO: Decodable, Sendable {
    let fixtureId: String
    let homeTeam: TeamDTO
    let awayTeam: TeamDTO
    let meetings: [FixtureDTO]
    let source: DataSourceDTO
    let updatedAt: Date

    func domain(
        expectedFixture: Fixture,
        limit: Int
    ) throws -> FixtureHeadToHeadContext {
        guard (1...20).contains(limit) else {
            throw SportsDataError.contractViolation(field: "limit")
        }
        let fixtureID = try validatedIdentifier(fixtureId, field: "data.fixtureId")
        guard fixtureID == expectedFixture.id else {
            throw SportsDataError.contractViolation(field: "data.fixtureId")
        }
        let homeTeam = try homeTeam.domain(field: "data.homeTeam")
        let awayTeam = try awayTeam.domain(field: "data.awayTeam")
        guard homeTeam.id == expectedFixture.homeTeam.id else {
            throw SportsDataError.contractViolation(field: "data.homeTeam.id")
        }
        guard awayTeam.id == expectedFixture.awayTeam.id else {
            throw SportsDataError.contractViolation(field: "data.awayTeam.id")
        }
        guard meetings.count <= limit else {
            throw SportsDataError.contractViolation(field: "data.meetings")
        }
        let meetings = try meetings.enumerated().map {
            try $0.element.domain(field: "data.meetings[\($0.offset)]")
        }
        try validateHeadToHeadMeetings(meetings, expectedFixture: expectedFixture)

        return FixtureHeadToHeadContext(
            fixtureID: fixtureID,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            meetings: meetings,
            sourceName: try validatedSourceName(source, field: "data.source.name"),
            updatedAt: updatedAt
        )
    }
}

private func validateFixtureStandings(
    _ groups: [StandingGroup],
    expectedFixture: Fixture
) throws {
    guard Set(groups.map(\.id)).count == groups.count else {
        throw SportsDataError.contractViolation(field: "data.standings")
    }
    var allTeamIDs: Set<String> = []
    for (groupIndex, group) in groups.enumerated() {
        guard !group.rows.isEmpty else {
            throw SportsDataError.contractViolation(
                field: "data.standings[\(groupIndex)].rows"
            )
        }
        var previousRank = 0
        var groupRanks: Set<Int> = []
        for (rowIndex, row) in group.rows.enumerated() {
            let field = "data.standings[\(groupIndex)].rows[\(rowIndex)]"
            guard row.rank > previousRank,
                  groupRanks.insert(row.rank).inserted,
                  allTeamIDs.insert(row.team.id).inserted else {
                throw SportsDataError.contractViolation(field: field)
            }
            guard row.played == row.won + row.drawn + row.lost else {
                throw SportsDataError.contractViolation(field: "\(field).played")
            }
            previousRank = row.rank
        }
    }
    guard groups.isEmpty
            || (allTeamIDs.contains(expectedFixture.homeTeam.id)
                && allTeamIDs.contains(expectedFixture.awayTeam.id)) else {
        throw SportsDataError.contractViolation(field: "data.standings")
    }
}

private func validateHeadToHeadMeetings(
    _ meetings: [Fixture],
    expectedFixture: Fixture
) throws {
    let expectedTeamIDs = Set([
        expectedFixture.homeTeam.id,
        expectedFixture.awayTeam.id
    ])
    guard Set(meetings.map(\.id)).count == meetings.count else {
        throw SportsDataError.contractViolation(field: "data.meetings")
    }

    for (index, meeting) in meetings.enumerated() {
        let field = "data.meetings[\(index)]"
        guard meeting.id != expectedFixture.id,
              meeting.state == .finished,
              meeting.homeScore != nil,
              meeting.awayScore != nil,
              Set([meeting.homeTeam.id, meeting.awayTeam.id]) == expectedTeamIDs else {
            throw SportsDataError.contractViolation(field: field)
        }
        guard index > 0 else { continue }
        let previous = meetings[index - 1]
        guard previous.kickoff > meeting.kickoff
                || (previous.kickoff == meeting.kickoff && previous.id < meeting.id) else {
            throw SportsDataError.contractViolation(field: "data.meetings")
        }
    }
}

private func validatedSourceName(
    _ source: DataSourceDTO,
    field: String
) throws -> String {
    let name = source.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
        throw SportsDataError.contractViolation(field: field)
    }
    return name
}

struct LeaderDTO: Decodable, Sendable {
    let rank: Int
    let player: PlayerDTO
    let team: TeamDTO
    let value: Double

    func domain(field: String) throws -> CompetitionLeader {
        guard rank >= 1, value.isFinite, value >= 0 else {
            throw SportsDataError.contractViolation(field: field)
        }
        return CompetitionLeader(
            rank: rank,
            player: try player.domain(field: "\(field).player"),
            team: try team.domain(field: "\(field).team"),
            value: value
        )
    }
}

struct LeaderListResponseDTO: Decodable, Sendable {
    let data: [LeaderDTO]
    let page: PageInfoDTO

    func domain() throws -> [CompetitionLeader] {
        try data.enumerated().map { try $0.element.domain(field: "data[\($0.offset)]") }
    }
}

struct FixtureListResponseDTO: Decodable, Sendable {
    let data: [FixtureDTO]
    let page: PageInfoDTO

    func domain() throws -> [Fixture] {
        try data.enumerated().map { try $0.element.domain(field: "data[\($0.offset)]") }
    }
}

struct CompetitionFixturePage: Sendable {
    let fixtures: [Fixture]
    let nextCursor: String?
    let hasMore: Bool
}

struct CompetitionFixtureListResponseDTO: Decodable, Sendable {
    let competitionId: String
    let seasonId: String
    let data: [FixtureDTO]
    let page: PageInfoDTO

    func domain(
        expectedCompetitionID: String,
        expectedSeasonID: String
    ) throws -> CompetitionFixturePage {
        guard competitionId == expectedCompetitionID else {
            throw SportsDataError.contractViolation(field: "competitionId")
        }
        guard seasonId == expectedSeasonID else {
            throw SportsDataError.contractViolation(field: "seasonId")
        }
        let fixtures = try data.enumerated().map {
            try $0.element.domain(field: "data[\($0.offset)]")
        }
        guard fixtures.allSatisfy({ $0.competition.id == expectedCompetitionID }) else {
            throw SportsDataError.contractViolation(field: "data.competition.id")
        }
        guard Set(fixtures.map(\.id)).count == fixtures.count else {
            throw SportsDataError.contractViolation(field: "data.id")
        }
        return CompetitionFixturePage(
            fixtures: fixtures,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }
}

enum FixtureEventTypeDTO: String, Decodable, Sendable {
    case kickoff = "KICKOFF"
    case goal = "GOAL"
    case ownGoal = "OWN_GOAL"
    case penalty = "PENALTY"
    case yellowCard = "YELLOW_CARD"
    case redCard = "RED_CARD"
    case substitution = "SUBSTITUTION"
    case halfTime = "HALF_TIME"
    case fullTime = "FULL_TIME"
    case varReview = "VAR"

    var domain: FixtureEventKind {
        switch self {
        case .kickoff: .kickoff
        case .goal: .goal
        case .ownGoal: .ownGoal
        case .penalty: .penalty
        case .yellowCard: .yellowCard
        case .redCard: .redCard
        case .substitution: .substitution
        case .halfTime: .halfTime
        case .fullTime: .fullTime
        case .varReview: .varReview
        }
    }
}

struct FixtureEventDTO: Decodable, Sendable {
    let id: String
    let revision: Int
    let minute: Int
    let addedTime: Int?
    let type: FixtureEventTypeDTO
    let title: LocalizedTextDTO
    let detail: LocalizedTextDTO
    let teamId: String?
    let playerId: String?
    let secondaryPlayerId: String?
    let isDeleted: Bool

    func domain(field: String) throws -> FixtureEvent {
        let id = try validatedIdentifier(id, field: "\(field).id")
        guard revision >= 0 else {
            throw SportsDataError.contractViolation(field: "\(field).revision")
        }
        guard (0...200).contains(minute) else {
            throw SportsDataError.contractViolation(field: "\(field).minute")
        }
        if let addedTime, addedTime < 0 {
            throw SportsDataError.contractViolation(field: "\(field).addedTime")
        }
        let titles = try title.validated(field: "\(field).title")
        let details = try detail.validated(field: "\(field).detail")
        let teamID = try validatedOptionalIdentifier(teamId, field: "\(field).teamId")
        let playerID = try validatedOptionalIdentifier(playerId, field: "\(field).playerId")
        let secondaryPlayerID = try validatedOptionalIdentifier(
            secondaryPlayerId,
            field: "\(field).secondaryPlayerId"
        )

        return FixtureEvent(
            id: id,
            revision: revision,
            minute: minute,
            addedTime: addedTime,
            kind: type.domain,
            titleArabic: titles.arabic,
            titleEnglish: titles.english,
            detailArabic: details.arabic,
            detailEnglish: details.english,
            teamID: teamID,
            playerID: playerID,
            secondaryPlayerID: secondaryPlayerID
        )
    }

    func mutation(field: String) throws -> FixtureEventMutation {
        let event = try domain(field: field)
        return isDeleted
            ? .deleted(id: event.id, revision: event.revision)
            : .upsert(event)
    }
}

struct FixtureEventsResponseDTO: Decodable, Sendable {
    let data: [FixtureEventDTO]
    let fixture: FixtureDTO
    let fixtureRevision: Int
    let updatedAt: Date

    func domain(
        expectedFixtureID: String,
        afterRevision: Int
    ) throws -> FixtureEventBatch {
        guard afterRevision >= 0 else {
            throw SportsDataError.contractViolation(field: "afterRevision")
        }
        let fixture = try fixture.domain(field: "fixture")
        guard fixture.id == expectedFixtureID else {
            throw SportsDataError.contractViolation(field: "fixture.id")
        }
        guard fixtureRevision == fixture.revision,
              fixtureRevision >= afterRevision else {
            throw SportsDataError.contractViolation(field: "fixtureRevision")
        }

        var previousRevision = afterRevision
        let mutations = try data.enumerated().map { index, value in
            let mutation = try value.mutation(field: "data[\(index)]")
            guard mutation.revision > previousRevision,
                  mutation.revision <= fixtureRevision else {
                throw SportsDataError.contractViolation(field: "data[\(index)].revision")
            }
            previousRevision = mutation.revision
            return mutation
        }

        return FixtureEventBatch(
            fixture: fixture,
            fixtureRevision: fixtureRevision,
            mutations: mutations,
            updatedAt: updatedAt
        )
    }
}

enum PlayerPositionDTO: String, Decodable, Sendable {
    case goalkeeper = "GOALKEEPER"
    case defender = "DEFENDER"
    case midfielder = "MIDFIELDER"
    case forward = "FORWARD"
    case unknown = "UNKNOWN"

    var localizationKey: String {
        switch self {
        case .goalkeeper: "position.goalkeeper"
        case .defender: "position.defender"
        case .midfielder: "position.midfielder"
        case .forward: "position.forward"
        case .unknown: "position.unknown"
        }
    }
}

struct FormationPositionDTO: Decodable, Sendable {
    let line: Int
    let order: Int

    func domain(field: String) throws -> FormationPosition {
        guard (0...4).contains(line), (0...4).contains(order) else {
            throw SportsDataError.contractViolation(field: field)
        }
        return FormationPosition(line: line, order: order)
    }
}

struct LineupPlayerDTO: Decodable, Sendable {
    let id: String
    let number: Int
    let name: String
    let position: PlayerPositionDTO
    let isStarter: Bool?
    let formationPosition: FormationPositionDTO?

    func domain(field: String) throws -> LineupPlayer {
        let id = try validatedIdentifier(id, field: "\(field).id")
        guard (1...99).contains(number) else {
            throw SportsDataError.contractViolation(field: "\(field).number")
        }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120 else {
            throw SportsDataError.contractViolation(field: "\(field).name")
        }
        return LineupPlayer(
            id: id,
            number: number,
            name: name,
            positionKey: position.localizationKey,
            isStarter: isStarter ?? true,
            formationPosition: try formationPosition?.domain(field: "\(field).formationPosition")
        )
    }
}

struct LineupsDTO: Decodable, Sendable {
    let home: [LineupPlayerDTO]
    let away: [LineupPlayerDTO]
    let homeFormation: String?
    let awayFormation: String?

    func homeDomain() throws -> TeamLineup {
        try validatedTeamLineup(
            home,
            formation: homeFormation,
            field: "data.lineups.home"
        )
    }

    func awayDomain() throws -> TeamLineup {
        try validatedTeamLineup(
            away,
            formation: awayFormation,
            field: "data.lineups.away"
        )
    }
}

func validatedTeamLineup(
    _ players: [LineupPlayerDTO],
    formation: String?,
    field: String
) throws -> TeamLineup {
    guard players.count <= 40 else {
        throw SportsDataError.contractViolation(field: field)
    }

    let formation = try formation.map { rawValue in
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value == rawValue,
              TeamLineup.formationComponents(for: value) != nil else {
            throw SportsDataError.contractViolation(field: "\(field).formation")
        }
        return value
    }

    var ids = Set<String>()
    var numbers = Set<Int>()
    var formationPositions = Set<FormationPosition>()
    var starterCount = 0
    let domainPlayers = try players.enumerated().map { index, playerDTO in
        let playerField = "\(field)[\(index)]"
        let player = try playerDTO.domain(field: playerField)
        guard ids.insert(player.id).inserted else {
            throw SportsDataError.contractViolation(field: "\(playerField).id")
        }
        guard numbers.insert(player.number).inserted else {
            throw SportsDataError.contractViolation(field: "\(playerField).number")
        }
        if player.isStarter {
            starterCount += 1
        } else if player.formationPosition != nil {
            throw SportsDataError.contractViolation(field: "\(playerField).formationPosition")
        }
        if let position = player.formationPosition,
           !formationPositions.insert(position).inserted {
            throw SportsDataError.contractViolation(field: "\(playerField).formationPosition")
        }
        return player
    }

    guard starterCount <= 11 else {
        throw SportsDataError.contractViolation(field: field)
    }
    return TeamLineup(formation: formation, players: domainPlayers)
}

enum MatchStatisticTypeDTO: String, CaseIterable, Decodable, Hashable, Sendable {
    case possession = "POSSESSION"
    case shots = "SHOTS"
    case shotsOnTarget = "SHOTS_ON_TARGET"
    case corners = "CORNERS"
    case fouls = "FOULS"
    case offsides = "OFFSIDES"
    case passes = "PASSES"
    case saves = "SAVES"

    var localizationKey: String {
        switch self {
        case .possession: "stat.possession"
        case .shots: "stat.shots"
        case .shotsOnTarget: "stat.shotsOnTarget"
        case .corners: "stat.corners"
        case .fouls: "stat.fouls"
        case .offsides: "stat.offsides"
        case .passes: "stat.passes"
        case .saves: "stat.saves"
        }
    }

    var sortOrder: Int {
        switch self {
        case .possession: 0
        case .shots: 1
        case .shotsOnTarget: 2
        case .corners: 3
        case .fouls: 4
        case .offsides: 5
        case .passes: 6
        case .saves: 7
        }
    }
}

struct MatchStatisticDTO: Decodable, Sendable {
    let id: String
    let type: MatchStatisticTypeDTO
    let homeValue: Double
    let awayValue: Double
    let unit: String

    func domain(field: String) throws -> MatchStatistic {
        let id = try validatedIdentifier(id, field: "\(field).id")
        guard homeValue.isFinite, awayValue.isFinite, homeValue >= 0, awayValue >= 0 else {
            throw SportsDataError.contractViolation(field: field)
        }
        switch type {
        case .possession:
            guard unit == "%",
                  homeValue <= 100,
                  awayValue <= 100,
                  abs(homeValue + awayValue - 100) <= 0.01 else {
                throw SportsDataError.contractViolation(field: field)
            }
        case .shots, .shotsOnTarget, .corners, .fouls, .offsides, .passes, .saves:
            guard unit.isEmpty,
                  homeValue.rounded() == homeValue,
                  awayValue.rounded() == awayValue else {
                throw SportsDataError.contractViolation(field: field)
            }
        }
        return MatchStatistic(
            id: id,
            titleKey: type.localizationKey,
            homeValue: homeValue,
            awayValue: awayValue,
            unit: unit
        )
    }
}

func validatedMatchStatistics(
    _ statistics: [MatchStatisticDTO],
    field: String
) throws -> [MatchStatistic] {
    guard statistics.count <= MatchStatisticTypeDTO.allCases.count else {
        throw SportsDataError.contractViolation(field: field)
    }
    var ids = Set<String>()
    var types = Set<MatchStatisticTypeDTO>()
    var validated = [(dto: MatchStatisticDTO, domain: MatchStatistic)]()
    for (index, statistic) in statistics.enumerated() {
        let statisticField = "\(field)[\(index)]"
        let domain = try statistic.domain(field: statisticField)
        guard ids.insert(domain.id).inserted,
              types.insert(statistic.type).inserted else {
            throw SportsDataError.contractViolation(field: statisticField)
        }
        validated.append((statistic, domain))
    }

    if let shots = statistics.first(where: { $0.type == .shots }),
       let shotsOnTarget = statistics.first(where: { $0.type == .shotsOnTarget }),
       (shotsOnTarget.homeValue > shots.homeValue || shotsOnTarget.awayValue > shots.awayValue) {
        throw SportsDataError.contractViolation(field: field)
    }

    return validated
        .sorted { $0.dto.type.sortOrder < $1.dto.type.sortOrder }
        .map { $0.domain }
}

struct DataSourceDTO: Decodable, Sendable {
    let name: String
}

struct FixtureDetailResponseDTO: Decodable, Sendable {
    let data: FixtureDetailDataDTO
}

struct FixtureDetailDataDTO: Decodable, Sendable {
    let fixture: FixtureDTO
    let events: [FixtureEventDTO]
    let lineups: LineupsDTO
    let statistics: [MatchStatisticDTO]
    let source: DataSourceDTO
    let updatedAt: Date

    func domain() throws -> MatchDetails {
        let sourceName = try validatedSourceName(source, field: "data.source.name")

        let eventMutations = try events.enumerated().map {
            try $0.element.mutation(field: "data.events[\($0.offset)]")
        }
        let details = MatchDetails(
            fixture: try fixture.domain(field: "data.fixture"),
            events: eventMutations.compactMap(\.event),
            homeLineup: try lineups.homeDomain(),
            awayLineup: try lineups.awayDomain(),
            statistics: try validatedMatchStatistics(statistics, field: "data.statistics"),
            sourceName: sourceName,
            updatedAt: updatedAt
        )
        return try MatchLiveTimeline(snapshot: details).details
    }
}

struct PredictionGameListResponseDTO: Decodable, Sendable {
    let data: [PredictionGameDTO]

    func domain() throws -> [PredictionGame] {
        guard data.count <= 20 else {
            throw SportsDataError.contractViolation(field: "data")
        }
        var gameIDs = Set<String>()
        return try data.enumerated().map { index, game in
            let domain = try game.domain(field: "data[\(index)]")
            guard gameIDs.insert(domain.id).inserted else {
                throw SportsDataError.contractViolation(field: "data[\(index)].id")
            }
            return domain
        }
    }
}

enum PredictionGameStateDTO: String, Decodable, Sendable {
    case open = "OPEN"
    case locked = "LOCKED"
    case settled = "SETTLED"
    case cancelled = "CANCELLED"

    var domain: PredictionGameState {
        switch self {
        case .open: .open
        case .locked: .locked
        case .settled: .settled
        case .cancelled: .cancelled
        }
    }
}

struct PredictionGameDTO: Decodable, Sendable {
    let id: String
    let title: LocalizedTextDTO
    let summary: LocalizedTextDTO
    let lockAt: Date
    let state: PredictionGameStateDTO
    let rulesURL: URL
    let groups: [PredictionGroupDTO]

    func domain(field: String) throws -> PredictionGame {
        let id = try validatedFollowIdentifier(id, field: "\(field).id")
        let title = try title.validated(field: "\(field).title")
        let summary = try summary.validated(field: "\(field).summary")
        guard rulesURL.scheme?.lowercased() == "https",
              rulesURL.host != nil,
              rulesURL.user == nil,
              rulesURL.password == nil,
              rulesURL.fragment == nil,
              rulesURL.absoluteString.count <= 2_048,
              (1...12).contains(groups.count) else {
            throw SportsDataError.contractViolation(field: field)
        }

        var groupIDs = Set<String>()
        var teamIDs = Set<String>()
        let domainGroups = try groups.enumerated().map { index, group in
            let groupField = "\(field).groups[\(index)]"
            let domain = try group.domain(field: groupField)
            guard groupIDs.insert(domain.id).inserted,
                  domain.teams.allSatisfy({ teamIDs.insert($0.id).inserted }) else {
                throw SportsDataError.contractViolation(field: groupField)
            }
            return domain
        }
        return PredictionGame(
            id: id,
            titleArabic: title.arabic,
            titleEnglish: title.english,
            summaryArabic: summary.arabic,
            summaryEnglish: summary.english,
            lockAt: lockAt,
            state: state.domain,
            rulesURL: rulesURL,
            groups: domainGroups
        )
    }
}

struct PredictionGroupDTO: Decodable, Sendable {
    let id: String
    let name: LocalizedTextDTO
    let teams: [TeamDTO]
    let qualifyingPositions: Int

    func domain(field: String) throws -> PredictionGroup {
        let id = try validatedFollowIdentifier(id, field: "\(field).id")
        let name = try name.validated(field: "\(field).name")
        guard (2...8).contains(teams.count),
              (1..<teams.count).contains(qualifyingPositions) else {
            throw SportsDataError.contractViolation(field: field)
        }
        var teamIDs = Set<String>()
        let domainTeams = try teams.enumerated().map { index, team in
            let domain = try team.domain(field: "\(field).teams[\(index)]")
            guard teamIDs.insert(domain.id).inserted else {
                throw SportsDataError.contractViolation(field: "\(field).teams[\(index)].id")
            }
            return domain
        }
        return PredictionGroup(
            id: id,
            nameArabic: name.arabic,
            nameEnglish: name.english,
            teams: domainTeams,
            qualifyingPositions: qualifyingPositions
        )
    }
}

struct PredictionGroupRankingDTO: Codable, Sendable {
    let groupId: String
    let orderedTeamIds: [String]

    init(_ ranking: PredictionGroupRanking) {
        groupId = ranking.groupID
        orderedTeamIds = ranking.orderedTeamIDs
    }

    func domain(field: String) throws -> PredictionGroupRanking {
        let groupID = try validatedFollowIdentifier(groupId, field: "\(field).groupId")
        guard (2...8).contains(orderedTeamIds.count) else {
            throw SportsDataError.contractViolation(field: "\(field).orderedTeamIds")
        }
        let teamIDs = try orderedTeamIds.enumerated().map { index, teamID in
            try validatedFollowIdentifier(teamID, field: "\(field).orderedTeamIds[\(index)]")
        }
        guard Set(teamIDs).count == teamIDs.count else {
            throw SportsDataError.contractViolation(field: "\(field).orderedTeamIds")
        }
        return PredictionGroupRanking(groupID: groupID, orderedTeamIDs: teamIDs)
    }
}

struct PredictionEntryInputDTO: Encodable, Sendable {
    let rankings: [PredictionGroupRankingDTO]

    init(rankings: [PredictionGroupRanking]) {
        self.rankings = rankings.map(PredictionGroupRankingDTO.init)
    }
}

struct PredictionEntryResponseDTO: Decodable, Sendable {
    let data: PredictionEntryDataDTO
}

struct PredictionEntryDataDTO: Decodable, Sendable {
    let gameId: String
    let rankings: [PredictionGroupRankingDTO]
    let updatedAt: Date

    func domain(for game: PredictionGame) throws -> PredictionEntry {
        let gameID = try validatedFollowIdentifier(gameId, field: "data.gameId")
        guard gameID == game.id else {
            throw SportsDataError.contractViolation(field: "data.gameId")
        }
        let domainRankings = try rankings.enumerated().map { index, ranking in
            try ranking.domain(field: "data.rankings[\(index)]")
        }
        try PredictionEntryContract.validate(domainRankings, for: game)
        return PredictionEntry(
            gameID: gameID,
            rankings: domainRankings,
            updatedAt: updatedAt
        )
    }
}

private func validatedIdentifier(_ value: String, field: String) throws -> String {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
        throw SportsDataError.contractViolation(field: field)
    }
    return value
}

private func validatedFollowIdentifier(_ value: String, field: String) throws -> String {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let forbidden = CharacterSet(charactersIn: "/\\?#")
    guard (1...128).contains(value.count),
          value.rangeOfCharacter(from: forbidden) == nil,
          value.unicodeScalars.allSatisfy({
              !CharacterSet.controlCharacters.contains($0)
          }) else {
        throw SportsDataError.contractViolation(field: field)
    }
    return value
}

private func validatedOptionalIdentifier(
    _ value: String?,
    field: String
) throws -> String? {
    guard let value else { return nil }
    return try validatedIdentifier(value, field: field)
}
