import Foundation

enum GlobalSearchContract {
    static let minimumQueryLength = 2
    static let maximumQueryLength = 100
    static let maximumResultCount = 100
    static let debounceNanoseconds: UInt64 = 350_000_000

    static var validQueryLength: ClosedRange<Int> {
        minimumQueryLength...maximumQueryLength
    }
}

enum ArabicSearchNormalizer {
    static func normalize(_ value: String) -> String {
        let decomposed = value.decomposedStringWithCompatibilityMapping
        let folded = decomposed.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "ar")
        )
        var withoutMarks = ""
        for scalar in folded.unicodeScalars
        where scalar.value != 0x0640 && !CharacterSet.nonBaseCharacters.contains(scalar) {
            withoutMarks.unicodeScalars.append(scalar)
        }
        return withoutMarks
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ى", with: "ي")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func matchPriority(
        query: String,
        primaryValues: [String],
        secondaryValues: [String] = []
    ) -> Int? {
        let query = normalize(query)
        guard query.count >= GlobalSearchContract.minimumQueryLength else { return nil }

        let primary = primaryValues.map(normalize)
        if primary.contains(query) { return 0 }
        if primary.contains(where: { $0.hasPrefix(query) }) { return 1 }
        if primary.contains(where: { $0.contains(query) }) { return 2 }
        if secondaryValues.map(normalize).contains(where: { $0.contains(query) }) { return 3 }
        return nil
    }
}
