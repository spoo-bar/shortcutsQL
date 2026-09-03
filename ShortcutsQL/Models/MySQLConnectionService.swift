import Foundation
import MySQLNIO
import NIOSSL

/// Wraps MySQLNIO (a SwiftNIO, future-based client) behind the async API
/// `DatabaseConnectionService` dispatches to.
///
/// Queries go over the text protocol (`COM_QUERY`) rather than prepared
/// statements so every value arrives as the text MySQL itself would print —
/// the same shape the PostgreSQL path produces, and the shape `ResultTable`
/// expects.
enum MySQLConnectionService {
    /// One event loop shared by every connection. Deliberately never shut
    /// down: it lives as long as the process (the app, or the short-lived
    /// Shortcuts extension) and starting a fresh loop per query would cost a
    /// thread spin-up on each run.
    private static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    private static let logger = Logger(label: "xyz.shortcutsql.mysql")

    /// Opens a connection, runs `SELECT 1`, and closes it. Throws a
    /// `ConnectionError` with a readable message if anything fails.
    static func testConnection(_ parameters: ConnectionParameters) async throws {
        _ = try await runQuery("SELECT 1", parameters)
    }

    /// Runs `sql` against the server/database in `parameters` and returns the
    /// rows plus how long execution took (in milliseconds, excluding
    /// connection setup). Throws a `ConnectionError` with a readable message
    /// on failure.
    static func runQuery(
        _ sql: String, _ parameters: ConnectionParameters
    ) async throws -> (table: ResultTable, durationMilliseconds: Int) {
        let connection: MySQLConnection
        do {
            let address = try await resolveAddress(parameters)
            connection = try await MySQLConnection.connect(
                to: address,
                username: parameters.user,
                database: parameters.database,
                password: parameters.password,
                tlsConfiguration: clientTLSConfiguration(),
                serverHostname: sniHostname(for: parameters.host),
                logger: logger,
                on: eventLoopGroup.next()
            ).get()
        } catch {
            throw ConnectionError(message: readableMessage(for: error))
        }

        do {
            let start = Date()
            let rows = try await connection.simpleQuery(sql).get()
            let durationMilliseconds = Int(Date().timeIntervalSince(start) * 1000)
            // MySQLConnection asserts it was closed before deinit, so close on
            // the failure path too.
            try? await connection.close().get()
            return (table(from: rows), durationMilliseconds)
        } catch {
            try? await connection.close().get()
            throw ConnectionError(message: readableMessage(for: error))
        }
    }

    /// Converts the driver's rows into a `ResultTable`, rendering every value
    /// as text and a SQL NULL as "NULL".
    ///
    /// Column names come from the rows themselves — the text protocol reports
    /// column metadata alongside the data, so a result with no rows also has
    /// no column headers to show.
    static func table(from rows: [MySQLRow]) -> ResultTable {
        let cells = rows.map { row in
            zip(row.columnDefinitions, row.values).map { column, value in
                MySQLData(
                    type: column.columnType,
                    format: row.format,
                    buffer: value,
                    isUnsigned: column.flags.contains(.COLUMN_UNSIGNED)
                ).string ?? ResultTable.nullPlaceholder
            }
        }
        return ResultTable.make(
            columnNames: rows.first?.columnDefinitions.map(\.name) ?? [], rows: cells
        )
    }

    /// The hostname to present for TLS server-name indication, or nil when the
    /// host is an IP literal — NIOSSL rejects those as SNI names, which would
    /// turn "connect to 10.0.0.5" into a TLS error rather than a connection.
    static func sniHostname(for host: String) -> String? {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        if inet_pton(AF_INET, host, &ipv4) == 1 || inet_pton(AF_INET6, host, &ipv6) == 1 {
            return nil
        }
        return host
    }

    /// TLS settings for the connection. MySQLNIO negotiates TLS when the
    /// server advertises it and stays on a plaintext connection when it
    /// doesn't, so this is safe to pass unconditionally.
    ///
    /// Certificate verification is off to match the PostgreSQL path
    /// (PostgresClientKit's `ssl = true` doesn't validate the server
    /// certificate either): MySQL servers overwhelmingly present the
    /// self-signed certificate the server generates on first start, and
    /// rejecting those would make the engine unusable in practice. Traffic is
    /// still encrypted, but it isn't protected against an active
    /// man-in-the-middle.
    private static func clientTLSConfiguration() -> TLSConfiguration {
        var configuration = TLSConfiguration.makeClientConfiguration()
        configuration.certificateVerification = .none
        return configuration
    }

    /// Resolves "host:port" to a socket address. Name resolution blocks, so it
    /// runs off the calling task's thread.
    private static func resolveAddress(
        _ parameters: ConnectionParameters
    ) async throws -> SocketAddress {
        let host = parameters.host
        let port = parameters.port
        return try await Task.detached(priority: .userInitiated) {
            try SocketAddress.makeAddressResolvingHost(host, port: port)
        }.value
    }

    static func readableMessage(for error: any Error) -> String {
        if let error = error as? MySQLError {
            switch error {
            case .server(let packet):
                return packet.errorMessage
            case .invalidSyntax(let message):
                return message
            case .duplicateEntry(let message):
                return "Duplicate entry: \(message)"
            case .secureConnectionRequired:
                return "The server requires a secure connection to authenticate this user."
            case .unsupportedAuthPlugin(let name):
                return "The server requires an unsupported authentication plugin (\(name))."
            case .closed:
                return "The connection to the server was closed."
            default:
                return error.message
            }
        }
        if error is SocketAddressError {
            return "Couldn\u{2019}t resolve the host. Check the server address."
        }
        // A refused/timed-out connection surfaces as a socket-level error.
        if error is NIOConnectionError || error is IOError {
            return "Couldn\u{2019}t reach the server. Check the host and port and that it\u{2019}s reachable from this device."
        }
        if error is NIOSSLError {
            return "SSL/TLS negotiation failed. Confirm the server supports SSL."
        }
        return error.localizedDescription
    }
}
