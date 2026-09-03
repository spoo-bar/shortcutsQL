import Testing
import Foundation
@testable import ShortcutsQL

@Suite("Query store")
struct QueryStoreTests {
    /// A store backed by an isolated UserDefaults suite so tests don't touch
    /// (or depend on) real persisted data.
    private func makeStore() -> (QueryStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (QueryStore(defaults: defaults), defaults)
    }

    private func sampleQuery(id: String, name: String = "Query") -> SavedQuery {
        SavedQuery(id: id, name: name, serverName: "prod", database: "app_production",
                   sql: "SELECT count(*) FROM trials;")
    }

    private func sampleServer(
        id: String, name: String = "prod",
        engine: DatabaseEngine = .postgreSQL, host: String = "db.internal:5432"
    ) -> DatabaseServer {
        DatabaseServer(id: id, name: name, engine: engine, host: host,
                       color: .blue, databases: [ServerDatabase(name: "app_production")])
    }

    // MARK: Queries

    @Test("Saving a new query prepends it")
    func saveNew() {
        let (store, _) = makeStore()
        store.save(sampleQuery(id: "new"))
        #expect(store.queries.count == 1)
        #expect(store.queries.first?.id == "new")
    }

    @Test("Saving an existing query updates it in place")
    func saveExisting() {
        let (store, _) = makeStore()
        store.save(sampleQuery(id: "a", name: "First"))
        store.save(sampleQuery(id: "b", name: "Second"))
        store.save(sampleQuery(id: "a", name: "Renamed"))
        #expect(store.queries.count == 2)
        #expect(store.queries.first { $0.id == "a" }?.name == "Renamed")
    }

    @Test("Deleting removes the query")
    func deleteQuery() {
        let (store, _) = makeStore()
        store.save(sampleQuery(id: "a"))
        store.deleteQuery(id: "a")
        #expect(store.queries.isEmpty)
    }

    @Test("Queries persist across store instances")
    func queriesPersist() {
        let (store, defaults) = makeStore()
        store.save(sampleQuery(id: "a", name: "Kept"))
        let reloaded = QueryStore(defaults: defaults)
        #expect(reloaded.queries.first { $0.id == "a" }?.name == "Kept")
    }

    // MARK: Run metadata

    @Test("Recording a run stores its stats and persists them")
    func recordRunPersists() {
        let (store, defaults) = makeStore()
        store.save(sampleQuery(id: "a"))
        let ranAt = Date(timeIntervalSince1970: 1_000_000)
        store.recordRun(queryID: "a", at: ranAt, durationMilliseconds: 42, rowCount: 7)

        let saved = store.queries.first { $0.id == "a" }
        #expect(saved?.rowCount == 7)
        #expect(saved?.durationMilliseconds == 42)
        #expect(saved?.lastRanAt == ranAt)

        // And it survives a reload.
        let reloaded = QueryStore(defaults: defaults).queries.first { $0.id == "a" }
        #expect(reloaded?.rowCount == 7)
        #expect(reloaded?.rowsLabel == "7 rows")
    }

    @Test("Recording a run for an unknown query is a no-op")
    func recordRunUnknown() {
        let (store, _) = makeStore()
        store.recordRun(queryID: "missing", at: Date(), durationMilliseconds: 1, rowCount: 1)
        #expect(store.queries.isEmpty)
    }

    // MARK: History

    private func historyEntry(_ id: String, seconds: TimeInterval) -> QueryHistoryEntry {
        QueryHistoryEntry(id: id, ranAt: Date(timeIntervalSince1970: seconds),
                          resultJSON: "[{\"n\":\"\(id)\"}]")
    }

    @Test("isHistoryEnabled reflects the historyEnabled default")
    func isHistoryEnabled() {
        let (store, defaults) = makeStore()
        #expect(store.isHistoryEnabled == false)
        defaults.set(true, forKey: QueryStore.historyEnabledKey)
        #expect(store.isHistoryEnabled == true)
    }

    @Test("Recording history prepends (newest first) and trims to the limit")
    func recordHistoryTrims() {
        let (store, _) = makeStore()
        store.save(sampleQuery(id: "a"))
        for i in 1...5 {
            store.recordHistory(queryID: "a", entry: historyEntry("e\(i)", seconds: Double(i)), limit: 3)
        }
        let entries = store.history(forQueryID: "a")
        #expect(entries.count == 3)
        // Newest first, older ones dropped.
        #expect(entries.map(\.id) == ["e5", "e4", "e3"])
    }

    @Test("History persists across store instances")
    func historyPersists() {
        let (store, defaults) = makeStore()
        store.save(sampleQuery(id: "a"))
        store.recordHistory(queryID: "a", entry: historyEntry("e1", seconds: 1), limit: 5)
        let reloaded = QueryStore(defaults: defaults)
        #expect(reloaded.history(forQueryID: "a").map(\.id) == ["e1"])
    }

    @Test("Deleting a query also clears its history")
    func deleteQueryClearsHistory() {
        let (store, defaults) = makeStore()
        store.save(sampleQuery(id: "a"))
        store.recordHistory(queryID: "a", entry: historyEntry("e1", seconds: 1), limit: 5)
        store.deleteQuery(id: "a")
        #expect(store.history(forQueryID: "a").isEmpty)
        // And the removal is persisted.
        #expect(QueryStore(defaults: defaults).history(forQueryID: "a").isEmpty)
    }

    @Test("Clearing history removes only the target query's entries")
    func clearHistory() {
        let (store, _) = makeStore()
        store.recordHistory(queryID: "a", entry: historyEntry("a1", seconds: 1), limit: 5)
        store.recordHistory(queryID: "b", entry: historyEntry("b1", seconds: 1), limit: 5)
        store.clearHistory(forQueryID: "a")
        #expect(store.history(forQueryID: "a").isEmpty)
        #expect(store.history(forQueryID: "b").map(\.id) == ["b1"])
    }

    // MARK: Servers & credentials

    @Test("Servers persist across store instances")
    func serversPersist() {
        let (store, defaults) = makeStore()
        let id = "srv-\(UUID().uuidString)"
        defer { store.deleteServer(id: id) }
        store.saveServer(sampleServer(id: id, name: "Kept"), credentials: ServerCredentials(user: "u", password: "p"))
        let reloaded = QueryStore(defaults: defaults)
        #expect(reloaded.servers.first { $0.id == id }?.name == "Kept")
    }

    @Test("Saving a server stores its credentials in the Keychain")
    func serverCredentialsRoundTrip() {
        let (store, _) = makeStore()
        let id = "srv-\(UUID().uuidString)"
        defer { store.deleteServer(id: id) }
        let credentials = ServerCredentials(user: "readonly", password: "hunter2hunter2")
        store.saveServer(sampleServer(id: id), credentials: credentials)
        #expect(store.credentials(for: id) == credentials)
    }

    @Test("Deleting a server also clears its credentials")
    func deleteServerClearsCredentials() {
        let (store, _) = makeStore()
        let id = "srv-\(UUID().uuidString)"
        store.saveServer(sampleServer(id: id), credentials: ServerCredentials(user: "u", password: "p"))
        store.deleteServer(id: id)
        #expect(store.servers.contains { $0.id == id } == false)
        #expect(store.credentials(for: id) == nil)
    }

    @Test("The password is never written to UserDefaults in plaintext")
    func passwordNotPersistedInPlaintext() {
        let (store, defaults) = makeStore()
        let id = "srv-\(UUID().uuidString)"
        defer { store.deleteServer(id: id) }
        let password = "sup3r-s3cret-\(UUID().uuidString)"
        store.saveServer(sampleServer(id: id), credentials: ServerCredentials(user: "specialuser", password: password))
        let persisted = defaults.data(forKey: "servers").flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(!persisted.contains(password))
        #expect(!persisted.contains("specialuser"))
    }

    // MARK: Connection parameters

    @Test("Connection parameters carry the server's engine, endpoint, and credentials")
    func connectionParametersFromServer() {
        let (store, _) = makeStore()
        let id = "srv-\(UUID().uuidString)"
        defer { store.deleteServer(id: id) }
        store.saveServer(sampleServer(id: id, name: "prod"),
                         credentials: ServerCredentials(user: "readonly", password: "pw"))
        let parameters = store.connectionParameters(for: sampleQuery(id: "q"))
        #expect(parameters?.engine == .postgreSQL)
        #expect(parameters?.host == "db.internal")
        #expect(parameters?.port == 5432)
        #expect(parameters?.database == "app_production")
        #expect(parameters?.user == "readonly")
        #expect(parameters?.password == "pw")
    }

    @Test("A MySQL server's parameters use its engine and port")
    func connectionParametersForMySQL() {
        let (store, _) = makeStore()
        let id = "srv-\(UUID().uuidString)"
        defer { store.deleteServer(id: id) }
        store.saveServer(
            sampleServer(id: id, name: "prod", engine: .mySQL, host: "mysql.internal:3306"),
            credentials: ServerCredentials(user: "app", password: "pw")
        )
        let parameters = store.connectionParameters(for: sampleQuery(id: "q"))
        #expect(parameters?.engine == .mySQL)
        #expect(parameters?.host == "mysql.internal")
        #expect(parameters?.port == 3306)
    }

    @Test("A query with no database falls back to the engine's default")
    func connectionParametersDefaultDatabase() {
        let (store, _) = makeStore()
        let postgresID = "srv-\(UUID().uuidString)"
        let mysqlID = "srv-\(UUID().uuidString)"
        defer {
            store.deleteServer(id: postgresID)
            store.deleteServer(id: mysqlID)
        }
        store.saveServer(sampleServer(id: postgresID, name: "pg"),
                         credentials: ServerCredentials(user: "u", password: "p"))
        store.saveServer(sampleServer(id: mysqlID, name: "my", engine: .mySQL,
                                      host: "mysql.internal:3306"),
                         credentials: ServerCredentials(user: "u", password: "p"))

        func query(server: String) -> SavedQuery {
            SavedQuery(id: "q", name: "Q", serverName: server, database: "", sql: "SELECT 1;")
        }
        #expect(store.connectionParameters(for: query(server: "pg"))?.database == "postgres")
        // MySQL connects with no database selected rather than a named one.
        #expect(store.connectionParameters(for: query(server: "my"))?.database == "")
    }

    @Test("Connection parameters are nil without a matching server")
    func connectionParametersWithoutServer() {
        let (store, _) = makeStore()
        #expect(store.connectionParameters(for: sampleQuery(id: "q")) == nil)
    }
}
