import Foundation

struct URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SportsDataError.invalidResponse(statusCode: 0)
            }

            let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
                guard let key = pair.key as? String else { return }
                result[key] = String(describing: pair.value)
            }

            return HTTPResponse(
                data: data,
                statusCode: httpResponse.statusCode,
                headers: headers
            )
        } catch let error as SportsDataError {
            throw error
        } catch is URLError {
            throw SportsDataError.networkUnavailable
        } catch {
            throw SportsDataError.serverUnavailable
        }
    }
}
