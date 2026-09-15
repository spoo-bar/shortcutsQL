import Testing
import Foundation
@testable import ShortcutsQL

@Suite("Connection routing")
struct DatabaseConnectionServiceTests {
    @Test("Each engine is routed to its driver")
    func driverPerEngine() {
        #expect(DatabaseConnectionService.driver(for: .postgreSQL) == .postgres)
        #expect(DatabaseConnectionService.driver(for: .mySQL) == .mySQL)
        // MariaDB speaks the MySQL protocol, so it shares MySQLNIO.
        #expect(DatabaseConnectionService.driver(for: .mariaDB) == .mySQL)
    }

    @Test("Only PostgreSQL uses the PostgreSQL driver")
    func onlyPostgresUsesItsOwnDriver() {
        // An engine added later must pick a driver deliberately rather than
        // falling into the PostgreSQL path by default.
        let onPostgres = DatabaseEngine.allCases.filter {
            DatabaseConnectionService.driver(for: $0) == .postgres
        }
        #expect(onPostgres == [.postgreSQL])
    }
}
