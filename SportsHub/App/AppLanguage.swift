import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var layoutDirection: LayoutDirection {
        self == .arabic ? .rightToLeft : .leftToRight
    }

    var nativeName: String {
        switch self {
        case .arabic: "العربية"
        case .english: "English"
        }
    }
}
