import Foundation

/// Keeps credential storage outside the data provider. A Keychain-backed
/// implementation can be injected when the account slice is connected.
protocol AccessTokenProviding: Sendable {
    func accessToken() async -> String?
    func accessToken(forAccountID accountID: String) async -> String?
    func accountSessionExists() async -> Bool
}

extension AccessTokenProviding {
    func accessToken(forAccountID _: String) async -> String? {
        nil
    }

    func accountSessionExists() async -> Bool {
        await accessToken() != nil
    }
}

struct NoAccessTokenProvider: AccessTokenProviding {
    func accessToken() async -> String? { nil }
}

struct StaticAccessTokenProvider: AccessTokenProviding {
    let token: String?
    let accountID: String? = nil

    func accessToken() async -> String? { token }

    func accessToken(forAccountID accountID: String) async -> String? {
        guard accountID == self.accountID else { return nil }
        return token
    }
}
