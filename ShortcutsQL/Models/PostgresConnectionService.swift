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
            configuration.ssl = parameters.ssl
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
            return "SSL/TLS negotiation failed. Try turning off \u{201C}Use SSL/TLS\u{201D}, or confirm the server supports SSL."
        case .socketError:
            return "Couldn\u{2019}t reach the server. Check the host and port and that it\u{2019}s reachable from this device."
        case .serverError(let description):
            return description
        default:
            return String(describing: error)
        }
    }
}

/// A connection failure surfaced to the UI with a readable message.
struct ConnectionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
