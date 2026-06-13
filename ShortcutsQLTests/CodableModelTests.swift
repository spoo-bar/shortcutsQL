import Testing
import Foundation
@testable import ShortcutsQL

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
