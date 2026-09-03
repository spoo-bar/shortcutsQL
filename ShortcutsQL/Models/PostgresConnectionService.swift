import Foundation
import PostgresClientKit

/// Wraps PostgresClientKit (a synchronous/blocking client) behind the async
/// API `DatabaseConnectionService` dispatches to.
enum PostgresConnectionService {
    /// Opens a connection, runs `SELECT 1`, and closes it. Throws a
    /// `ConnectionError` with a readable message if anything fails.
    static func testConnection(_ parameters: ConnectionParameters) async throws {
        // PostgresClientKit is blocking, so run it off the main thread.
        try await Task.detached(priority: .userInitiated) {
            do {
                let connection = try openConnection(parameters)
                defer { connection.close() }
                let statement = try connection.prepareStatement(text: "SELECT 1")
                defer { statement.close() }
                _ = try statement.execute()
            } catch {
                throw ConnectionError(message: readableMessage(for: error))
            }
        }.value
    }

    /// Runs `sql` against the server/database in `parameters` and returns the
    /// rows plus how long execution took (in milliseconds, excluding connection
    /// setup). Throws a `ConnectionError` with a readable message on failure.
    static func runQuery(
        _ sql: String, _ parameters: ConnectionParameters
    ) async throws -> (table: ResultTable, durationMilliseconds: Int) {
        try await Task.detached(priority: .userInitiated) {
            do {
                let connection = try openConnection(parameters)
                defer { connection.close() }
                let statement = try connection.prepareStatement(text: sql)
                defer { statement.close() }

                let start = Date()
                let cursor = try statement.execute(retrieveColumnMetadata: true)
                defer { cursor.close() }

                var rows: [[String]] = []
                for result in cursor {
                    let row = try result.get()
                    rows.append(row.columns.map { $0.rawValue ?? ResultTable.nullPlaceholder })
                }
                let durationMilliseconds = Int(Date().timeIntervalSince(start) * 1000)

                let table = ResultTable.make(
                    columnNames: cursor.columns?.map(\.name) ?? [], rows: rows
                )
                return (table, durationMilliseconds)
            } catch {
                throw ConnectionError(message: readableMessage(for: error))
            }
        }.value
    }

    /// Opens a connection. PostgresClientKit needs the credential to match the
    /// method the server requests, so try SCRAM-SHA-256 (the modern default)
    /// and only switch methods when the server *explicitly* asks for another
    /// one — a real failure (e.g. a bad password) is surfaced as-is rather
    /// than masked by a follow-up attempt with the wrong method.
    private static func openConnection(_ parameters: ConnectionParameters) throws -> Connection {
        func configuration(_ credential: Credential) -> ConnectionConfiguration {
            var configuration = ConnectionConfiguration()
            configuration.host = parameters.host
            configuration.port = parameters.port
            configuration.database = parameters.database
            configuration.user = parameters.user
            configuration.ssl = true
            configuration.credential = credential
            return configuration
        }

        let password = parameters.password
        do {
            return try Connection(configuration: configuration(.scramSHA256(password: password)))
        } catch PostgresError.md5PasswordCredentialRequired {
            return try Connection(configuration: configuration(.md5Password(password: password)))
        } catch PostgresError.cleartextPasswordCredentialRequired {
            return try Connection(configuration: configuration(.cleartextPassword(password: password)))
        } catch PostgresError.trustCredentialRequired {
            return try Connection(configuration: configuration(.trust))
        }
    }

    private static func readableMessage(for error: Error) -> String {
        guard let error = error as? PostgresError else { return error.localizedDescription }
        switch error {
        case .sqlError(let notice):
            return notice.message ?? "The server reported an error."
        case .scramSHA256CredentialRequired, .md5PasswordCredentialRequired,
             .cleartextPasswordCredentialRequired, .trustCredentialRequired:
            return "Authentication failed. Check the username and password."
        case .unsupportedAuthenticationType(let type):
            return "The server requires an unsupported authentication type (\(type))."
        case .sslError:
            return "SSL/TLS negotiation failed. Confirm the server supports SSL."
        case .socketError:
            return "Couldn\u{2019}t reach the server. Check the host and port and that it\u{2019}s reachable from this device."
        case .serverError(let description):
            return description
        default:
            return String(describing: error)
        }
    }
}
