import Foundation

enum WidgetMatchContract {
    static let appGroupInfoKey = "SportsAppGroupIdentifier"
    static let fileName = "next-match-v1.json"
    static let widgetKind = "NextMatchWidget"
    static let schemaVersion = 1
    static let maximumIdentifierLength = 128
    static let maximumTextLength = 120
    static let maximumEncodedSize = 16 * 1_024
    static let liveStaleInterval: TimeInterval = 15 * 60
    static let upcomingStaleInterval: TimeInterval = 24 * 60 * 60
    static let kickoffGraceInterval: TimeInterval = 15 * 60
}

enum WidgetDisplayLanguage: String, Codable, Hashable, Sendable {
    case arabic = "ar"
    case english = "en"

    var locale: Locale { Locale(identifier: rawValue) }
}

enum WidgetMatchState: String, Codable, Hashable, Sendable {
    case upcoming
    case live
    case halfTime
    case finished
    case postponed
    case cancelled

    var localizationKey: String {
        "widget.state.\(rawValue)"
    }

    var isLive: Bool {
        self == .live || self == .halfTime
    }
}

enum WidgetMatchSnapshotError: Error, Equatable, Sendable {
    case invalidFile
    case invalidSchemaVersion
    case invalidIdentifier
    case invalidText
    case invalidDate
    case invalidScore
    case invalidMinute
    case invalidRevision
}

struct WidgetMatchSnapshot: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let fixtureID: String
    let competitionArabic: String
    let competitionEnglish: String
    let homeTeamArabic: String
    let homeTeamEnglish: String
    let awayTeamArabic: String
    let awayTeamEnglish: String
    let kickoff: Date
    let state: WidgetMatchState
    let minute: Int?
    let homeScore: Int?
    let awayScore: Int?
    let revision: Int
    let preferredLanguage: WidgetDisplayLanguage
    let isDemo: Bool
    let savedAt: Date

    init(
        fixtureID: String,
        competitionArabic: String,
        competitionEnglish: String,
        homeTeamArabic: String,
        homeTeamEnglish: String,
        awayTeamArabic: String,
        awayTeamEnglish: String,
        kickoff: Date,
        state: WidgetMatchState,
        minute: Int?,
        homeScore: Int?,
        awayScore: Int?,
        revision: Int,
        preferredLanguage: WidgetDisplayLanguage,
        isDemo: Bool,
        savedAt: Date,
        schemaVersion: Int = WidgetMatchContract.schemaVersion
    ) throws {
        guard schemaVersion == WidgetMatchContract.schemaVersion else {
            throw WidgetMatchSnapshotError.invalidSchemaVersion
        }
        guard Self.isValidIdentifier(fixtureID) else {
            throw WidgetMatchSnapshotError.invalidIdentifier
        }
        guard [
            competitionArabic,
            competitionEnglish,
            homeTeamArabic,
            homeTeamEnglish,
            awayTeamArabic,
            awayTeamEnglish
        ].allSatisfy(Self.isValidText) else {
            throw WidgetMatchSnapshotError.invalidText
        }
        guard kickoff.timeIntervalSinceReferenceDate.isFinite,
              savedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw WidgetMatchSnapshotError.invalidDate
        }
        guard (homeScore == nil) == (awayScore == nil),
              [homeScore, awayScore]
                .compactMap({ $0 })
                .allSatisfy({ (0...99).contains($0) }),
              !state.isLive || homeScore != nil,
              state != .upcoming || homeScore == nil else {
            throw WidgetMatchSnapshotError.invalidScore
        }
        guard minute.map({ (0...200).contains($0) }) ?? true,
              state != .upcoming || minute == nil else {
            throw WidgetMatchSnapshotError.invalidMinute
        }
        guard revision >= 0 else {
            throw WidgetMatchSnapshotError.invalidRevision
        }

        self.schemaVersion = schemaVersion
        self.fixtureID = fixtureID
        self.competitionArabic = competitionArabic
        self.competitionEnglish = competitionEnglish
        self.homeTeamArabic = homeTeamArabic
        self.homeTeamEnglish = homeTeamEnglish
        self.awayTeamArabic = awayTeamArabic
        self.awayTeamEnglish = awayTeamEnglish
        self.kickoff = kickoff
        self.state = state
        self.minute = minute
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.revision = revision
        self.preferredLanguage = preferredLanguage
        self.isDemo = isDemo
        self.savedAt = savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            fixtureID: container.decode(String.self, forKey: .fixtureID),
            competitionArabic: container.decode(String.self, forKey: .competitionArabic),
            competitionEnglish: container.decode(String.self, forKey: .competitionEnglish),
            homeTeamArabic: container.decode(String.self, forKey: .homeTeamArabic),
            homeTeamEnglish: container.decode(String.self, forKey: .homeTeamEnglish),
            awayTeamArabic: container.decode(String.self, forKey: .awayTeamArabic),
            awayTeamEnglish: container.decode(String.self, forKey: .awayTeamEnglish),
            kickoff: container.decode(Date.self, forKey: .kickoff),
            state: container.decode(WidgetMatchState.self, forKey: .state),
            minute: container.decodeIfPresent(Int.self, forKey: .minute),
            homeScore: container.decodeIfPresent(Int.self, forKey: .homeScore),
            awayScore: container.decodeIfPresent(Int.self, forKey: .awayScore),
            revision: container.decode(Int.self, forKey: .revision),
            preferredLanguage: container.decode(
                WidgetDisplayLanguage.self,
                forKey: .preferredLanguage
            ),
            isDemo: container.decode(Bool.self, forKey: .isDemo),
            savedAt: container.decode(Date.self, forKey: .savedAt),
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion)
        )
    }

    func competitionName(in language: WidgetDisplayLanguage) -> String {
        language == .arabic ? competitionArabic : competitionEnglish
    }

    func homeTeamName(in language: WidgetDisplayLanguage) -> String {
        language == .arabic ? homeTeamArabic : homeTeamEnglish
    }

    func awayTeamName(in language: WidgetDisplayLanguage) -> String {
        language == .arabic ? awayTeamArabic : awayTeamEnglish
    }

    func isStale(at now: Date) -> Bool {
        if state.isLive {
            return now.timeIntervalSince(savedAt) > WidgetMatchContract.liveStaleInterval
        }
        if state == .upcoming {
            return now.timeIntervalSince(savedAt) > WidgetMatchContract.upcomingStaleInterval
                || now.timeIntervalSince(kickoff) > WidgetMatchContract.kickoffGraceInterval
        }
        return true
    }

    var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "sportshub"
        components.host = "fixtures"
        components.path = "/\(fixtureID)"
        return components.url
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case fixtureID
        case competitionArabic
        case competitionEnglish
        case homeTeamArabic
        case homeTeamEnglish
        case awayTeamArabic
        case awayTeamEnglish
        case kickoff
        case state
        case minute
        case homeScore
        case awayScore
        case revision
        case preferredLanguage
        case isDemo
        case savedAt
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        guard (1...WidgetMatchContract.maximumIdentifierLength).contains(value.count),
              value != ".",
              value != ".." else {
            return false
        }
        let punctuation = CharacterSet(charactersIn: "-._~")
        return value.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) || punctuation.contains(scalar)
        }
    }

    private static func isValidText(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == value
            && (1...WidgetMatchContract.maximumTextLength).contains(value.count)
            && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }
}

struct WidgetMatchSnapshotStore: Sendable {
    let fileURL: URL

    static func appGroup(
        identifier: String,
        fileManager: FileManager = .default
    ) -> WidgetMatchSnapshotStore? {
        let identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard identifier.hasPrefix("group."),
              (7...255).contains(identifier.count),
              let containerURL = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: identifier
              ) else {
            return nil
        }
        return WidgetMatchSnapshotStore(
            fileURL: containerURL.appendingPathComponent(
                WidgetMatchContract.fileName,
                isDirectory: false
            )
        )
    }

    func read() throws -> WidgetMatchSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true,
              let fileSize = values.fileSize,
              (1...WidgetMatchContract.maximumEncodedSize).contains(fileSize) else {
            throw WidgetMatchSnapshotError.invalidFile
        }
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        guard data.count <= WidgetMatchContract.maximumEncodedSize else {
            throw WidgetMatchSnapshotError.invalidFile
        }
        return try Self.decoder.decode(WidgetMatchSnapshot.self, from: data)
    }

    func write(_ snapshot: WidgetMatchSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(snapshot)
        guard data.count <= WidgetMatchContract.maximumEncodedSize else {
            throw WidgetMatchSnapshotError.invalidFile
        }
        try data.write(to: fileURL, options: [.atomic])
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
