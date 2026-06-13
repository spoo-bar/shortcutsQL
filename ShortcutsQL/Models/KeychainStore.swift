import Foundation
import Security

/// A database server's connection credentials. Stored only in the Keychain —
/// never persisted in plaintext (e.g. UserDefaults) alongside the metadata.
struct ServerCredentials: Codable, Sendable, Equatable {
    let user: String
    let password: String
}

/// Thin wrapper over the Security framework for storing per-server
/// credentials as a generic-password Keychain item, keyed by the server id.
enum KeychainStore {
    private static let service = "\(Bundle.main.bundleIdentifier ?? "ShortcutsQL").db-credentials"

    /// Stores (or replaces) the credentials for a server.
    @discardableResult
    static func save(_ credentials: ServerCredentials, for serverID: String) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else { return false }
        // Delete any existing item first so this is an idempotent upsert.
        delete(for: serverID)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Reads the credentials for a server, or nil if none are stored.
    static func read(for serverID: String) -> ServerCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(ServerCredentials.self, from: data)
    }

    /// Removes the credentials for a server (no-op if absent).
    static func delete(for serverID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
