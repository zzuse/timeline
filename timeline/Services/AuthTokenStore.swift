import Foundation
import Security

protocol AuthTokenStore {
    func saveTokens(accessToken: String, refreshToken: String) throws
    func loadAccessToken() throws -> String?
    func loadRefreshToken() throws -> String?
    func clearTokens() throws
}

final class KeychainAuthTokenStore: AuthTokenStore {
    private let service = "timeline.notesync.tokens"
    private let accessAccount = "access"
    private let refreshAccount = "refresh"

    func saveTokens(accessToken: String, refreshToken: String) throws {
        try clearTokens()
        try saveToken(accessToken, account: accessAccount)
        try saveToken(refreshToken, account: refreshAccount)
    }

    func loadAccessToken() throws -> String? {
        try loadToken(account: accessAccount)
    }

    func loadRefreshToken() throws -> String? {
        try loadToken(account: refreshAccount)
    }

    func clearTokens() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func saveToken(_ token: String, account: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "Keychain", code: Int(status)) }
    }

    private func loadToken(account: String) throws -> String? {
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
}

final class InMemoryAuthTokenStore: AuthTokenStore {
    private var accessToken: String?
    private var refreshToken: String?

    func saveTokens(accessToken: String, refreshToken: String) throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func loadAccessToken() throws -> String? { accessToken }
    func loadRefreshToken() throws -> String? { refreshToken }

    func clearTokens() throws {
        accessToken = nil
        refreshToken = nil
    }
}
