import Foundation

struct CommunityConfiguration: Equatable, Sendable {
    let isEnabled: Bool
    let standardsURL: URL?
    let supportURL: URL?

    init(isEnabled: Bool, standardsURL: URL?, supportURL: URL?) {
        self.isEnabled = isEnabled
        self.standardsURL = standardsURL.flatMap {
            Self.securePublisherURL($0.absoluteString)
        }
        self.supportURL = supportURL.flatMap {
            Self.securePublisherURL($0.absoluteString)
        }
    }

    var isReleaseGateSatisfied: Bool {
        isEnabled && standardsURL != nil && supportURL != nil
    }

    static let developmentDisabled = CommunityConfiguration(
        isEnabled: false,
        standardsURL: nil,
        supportURL: nil
    )

    static func from(bundle: Bundle) -> CommunityConfiguration {
        CommunityConfiguration(
            isEnabled: booleanValue(
                bundle.object(forInfoDictionaryKey: "SportsCommunityEnabled")
            ),
            standardsURL: securePublisherURL(
                bundle.object(forInfoDictionaryKey: "SportsCommunityStandardsURL") as? String
            ),
            supportURL: securePublisherURL(
                bundle.object(forInfoDictionaryKey: "SportsCommunitySupportURL") as? String
            )
        )
    }

    private static func booleanValue(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? String {
            return ["1", "true", "yes"].contains(value.lowercased())
        }
        return false
    }

    private static func securePublisherURL(_ value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host,
              !host.isEmpty,
              host.lowercased() != "invalid",
              !host.lowercased().hasSuffix(".invalid") else {
            return nil
        }
        return url
    }
}
