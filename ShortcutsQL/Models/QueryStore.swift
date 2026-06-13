import Foundation
import Observation

/// Store backing the UI. Server/query metadata is persisted in UserDefaults;
/// server credentials (username + password) live in the Keychain, keyed by
/// the server id — never in plaintext alongside the metadata.
@Observable
final class QueryStore {
    private(set) var queries: [SavedQuery]
    private(set) var servers: [DatabaseServer]

    private let defaults: UserDefaults
    private static let serversKey = "servers"
    private static let queriesKey = "queries"

    /// Loads persisted metadata. Pass explicit arrays (e.g. in previews) to
    /// bypass persistence.
    init(queries: [SavedQuery]? = nil, servers: [DatabaseServer]? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.queries = queries ?? Self.load([SavedQuery].self, key: Self.queriesKey, from: defaults) ?? []
        self.servers = servers ?? Self.load([DatabaseServer].self, key: Self.serversKey, from: defaults) ?? []
    }

    // MARK: Queries

    /// Updates an existing query in place, or prepends a new one.
    func save(_ query: SavedQuery) {
        if let index = queries.firstIndex(where: { $0.id == query.id }) {
            queries[index] = query
        } else {
            queries.insert(query, at: 0)
        }
        persistQueries()
    }

    func deleteQuery(id: String) {
        queries.removeAll { $0.id == id }
        persistQueries()
    }

    // MARK: Servers

    /// Updates an existing server in place (or appends a new one) and stores
    /// its credentials in the Keychain.
    func saveServer(_ server: DatabaseServer, credentials: ServerCredentials) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
        } else {
            servers.append(server)
        }
        KeychainStore.save(credentials, for: server.id)
        persistServers()
    }

    func deleteServer(id: String) {
        servers.removeAll { $0.id == id }
        KeychainStore.delete(for: id)
        persistServers()
    }

    /// The stored credentials for a server, or nil if none are saved.
    func credentials(for id: String) -> ServerCredentials? {
        KeychainStore.read(for: id)
    }

    func server(named name: String) -> DatabaseServer? {
        servers.first { $0.name == name }
    }

    // MARK: Persistence

    private func persistServers() {
        Self.save(servers, key: Self.serversKey, to: defaults)
    }

    private func persistQueries() {
        Self.save(queries, key: Self.queriesKey, to: defaults)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
