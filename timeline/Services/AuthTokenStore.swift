import Foundation
import Security

protocol AuthTokenStore {
    func saveToken(_ token: String) throws
    func loadToken() throws -> String?
    func clearToken() throws
}

final class KeychainAuthTokenStore: AuthTokenStore {
    private let service = "timeline.notesync.jwt"
    private let account = "user"

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        try clearToken()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "Keychain", code: Int(status)) }
    }

    func loadToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
        return String(data: data, encoding: .utf8)
    }

    func clearToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class InMemoryAuthTokenStore: AuthTokenStore {
    private var token: String?

    func saveToken(_ token: String) throws { self.token = token }
    func loadToken() throws -> String? { token }
    func clearToken() throws { token = nil }
}
