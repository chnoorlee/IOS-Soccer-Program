import Foundation

protocol EditorialImageMediaPayload: Sendable {
    var url: URL { get }
    var contentType: EditorialImageContentType { get }
    var width: Int { get }
    var height: Int { get }
}

extension ArticleHeroMedia: EditorialImageMediaPayload {}
extension VideoPosterMedia: EditorialImageMediaPayload {}

struct ArticleMediaConfiguration: Hashable, Sendable {
    let allowedHosts: Set<String>

    init(allowedHosts: some Sequence<String>) {
        self.allowedHosts = Set(allowedHosts.compactMap(Self.normalizedHost))
    }

    static func from(bundle: Bundle = .main) -> ArticleMediaConfiguration {
        let value = bundle.object(forInfoDictionaryKey: "SportsMediaAllowedHosts") as? String
        let hosts = value?
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace })
            .map(String.init) ?? []
        return ArticleMediaConfiguration(allowedHosts: hosts)
    }

    func permits(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host.flatMap(Self.normalizedHost),
              allowedHosts.contains(host),
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.fragment == nil,
              !url.path.isEmpty,
              url.path != "/" else {
            return false
        }
        return true
    }

    private static func normalizedHost(_ rawValue: String) -> String? {
        let host = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty,
              !host.contains("*"),
              !host.contains("/"),
              !host.contains(":"),
              !host.hasSuffix("."),
              host != "localhost",
              !host.hasSuffix(".local"),
              !isIPv4Address(host) else {
            return nil
        }
        return host
    }

    private static func isIPv4Address(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let value = Int(part) else {
                return false
            }
            return (0...255).contains(value)
        }
    }
}

typealias VideoPosterMediaConfiguration = ArticleMediaConfiguration

enum ArticleHeroImageLoadError: Error, Equatable {
    case disallowedURL
    case invalidResponse
    case unexpectedStatus(Int)
    case unexpectedContentType
    case responseTooLarge
    case invalidImage
}

typealias VideoPosterImageLoadError = ArticleHeroImageLoadError

enum ArticleHeroImageResponseValidator {
    static func validateHeaders(
        statusCode: Int,
        mimeType: String?,
        expectedContentType: ArticleHeroMediaContentType,
        expectedContentLength: Int64
    ) throws {
        guard statusCode == 200 else {
            throw ArticleHeroImageLoadError.unexpectedStatus(statusCode)
        }
        guard mimeType?.lowercased() == expectedContentType.rawValue else {
            throw ArticleHeroImageLoadError.unexpectedContentType
        }
        guard expectedContentLength >= -1 else {
            throw ArticleHeroImageLoadError.invalidResponse
        }
        guard expectedContentLength <= Int64(EditorialImageMediaPolicy.maximumByteCount) else {
            throw ArticleHeroImageLoadError.responseTooLarge
        }
    }

    static func validate(
        statusCode: Int,
        mimeType: String?,
        expectedContentType: ArticleHeroMediaContentType,
        expectedContentLength: Int64,
        data: Data
    ) throws {
        try validateHeaders(
            statusCode: statusCode,
            mimeType: mimeType,
            expectedContentType: expectedContentType,
            expectedContentLength: expectedContentLength
        )
        guard data.count <= EditorialImageMediaPolicy.maximumByteCount else {
            throw ArticleHeroImageLoadError.responseTooLarge
        }
        guard !data.isEmpty else {
            throw ArticleHeroImageLoadError.invalidImage
        }
    }
}

typealias VideoPosterImageResponseValidator = ArticleHeroImageResponseValidator

final class ArticleMediaNoRedirectDelegate: NSObject, URLSessionTaskDelegate,
    @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

actor ArticleHeroImagePipeline {
    static let shared = ArticleHeroImagePipeline()

    private let configuration: ArticleMediaConfiguration
    private let redirectDelegate: ArticleMediaNoRedirectDelegate
    private let session: URLSession

    init(configuration: ArticleMediaConfiguration = .from()) {
        self.configuration = configuration
        let redirectDelegate = ArticleMediaNoRedirectDelegate()
        self.redirectDelegate = redirectDelegate

        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpShouldSetCookies = false
        sessionConfiguration.httpCookieStorage = nil
        sessionConfiguration.urlCredentialStorage = nil
        sessionConfiguration.requestCachePolicy = .useProtocolCachePolicy
        sessionConfiguration.timeoutIntervalForRequest = 20
        sessionConfiguration.timeoutIntervalForResource = 30
        session = URLSession(
            configuration: sessionConfiguration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
    }

    func data<Media: EditorialImageMediaPayload>(for media: Media) async throws -> Data {
        guard configuration.permits(media.url) else {
            throw ArticleHeroImageLoadError.disallowedURL
        }

        var request = URLRequest(
            url: media.url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 20
        )
        request.httpMethod = "GET"
        request.setValue(media.contentType.rawValue, forHTTPHeaderField: "Accept")

        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ArticleHeroImageLoadError.invalidResponse
        }
        try ArticleHeroImageResponseValidator.validateHeaders(
            statusCode: response.statusCode,
            mimeType: response.mimeType,
            expectedContentType: media.contentType,
            expectedContentLength: response.expectedContentLength
        )

        var data = Data()
        for try await byte in bytes {
            guard data.count < EditorialImageMediaPolicy.maximumByteCount else {
                throw ArticleHeroImageLoadError.responseTooLarge
            }
            data.append(byte)
        }
        guard !data.isEmpty else {
            throw ArticleHeroImageLoadError.invalidImage
        }
        return data
    }
}

typealias VideoPosterImagePipeline = ArticleHeroImagePipeline
