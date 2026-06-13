import Testing
import Foundation
@testable import ShortcutsQL

@Suite("SQL validation")
struct SQLValidatorTests {
    @Test("Well-formed SELECT passes")
    func validSelect() {
        #expect(SQLValidator.validate("SELECT count(*) AS signups FROM users WHERE created_at >= current_date;") == nil)
    }

    @Test("Literal SELECT without FROM passes")
    func selectLiteral() {
        #expect(SQLValidator.validate("SELECT 1") == nil)
    }

    @Test("CTE passes")
    func cte() {
        #expect(SQLValidator.validate("WITH x AS (SELECT 1) SELECT * FROM x") == nil)
    }

    @Test("Misspelled keyword is a syntax error naming the token")
    func misspelledKeyword() {
        let error = SQLValidator.validate("SELEC * FORM logs")
        #expect(error?.hasPrefix("syntax error at or near \"SELEC\"") == true)
    }

    @Test("Unmatched opening parenthesis is caught")
    func unmatchedOpeningParen() {
        let error = SQLValidator.validate("SELECT count(* FROM users")
        #expect(error?.contains("unmatched opening parenthesis") == true)
    }

    @Test("Unmatched closing parenthesis is caught")
    func unmatchedClosingParen() {
        let error = SQLValidator.validate("SELECT count(*)) FROM users")
        #expect(error?.contains("unmatched closing parenthesis") == true)
    }

    @Test("Unterminated string literal is caught")
    func unterminatedString() {
        let error = SQLValidator.validate("SELECT * FROM users WHERE plan = 'pro")
        #expect(error?.contains("unterminated quoted string") == true)
    }

    @Test("SELECT of a column without FROM is caught")
    func missingFrom() {
        let error = SQLValidator.validate("SELECT signups")
        #expect(error?.contains("missing FROM clause") == true)
    }

    @Test("Empty statement is caught")
    func emptyStatement() {
        #expect(SQLValidator.validate("  -- only a comment\n") == "empty statement")
    }
}

@Suite("Codable models")
struct CodableModelTests {
    @Test("DatabaseServer round-trips through JSON")
    func databaseServerRoundTrip() throws {
        let server = DatabaseServer(
            id: "s1", name: "prod", engine: "PostgreSQL", host: "db.internal:5432",
            ssl: true, color: .blue, databases: [ServerDatabase(name: "app_production")]
        )
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(DatabaseServer.self, from: data)
        #expect(decoded == server)
    }

    @Test("SavedQuery round-trips through JSON")
    func savedQueryRoundTrip() throws {
        let query = SavedQuery(
            id: "q1", name: "Signups", serverName: "prod", database: "app_production",
            sql: "SELECT 1;", lastRanAt: nil, durationMilliseconds: nil, rowCount: nil
        )
        let data = try JSONEncoder().encode(query)
        let decoded = try JSONDecoder().decode(SavedQuery.self, from: data)
        #expect(decoded == query)
    }

    @Test("Run-metadata labels format from the stored counts")
    func runMetadataLabels() {
        var query = SavedQuery(id: "q", name: "Q", serverName: "s", database: "d", sql: "SELECT 1;")
        #expect(query.rowsLabel == nil)
        #expect(query.durationLabel == nil)
        query.rowCount = 1
        query.durationMilliseconds = 42
        #expect(query.rowsLabel == "1 row")
        #expect(query.durationLabel == "42 ms")
        query.rowCount = 25
        query.durationMilliseconds = 1500
        #expect(query.rowsLabel == "25 rows")
        #expect(query.durationLabel == "1.5 s")
    }
}

@Suite("Keychain credential storage")
struct KeychainStoreTests {
    /// A unique id per test so concurrently-run tests don't collide, with
    /// cleanup of the Keychain item afterwards.
    private func withTemporaryID(_ body: (String) -> Void) {
        let id = "test-\(UUID().uuidString)"
        defer { KeychainStore.delete(for: id) }
        body(id)
    }

    @Test("Saved credentials round-trip")
    func roundTrip() {
        withTemporaryID { id in
            let credentials = ServerCredentials(user: "readonly", password: "hunter2hunter2")
            #expect(KeychainStore.save(credentials, for: id))
            #expect(KeychainStore.read(for: id) == credentials)
        }
    }

    @Test("Saving again overwrites the previous value")
    func overwrite() {
        withTemporaryID { id in
            KeychainStore.save(ServerCredentials(user: "a", password: "1"), for: id)
            KeychainStore.save(ServerCredentials(user: "b", password: "2"), for: id)
            #expect(KeychainStore.read(for: id) == ServerCredentials(user: "b", password: "2"))
        }
    }

    @Test("Reading an unknown id returns nil")
    func missing() {
        #expect(KeychainStore.read(for: "test-does-not-exist-\(UUID().uuidString)") == nil)
    }

    @Test("Deleting removes the credentials")
    func delete() {
        withTemporaryID { id in
            KeychainStore.save(ServerCredentials(user: "a", password: "1"), for: id)
            KeychainStore.delete(for: id)
            #expect(KeychainStore.read(for: id) == nil)
        }
    }
}

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

    private func sampleServer(id: String, name: String = "prod") -> DatabaseServer {
        DatabaseServer(id: id, name: name, engine: "PostgreSQL", host: "db.internal:5432",
                       ssl: true, color: .blue, databases: [ServerDatabase(name: "app_production")])
    }

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
}
