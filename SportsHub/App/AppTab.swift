import Foundation

enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case matches
    case explore
    case following
    case profile

    var id: String { rawValue }

    var titleKey: String {
        "nav.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .matches: "sportscourt.fill"
        case .explore: "safari.fill"
        case .following: "star.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}
