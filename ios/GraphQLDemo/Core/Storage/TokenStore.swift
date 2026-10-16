import Foundation
import Security

/// Stores the access token returned by the `login` mutation.
protocol TokenStoring: Sendable {
    var accessToken: String? { get }
    func save(accessToken: String, refreshToken: String?)
    func clear()
}

/// Keeps tokens in the iOS Keychain (survives app restarts, not readable by other apps).
final class KeychainTokenStore: TokenStoring, @unchecked Sendable {
    private let service: String
    private let accessKey = "accessToken"
    private let refreshKey = "refreshToken"

    init(service: String = Bundle.main.bundleIdentifier.map { "\($0).auth" } ?? "GraphQLDemo.auth") {
        self.service = service
    }

    var accessToken: String? { read(accessKey) }

    func save(accessToken: String, refreshToken: String?) {
        write(accessToken, account: accessKey)
        if let refreshToken {
            write(refreshToken, account: refreshKey)
        } else {
            delete(refreshKey)
        }
    }

    func clear() {
        delete(accessKey)
        delete(refreshKey)
    }

    // MARK: - Keychain helpers

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func read(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, account: String) {
        delete(account)
        var query = baseQuery(account)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}

/// In-memory store for SwiftUI previews and tests.
final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) { self.token = token }

    var accessToken: String? { lock.withLock { token } }
    func save(accessToken: String, refreshToken: String?) { lock.withLock { token = accessToken } }
    func clear() { lock.withLock { token = nil } }
}
