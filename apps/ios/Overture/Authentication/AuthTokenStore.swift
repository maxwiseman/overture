import Foundation
import Security

struct AuthTokenStore {
    private let service = "com.overture.news.swiftui.auth"
    private let account = "better-auth-bearer"
    private let sharedAccessGroup = "group.com.overture.news.shared"

    func save(_ token: String) throws {
        deleteShared()
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: sharedAccessGroup,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: Data(token.utf8),
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw AuthTokenStoreError.unavailable(status) }
    }

    func read() -> String? {
        if let shared = read(accessGroup: sharedAccessGroup) {
            return shared
        }

        // Preserve an existing app-only session the first time Keychain sharing is enabled.
        guard let legacy = read(accessGroup: nil) else { return nil }
        try? save(legacy)
        return legacy
    }

    func delete() {
        deleteShared()
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary)
    }

    private func read(accessGroup: String?) -> String? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteShared() {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: sharedAccessGroup,
        ] as CFDictionary)
    }
}

private enum AuthTokenStoreError: Error {
    case unavailable(OSStatus)
}
