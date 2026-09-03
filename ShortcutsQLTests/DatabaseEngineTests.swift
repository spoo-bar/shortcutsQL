import Testing
import Foundation
@testable import ShortcutsQL

@Suite("Database engines")
struct DatabaseEngineTests {
    @Test("Each engine carries its standard port")
    func defaultPorts() {
        #expect(DatabaseEngine.postgreSQL.defaultPort == 5432)
        #expect(DatabaseEngine.mySQL.defaultPort == 3306)
    }

    @Test("Only PostgreSQL needs a database name to connect")
    func defaultDatabases() {
        #expect(DatabaseEngine.postgreSQL.defaultDatabase == "postgres")
        #expect(DatabaseEngine.mySQL.defaultDatabase == "")
    }

    @Test("The picker subtitle names the default port")
    func pickerSubtitle() {
        #expect(DatabaseEngine.mySQL.pickerSubtitle == "default port 3306")
    }

    @Test("Engines are matched by display name, case-insensitively")
    func namedLookup() {
        #expect(DatabaseEngine.named("MySQL") == .mySQL)
        #expect(DatabaseEngine.named("mysql") == .mySQL)
        #expect(DatabaseEngine.named("postgresql") == .postgreSQL)
        // Engines the picker shows but can't connect to.
        #expect(DatabaseEngine.named("MariaDB") == nil)
        #expect(DatabaseEngine.named("SQL Server") == nil)
    }

    @Test("A server's endpoint falls back to its engine's port")
    func endpointFallsBackToEnginePort() {
        func server(_ engine: DatabaseEngine, host: String) -> DatabaseServer {
            DatabaseServer(id: "s", name: "s", engine: engine, host: host,
                           color: .blue, databases: [])
        }
        // No port at all.
        #expect(server(.mySQL, host: "mysql.internal").endpoint.port == 3306)
        #expect(server(.postgreSQL, host: "db.internal").endpoint.port == 5432)
        // Present but unparseable (e.g. the port field was left blank on save).
        #expect(server(.mySQL, host: "mysql.internal:").endpoint.port == 3306)
        // An explicit port always wins.
        let explicit = server(.mySQL, host: "mysql.internal:3307").endpoint
        #expect(explicit.host == "mysql.internal")
        #expect(explicit.port == 3307)
    }

    @Test("IPv6 hosts keep everything before the last colon")
    func endpointSplitsOnTheLastColon() {
        let server = DatabaseServer(id: "s", name: "s", engine: .mySQL,
                                    host: "::1:3306", color: .blue, databases: [])
        #expect(server.endpoint.host == "::1")
        #expect(server.endpoint.port == 3306)
    }
}
