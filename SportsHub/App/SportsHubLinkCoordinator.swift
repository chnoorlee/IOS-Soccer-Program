import Combine
import Foundation

@MainActor
final class SportsHubLinkCoordinator: ObservableObject {
    @Published private(set) var pendingRoute: SportsHubRoute?
    @Published private(set) var presentationError: SportsHubLinkError?

    private let policy: SportsHubLinkPolicy

    init(
        policy: SportsHubLinkPolicy,
        seedUITestRoute: Bool = true
    ) {
        self.policy = policy
        if seedUITestRoute {
            seedRouteFromProcessArguments()
        }
    }

    convenience init(bundle: Bundle = .main) {
        let rawValue = (bundle.object(
            forInfoDictionaryKey: "SportsPublicWebBaseURL"
        ) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let policy: SportsHubLinkPolicy
        if let rawValue, !rawValue.isEmpty, let url = URL(string: rawValue) {
            policy = (try? SportsHubLinkPolicy(publicBaseURL: url)) ?? .localOnly
        } else {
            policy = .localOnly
        }
        self.init(policy: policy)
    }

    func receive(_ url: URL) {
        do {
            pendingRoute = try policy.route(from: url)
            presentationError = nil
        } catch let error as SportsHubLinkError {
            presentationError = error
        } catch {
            presentationError = .unsupportedURL
        }
    }

    func consumePendingRoute() -> SportsHubRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func dismissPresentationError() {
        presentationError = nil
    }

    func publicURL(for route: SportsHubRoute) -> URL? {
        policy.publicURL(for: route)
    }

    private func seedRouteFromProcessArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-ui-test-deep-link"),
              arguments.indices.contains(flagIndex + 1),
              let url = URL(string: arguments[flagIndex + 1]) else {
            return
        }
        receive(url)
        #endif
    }
}
