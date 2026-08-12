import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security

@MainActor
@Observable
final class AuthenticationSession {
    private(set) var userName: String?
    private(set) var userEmail: String?
    private(set) var isAuthenticated = false
    private(set) var isWorking = false
    var errorMessage: String?

    private var currentNonce: String?
    private let tokenStore = AuthTokenStore()

    var userInitials: String? {
        let nameParts = userName?
            .split(whereSeparator: \Character.isWhitespace)
            .map(String.init) ?? []

        if let first = nameParts.first?.first {
            let last = nameParts.count > 1 ? nameParts.last?.first : nil
            return [first, last].compactMap { $0 }.map(String.init).joined().uppercased()
        }

        return nil
    }

    init() {
        isAuthenticated = tokenStore.read() != nil
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func completeAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            currentNonce = nil
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Apple did not return a usable identity token."
                return
            }

            let appleEmail = credential.email
            let appleName = credential.fullName.map {
                PersonNameComponentsFormatter().string(from: $0)
            }
            currentNonce = nil
            Task {
                await exchangeAppleToken(
                    identityToken,
                    nonce: nonce,
                    appleEmail: appleEmail,
                    appleName: appleName
                )
            }
        }
    }

    func signOut() async {
        guard let token = tokenStore.read() else {
            isAuthenticated = false
            userName = nil
            userEmail = nil
            return
        }

        var request = URLRequest(url: OvertureEnvironment.apiBaseURL.appending(path: "api/auth/sign-out"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        _ = try? await URLSession.shared.data(for: request)
        tokenStore.delete()
        isAuthenticated = false
        userName = nil
        userEmail = nil
    }

    func restoreSession() async {
        guard let token = tokenStore.read() else { return }

        do {
            var request = URLRequest(
                url: OvertureEnvironment.apiBaseURL.appending(path: "api/auth/get-session")
            )
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                tokenStore.delete()
                isAuthenticated = false
                return
            }
            userName = Self.userField("name", from: data)
            userEmail = Self.userField("email", from: data)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exchangeAppleToken(
        _ identityToken: String,
        nonce: String,
        appleEmail: String?,
        appleName: String?
    ) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            var request = URLRequest(
                url: OvertureEnvironment.apiBaseURL.appending(path: "api/auth/sign-in/social")
            )
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "provider": "apple",
                "idToken": ["token": identityToken, "nonce": nonce],
            ])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw AuthenticationError.invalidResponse
            }
            guard (200..<300).contains(response.statusCode) else {
                throw AuthenticationError.server(response.statusCode)
            }
            guard let bearerToken = response.value(forHTTPHeaderField: "set-auth-token") else {
                throw AuthenticationError.missingBearerToken
            }

            try tokenStore.save(bearerToken)
            userName = Self.userField("name", from: data) ?? appleName
            userEmail = appleEmail ?? Self.userField("email", from: data)
            isAuthenticated = true
            Haptics.impact()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func userField(_ field: String, from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let user = object["user"] as? [String: Any]
        else { return nil }
        return user[field] as? String
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var byte: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &byte) == errSecSuccess else {
                preconditionFailure("Unable to generate a secure nonce")
            }
            if byte < alphabet.count {
                result.append(alphabet[Int(byte)])
            }
        }
        return result
    }
}

private enum AuthenticationError: LocalizedError {
    case invalidResponse
    case server(Int)
    case missingBearerToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The authentication server returned an invalid response."
        case .server(let status): "Sign in failed with server status \(status)."
        case .missingBearerToken: "Sign in succeeded without a native session token."
        }
    }
}

private struct AuthTokenStore {
    private let service = "com.overture.news.swiftui.auth"
    private let account = "better-auth-bearer"

    func save(_ token: String) throws {
        delete()
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: Data(token.utf8),
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw AuthenticationError.missingBearerToken }
    }

    func read() -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ] as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete() {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary)
    }
}
