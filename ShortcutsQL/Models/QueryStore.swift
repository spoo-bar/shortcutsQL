import Foundation
import Observation

/// Store backing the UI. Server/query metadata is persisted in UserDefaults;
/// server credentials (username + password) live in the Keychain, keyed by
/// the server id — never in plaintext alongside the metadata.
@Observable
final class QueryStore {
    private(set) var queries: [SavedQuery]
    private(set) var servers: [DatabaseServer]
    /// Retained query results keyed by query id, newest first. Only populated
    /// when history is enabled (see `isHistoryEnabled`).
    private(set) var histories: [String: [QueryHistoryEntry]]

    private let defaults: UserDefaults
    private static let serversKey = "servers"
    private static let queriesKey = "queries"
    private static let historyKey = "history"
    /// UserDefaults key mirroring the `@AppStorage("historyEnabled")` toggle so
    /// the Shortcuts intents (which have no SwiftUI environment) can read it.
    static let historyEnabledKey = "historyEnabled"

    /// Loads persisted metadata. Pass explicit arrays (e.g. in previews) to
    /// bypass persistence.
    init(queries: [SavedQuery]? = nil, servers: [DatabaseServer]? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.queries = queries ?? Self.load([SavedQuery].self, key: Self.queriesKey, from: defaults) ?? []
        self.servers = servers ?? Self.load([DatabaseServer].self, key: Self.serversKey, from: defaults) ?? []
        self.histories = Self.load([String: [QueryHistoryEntry]].self, key: Self.historyKey, from: defaults) ?? [:]
    }

    /// Whether result history is turned on. Mirrors the Settings toggle.
    var isHistoryEnabled: Bool { defaults.bool(forKey: Self.historyEnabledKey) }

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
        if histories.removeValue(forKey: id) != nil {
            persistHistories()
        }
        persistQueries()
    }

    /// Re-reads persisted queries and servers so the UI picks up changes made
    /// elsewhere — e.g. run stats recorded by the Shortcuts intent while the
    /// app was backgrounded. Safe because every mutation persists immediately,
    /// so the store and UserDefaults never diverge.
    func reload() {
        if let loaded = Self.load([SavedQuery].self, key: Self.queriesKey, from: defaults) {
            queries = loaded
        }
        if let loaded = Self.load([DatabaseServer].self, key: Self.serversKey, from: defaults) {
            servers = loaded
        }
        if let loaded = Self.load([String: [QueryHistoryEntry]].self, key: Self.historyKey, from: defaults) {
            histories = loaded
        }
    }

    /// Records the outcome of running a saved query so the Home screen can
    /// show its last-run time, row count, and duration. No-op for queries
    /// that aren't saved yet.
    func recordRun(queryID: String, at date: Date, durationMilliseconds: Int, rowCount: Int) {
        guard let index = queries.firstIndex(where: { $0.id == queryID }) else { return }
        queries[index].lastRanAt = date
        queries[index].durationMilliseconds = durationMilliseconds
        queries[index].rowCount = rowCount
        persistQueries()
    }

    // MARK: History

    /// The retained results for a query, newest first (empty if none).
    func history(forQueryID id: String) -> [QueryHistoryEntry] {
        histories[id] ?? []
    }

    /// Prepends a result to a query's history and trims it to the newest
    /// `limit` entries, then persists. Used by the Shortcuts run intent when
    /// history is enabled.
    func recordHistory(queryID: String, entry: QueryHistoryEntry, limit: Int) {
        var entries = histories[queryID] ?? []
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
        histories[queryID] = entries
        persistHistories()
    }

    /// Removes all retained results for a query.
    func clearHistory(forQueryID id: String) {
        guard histories.removeValue(forKey: id) != nil else { return }
        persistHistories()
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

    /// Builds connection parameters for a saved query from its server and the
    /// Keychain credentials, or nil if either is missing. Used by both the
    /// editor and the Shortcuts intent.
    func connectionParameters(for query: SavedQuery) -> ConnectionParameters? {
        guard let server = servers.first(where: { $0.name == query.serverName }),
              let credentials = credentials(for: server.id) else { return nil }
        let endpoint = server.endpoint
        return ConnectionParameters(
            host: endpoint.host,
            port: endpoint.port,
            database: query.database.isEmpty ? "postgres" : query.database,
            user: credentials.user,
            password: credentials.password
        )
    }

    // MARK: Persistence

    private func persistServers() {
        Self.save(servers, key: Self.serversKey, to: defaults)
    }

    private func persistQueries() {
        Self.save(queries, key: Self.queriesKey, to: defaults)
    }

    private func persistHistories() {
        Self.save(histories, key: Self.historyKey, to: defaults)
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
