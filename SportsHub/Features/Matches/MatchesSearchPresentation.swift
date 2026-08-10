import Foundation

enum MatchesSearchState: Equatable, Sendable {
    case prompt
    case tooShort
    case empty
    case results
}

struct MatchesSearchPresentation: Equatable, Sendable {
    let fixtures: [Fixture]
    let state: MatchesSearchState

    init(fixtures candidates: [Fixture], query: String) {
        let normalizedQuery = Self.normalize(query)

        guard !normalizedQuery.isEmpty else {
            fixtures = []
            state = .prompt
            return
        }
        guard normalizedQuery.count >= 2 else {
            fixtures = []
            state = .tooShort
            return
        }

        fixtures = candidates.filter { fixture in
            Self.searchableValues(for: fixture).contains { value in
                Self.normalize(value).contains(normalizedQuery)
            }
        }
        state = fixtures.isEmpty ? .empty : .results
    }

    private static func searchableValues(for fixture: Fixture) -> [String] {
        [
            fixture.homeTeam.nameArabic,
            fixture.homeTeam.nameEnglish,
            fixture.homeTeam.monogram,
            fixture.awayTeam.nameArabic,
            fixture.awayTeam.nameEnglish,
            fixture.awayTeam.monogram,
            fixture.competition.nameArabic,
            fixture.competition.nameEnglish,
            fixture.venueArabic,
            fixture.venueEnglish
        ]
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .replacingOccurrences(of: "ـ", with: "")
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ٱ", with: "ا")
            .replacingOccurrences(of: "ى", with: "ي")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
