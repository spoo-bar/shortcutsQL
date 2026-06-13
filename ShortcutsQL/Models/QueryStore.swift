import Foundation
import Observation

/// In-memory store backing the UI. Mock data only — no persistence or
/// real database connections yet.
@Observable
final class QueryStore {
    private(set) var queries: [SavedQuery]
    private(set) var servers: [DatabaseServer]

    init(queries: [SavedQuery] = MockData.queries,
         servers: [DatabaseServer] = MockData.servers) {
        self.queries = queries
        self.servers = servers
    }

    /// Updates an existing query in place, or prepends a new one.
    func save(_ query: SavedQuery) {
        if let index = queries.firstIndex(where: { $0.id == query.id }) {
            queries[index] = query
        } else {
            queries.insert(query, at: 0)
        }
    }

    func deleteQuery(id: String) {
        queries.removeAll { $0.id == id }
    }

    /// Updates an existing server in place, or appends a new one.
    func saveServer(_ server: DatabaseServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
        } else {
            servers.append(server)
        }
    }

    func deleteServer(id: String) {
        servers.removeAll { $0.id == id }
    }

    func server(named name: String) -> DatabaseServer? {
        servers.first { $0.name == name }
    }
}
