import Foundation

enum ContextualAlertEligibility: Equatable, Sendable {
    case ineligible
    case followedEntity
    case fixture(FixtureFollowReason)

    var isEligible: Bool {
        self != .ineligible
    }

    var localizationKey: String? {
        switch self {
        case .ineligible:
            nil
        case .followedEntity:
            "contextualAlerts.eligible.entity"
        case let .fixture(reason):
            "contextualAlerts.eligible.fixture.\(reason.rawValue)"
        }
    }
}

struct ContextualAlertPresentation: Equatable, Sendable {
    let eligibility: ContextualAlertEligibility

    init(
        entityType: FollowEntityType,
        entityID: String,
        follows: [SportsFollow]
    ) {
        eligibility = follows.contains {
            $0.type == entityType && $0.entityID == entityID
        } ? .followedEntity : .ineligible
    }

    init(fixture: Fixture, follows: [SportsFollow]) {
        let reason = FixtureFollowMatcher(follows: follows).reason(for: fixture)
        eligibility = reason.map { .fixture($0) } ?? .ineligible
    }
}
