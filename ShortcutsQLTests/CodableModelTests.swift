import Testing
import Foundation
@testable import ShortcutsQL

@Suite("Codable models")
struct CodableModelTests {
    @Test("DatabaseServer round-trips through JSON")
    func databaseServerRoundTrip() throws {
        let server = DatabaseServer(
            id: "s1", name: "prod", engine: .postgreSQL, host: "db.internal:5432",
            color: .blue, databases: [ServerDatabase(name: "app_production")]
        )
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(DatabaseServer.self, from: data)
        #expect(decoded == server)
    }

    @Test("DatabaseServer encodes its engine as the display name")
    func databaseServerEncodesEngineName() throws {
        let server = DatabaseServer(
            id: "s1", name: "prod", engine: .mySQL, host: "mysql.internal:3306",
            color: .blue, databases: []
        )
        let json = String(decoding: try JSONEncoder().encode(server), as: UTF8.self)
        #expect(json.contains("\"engine\":\"MySQL\""))
        let decoded = try JSONDecoder().decode(DatabaseServer.self, from: Data(json.utf8))
        #expect(decoded.engine == .mySQL)
    }

    @Test("An unknown engine name decodes as the fallback engine")
    func databaseServerDecodesUnknownEngine() throws {
        // A server saved with an engine this build can no longer connect to
        // must still decode: throwing here would fail the whole array decode
        // and silently drop every saved server.
        let legacy = """
        {"id":"s9","name":"legacy","engine":"CockroachDB","host":"db.internal:5432",
         "color":"blue","databases":[]}
        """
        let decoded = try JSONDecoder().decode(DatabaseServer.self, from: Data(legacy.utf8))
        #expect(decoded.engine == DatabaseEngine.fallback)
        #expect(decoded.endpoint.port == 5432)
    }

    @Test("SavedQuery round-trips through JSON")
    func savedQueryRoundTrip() throws {
        let query = SavedQuery(
            id: "q1", name: "Signups", serverName: "prod", database: "app_production",
            sql: "SELECT 1;", lastRanAt: nil, durationMilliseconds: nil, rowCount: nil,
            historyLimit: 10
        )
        let data = try JSONEncoder().encode(query)
        let decoded = try JSONDecoder().decode(SavedQuery.self, from: data)
        #expect(decoded == query)
        #expect(decoded.historyLimit == 10)
    }

    @Test("SavedQuery decodes legacy JSON that predates historyLimit")
    func savedQueryDecodesLegacyJSON() throws {
        // A payload written before the history feature — no historyLimit key.
        // Decoding must succeed (a throw here would drop every saved query,
        // since the store loads with try?).
        let legacy = """
        {"id":"old","name":"Legacy","serverName":"prod","database":"app","sql":"SELECT 1;"}
        """
        let decoded = try JSONDecoder().decode(SavedQuery.self, from: Data(legacy.utf8))
        #expect(decoded.id == "old")
        #expect(decoded.historyLimit == nil)
        // Falls back to the default limit.
        #expect(decoded.effectiveHistoryLimit == SavedQuery.defaultHistoryLimit)
    }

    @Test("effectiveHistoryLimit clamps to 1...50")
    func effectiveHistoryLimitClamps() {
        func query(_ limit: Int?) -> SavedQuery {
            SavedQuery(id: "q", name: "Q", serverName: "s", database: "d",
                       sql: "SELECT 1;", historyLimit: limit)
        }
        #expect(query(nil).effectiveHistoryLimit == SavedQuery.defaultHistoryLimit)
        #expect(query(0).effectiveHistoryLimit == 1)
        #expect(query(7).effectiveHistoryLimit == 7)
        #expect(query(999).effectiveHistoryLimit == 50)
    }

    @Test("QueryHistoryEntry round-trips through JSON")
    func queryHistoryEntryRoundTrip() throws {
        let entry = QueryHistoryEntry(
            id: "h1", ranAt: Date(timeIntervalSince1970: 1_000_000),
            resultJSON: "[{\"count\":\"7\"}]"
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(QueryHistoryEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test("QueryHistoryEntry.jsonArray nests parsed results with timestamps")
    func queryHistoryEntryJSONArray() throws {
        let entries = [
            QueryHistoryEntry(id: "h2", ranAt: Date(timeIntervalSince1970: 2_000_000),
                              resultJSON: "[{\"count\":\"9\"}]"),
            QueryHistoryEntry(id: "h1", ranAt: Date(timeIntervalSince1970: 1_000_000),
                              resultJSON: "[{\"count\":\"7\"}]"),
        ]
        let json = QueryHistoryEntry.jsonArray(entries)
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]
        #expect(parsed?.count == 2)
        // "result" is real nested JSON, not an escaped string.
        let firstResult = parsed?.first?["result"] as? [[String: String]]
        #expect(firstResult?.first?["count"] == "9")
        #expect(parsed?.first?["ranAt"] is String)
    }

    @Test("QueryHistoryEntry.jsonArray is an empty array for no entries")
    func queryHistoryEntryJSONArrayEmpty() throws {
        let json = QueryHistoryEntry.jsonArray([])
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [Any]
        #expect(parsed?.isEmpty == true)
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
