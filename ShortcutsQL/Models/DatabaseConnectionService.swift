import Foundation

/// Everything needed to open a connection to one database. `Sendable` so it
/// can be handed to a detached task safely under Swift 6 concurrency.
struct ConnectionParameters: Sendable {
    var engine: DatabaseEngine
    var host: String
    var port: Int
    var database: String
    var user: String
    var password: String
}

/// A connection failure surfaced to the UI with a readable message.
struct ConnectionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Routes a connection to the driver for the server's engine. Every call site
/// (Test connection, the query editor, and the Shortcuts intent) goes through
/// here so adding an engine is a single new case.
enum DatabaseConnectionService {
    /// Opens a connection, runs a trivial statement, and closes it. Throws a
    /// `ConnectionError` with a readable message if anything fails.
    static func testConnection(_ parameters: ConnectionParameters) async throws {
        switch parameters.engine {
        case .postgreSQL: try await PostgresConnectionService.testConnection(parameters)
        case .mySQL: try await MySQLConnectionService.testConnection(parameters)
        }
    }

    /// Runs `sql` against the server/database in `parameters` and returns the
    /// rows plus how long execution took (in milliseconds, excluding
    /// connection setup).
    static func runQuery(
        _ sql: String, _ parameters: ConnectionParameters
    ) async throws -> (table: ResultTable, durationMilliseconds: Int) {
        switch parameters.engine {
        case .postgreSQL: try await PostgresConnectionService.runQuery(sql, parameters)
        case .mySQL: try await MySQLConnectionService.runQuery(sql, parameters)
        }
    }
}
