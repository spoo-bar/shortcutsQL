import Foundation
import PostgresClientKit

/// Everything needed to open a PostgreSQL connection. `Sendable` so it can be
/// handed to a detached task safely under Swift 6 concurrency.
struct ConnectionParameters: Sendable {
    var host: String
    var port: Int
    var database: String
    var user: String
    var password: String
    var ssl: Bool
}

/// Wraps PostgresClientKit (a synchronous/blocking client) behind an async
/// API. Used by Add Database's "Test connection". Query execution is not
/// wired up yet.
enum PostgresConnectionService {
    /// Opens a connection, runs `SELECT 1`, and closes it. Throws a
    /// `ConnectionError` with a readable message if anything fails.
    static func testConnection(_ parameters: ConnectionParameters) async throws {
        // PostgresClientKit is blocking, so run it off the main thread.
        try await Task.detached(priority: .userInitiated) {
            let connection = try openConnection(parameters)
            defer { connection.close() }
            let statement = try connection.prepareStatement(text: "SELECT 1")
            defer { statement.close() }
            _ = try statement.execute()
        }.value
    }

    /// Opens a connection, trying SCRAM-SHA-256 first and falling back to MD5
    /// if the server rejects the auth method (Postgres dictates which it uses).
    private static func openConnection(_ parameters: ConnectionParameters) throws -> Connection {
        var configuration = ConnectionConfiguration()
        configuration.host = parameters.host
        configuration.port = parameters.port
        configuration.database = parameters.database
        configuration.user = parameters.user
        configuration.ssl = parameters.ssl

        let credentials: [Credential] = [
            .scramSHA256(password: parameters.password),
            .md5Password(password: parameters.password),
        ]

        var lastError: Error?
        for credential in credentials {
            configuration.credential = credential
            do {
                return try Connection(configuration: configuration)
            } catch {
                lastError = error
                // Only fall through to the next method when the failure looks
                // like an auth-method mismatch; otherwise stop and report it.
                if !isAuthMethodMismatch(error) { break }
            }
        }
        throw ConnectionError(message: readableMessage(for: lastError))
    }

    private static func isAuthMethodMismatch(_ error: Error) -> Bool {
        // PostgresClientKit raises an error referencing the auth type when the
        // chosen credential doesn't match what the server requested.
        let text = String(describing: error).lowercased()
        return text.contains("authentication") || text.contains("password")
    }

    private static func readableMessage(for error: Error?) -> String {
        guard let error else { return "Could not connect to the server." }
        if let postgresError = error as? PostgresError {
            return String(describing: postgresError)
        }
        return error.localizedDescription
    }
}

/// A connection failure surfaced to the UI with a readable message.
struct ConnectionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
