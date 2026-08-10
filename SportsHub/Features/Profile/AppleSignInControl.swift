import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

@MainActor
struct AppleSignInControl: View {
    @Environment(\.colorScheme) private var colorScheme

    let isEnabled: Bool
    let onCredential: @MainActor (AppleSignInCredential) async -> Void
    let onFailure: @MainActor (AuthenticationError) -> Void
    let identifier: String

    @State private var rawNonce: String?
    @State private var noncePreparationFailed = false
    @State private var authorizationInFlight = false

    init(
        isEnabled: Bool,
        onCredential: @escaping @MainActor (AppleSignInCredential) async -> Void,
        onFailure: @escaping @MainActor (AuthenticationError) -> Void,
        identifier: String = "profile.signInWithApple"
    ) {
        self.isEnabled = isEnabled
        self.onCredential = onCredential
        self.onFailure = onFailure
        self.identifier = identifier
    }

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            authorizationInFlight = true
            do {
                let nonce = try AppleSignInNonce.make()
                rawNonce = nonce
                noncePreparationFailed = false
                request.nonce = AppleSignInNonce.sha256(nonce)
                request.requestedScopes = [.fullName, .email]
            } catch {
                rawNonce = nil
                noncePreparationFailed = true
            }
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(maxWidth: .infinity, minHeight: 48)
        .disabled(!isEnabled || authorizationInFlight)
        .accessibilityIdentifier(identifier)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        authorizationInFlight = false
        guard !noncePreparationFailed, let rawNonce else {
            onFailure(.invalidCredential)
            return
        }
        self.rawNonce = nil

        switch result {
        case let .success(authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCodeData = appleCredential.authorizationCode,
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
                onFailure(.invalidCredential)
                return
            }
            let credential = AppleSignInCredential(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                rawNonce: rawNonce,
                givenName: normalized(appleCredential.fullName?.givenName),
                familyName: normalized(appleCredential.fullName?.familyName),
                email: normalized(appleCredential.email)
            )
            Task { @MainActor in
                await onCredential(credential)
            }
        case let .failure(error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                onFailure(.cancelled)
            } else {
                onFailure(.invalidCredential)
            }
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum AppleSignInNonce {
    static func make() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, baseAddress)
        }
        guard status == errSecSuccess else {
            throw AuthenticationError.invalidCredential
        }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
