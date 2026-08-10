import Foundation

enum SportsHubRoute: Hashable, Identifiable, Sendable {
    case fixture(String)
    case article(String)
    case video(String)
    case team(String)
    case player(String)
    case competition(String)

    var id: String {
        "\(collection):\(entityID)"
    }

    var entityID: String {
        switch self {
        case let .fixture(id), let .article(id), let .video(id), let .team(id),
             let .player(id), let .competition(id):
            id
        }
    }

    var collection: String {
        switch self {
        case .fixture: "fixtures"
        case .article: "articles"
        case .video: "videos"
        case .team: "teams"
        case .player: "players"
        case .competition: "competitions"
        }
    }

    var preferredTab: AppTab {
        switch self {
        case .fixture: .matches
        case .article, .video, .team, .player, .competition: .explore
        }
    }

    fileprivate static func make(
        collection: String,
        entityID: String
    ) -> SportsHubRoute? {
        switch collection {
        case "fixtures": .fixture(entityID)
        case "articles": .article(entityID)
        case "videos": .video(entityID)
        case "teams": .team(entityID)
        case "players": .player(entityID)
        case "competitions": .competition(entityID)
        default: nil
        }
    }
}

enum SportsHubLinkError: Error, Equatable, Sendable {
    case invalidPublicBaseURL
    case unsupportedURL
    case invalidRoute
}

struct SportsHubLinkPolicy: Sendable {
    static let customScheme = "sportshub"
    static let localOnly = SportsHubLinkPolicy(
        publicOrigin: nil,
        publicBasePath: []
    )

    private struct PublicOrigin: Sendable {
        let host: String
        let port: Int?
    }

    private let publicOrigin: PublicOrigin?
    private let publicBasePath: [String]

    init(publicBaseURL: URL?) throws {
        guard let publicBaseURL else {
            self = .localOnly
            return
        }

        guard let components = URLComponents(
            string: publicBaseURL.absoluteString
        ),
        components.scheme?.lowercased() == "https",
        let host = components.host?.lowercased(),
        !host.isEmpty,
        components.user == nil,
        components.password == nil,
        components.port == nil || components.port == 443,
        components.query == nil,
        components.fragment == nil else {
            throw SportsHubLinkError.invalidPublicBaseURL
        }

        let basePath = try Self.decodePath(
            components.percentEncodedPath,
            allowOriginRoot: true,
            error: .invalidPublicBaseURL
        )
        guard basePath.allSatisfy(Self.isValidIdentifier) else {
            throw SportsHubLinkError.invalidPublicBaseURL
        }

        self.init(
            publicOrigin: PublicOrigin(host: host, port: components.port),
            publicBasePath: basePath
        )
    }

    private init(publicOrigin: PublicOrigin?, publicBasePath: [String]) {
        self.publicOrigin = publicOrigin
        self.publicBasePath = publicBasePath
    }

    func publicURL(for route: SportsHubRoute) -> URL? {
        guard let publicOrigin,
              Self.isValidIdentifier(route.entityID) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = publicOrigin.host
        components.port = publicOrigin.port
        components.path = Self.path(
            components: publicBasePath + [route.collection, route.entityID]
        )
        return components.url
    }

    func customURL(for route: SportsHubRoute) -> URL? {
        guard Self.isValidIdentifier(route.entityID) else { return nil }

        var components = URLComponents()
        components.scheme = Self.customScheme
        components.host = route.collection
        components.path = Self.path(components: [route.entityID])
        return components.url
    }

    func route(from url: URL) throws -> SportsHubRoute {
        guard let components = URLComponents(string: url.absoluteString),
        let scheme = components.scheme?.lowercased() else {
            throw SportsHubLinkError.unsupportedURL
        }

        switch scheme {
        case Self.customScheme:
            return try customRoute(from: components)
        case "https":
            return try publicRoute(from: components)
        default:
            throw SportsHubLinkError.unsupportedURL
        }
    }

    private func customRoute(from components: URLComponents) throws -> SportsHubRoute {
        guard components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil,
              let collection = components.host?.lowercased(),
              !collection.isEmpty else {
            throw SportsHubLinkError.invalidRoute
        }

        let path = try Self.decodePath(
            components.percentEncodedPath,
            allowOriginRoot: false,
            error: .invalidRoute
        )
        guard path.count == 1,
              Self.isValidIdentifier(path[0]),
              let route = SportsHubRoute.make(collection: collection, entityID: path[0]) else {
            throw SportsHubLinkError.invalidRoute
        }
        return route
    }

    private func publicRoute(from components: URLComponents) throws -> SportsHubRoute {
        guard let publicOrigin,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == publicOrigin.host,
              Self.normalizedHTTPSPort(components.port)
                == Self.normalizedHTTPSPort(publicOrigin.port) else {
            throw SportsHubLinkError.unsupportedURL
        }

        let path = try Self.decodePath(
            components.percentEncodedPath,
            allowOriginRoot: false,
            error: .invalidRoute
        )
        guard path.count == publicBasePath.count + 2,
              Array(path.prefix(publicBasePath.count)) == publicBasePath else {
            throw SportsHubLinkError.invalidRoute
        }

        let collection = path[publicBasePath.count]
        let entityID = path[publicBasePath.count + 1]
        guard Self.isValidIdentifier(entityID),
              let route = SportsHubRoute.make(
                collection: collection,
                entityID: entityID
              ) else {
            throw SportsHubLinkError.invalidRoute
        }
        return route
    }

    private static func normalizedHTTPSPort(_ port: Int?) -> Int {
        port ?? 443
    }

    private static func path(components: [String]) -> String {
        guard !components.isEmpty else { return "" }
        return "/" + components.joined(separator: "/")
    }

    private static func decodePath(
        _ percentEncodedPath: String,
        allowOriginRoot: Bool,
        error: SportsHubLinkError
    ) throws -> [String] {
        if percentEncodedPath.isEmpty || percentEncodedPath == "/" {
            if allowOriginRoot { return [] }
            throw error
        }
        guard percentEncodedPath.hasPrefix("/"),
              !percentEncodedPath.hasSuffix("/"),
              !percentEncodedPath.contains("//") else {
            throw error
        }

        let encodedComponents = percentEncodedPath
            .dropFirst()
            .split(separator: "/", omittingEmptySubsequences: false)
        var decodedComponents: [String] = []
        decodedComponents.reserveCapacity(encodedComponents.count)
        for encodedComponent in encodedComponents {
            guard !encodedComponent.isEmpty,
                  let decoded = String(encodedComponent).removingPercentEncoding,
                  !decoded.isEmpty,
                  !decoded.contains("/"),
                  !decoded.contains("\\") else {
                throw error
            }
            decodedComponents.append(decoded)
        }
        var canonicalComponents = URLComponents()
        canonicalComponents.path = Self.path(components: decodedComponents)
        guard canonicalComponents.percentEncodedPath == percentEncodedPath else {
            throw error
        }
        return decodedComponents
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        guard (1...128).contains(value.count),
              value != ".",
              value != ".." else {
            return false
        }

        let punctuation = CharacterSet(charactersIn: "-._~")
        return value.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) || punctuation.contains(scalar)
        }
    }
}
