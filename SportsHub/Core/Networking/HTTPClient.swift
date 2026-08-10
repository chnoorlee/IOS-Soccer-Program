import Foundation

struct HTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    func header(named name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

