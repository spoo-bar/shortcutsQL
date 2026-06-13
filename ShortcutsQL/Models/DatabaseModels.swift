import SwiftUI

/// iOS system tints available as server colors (the design's swatch palette).
enum ServerColor: String, CaseIterable, Identifiable, Codable {
    case blue, green, orange, purple, pink, cyan

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .purple: .purple
        case .pink: .pink
        case .cyan: .cyan
        }
    }
}

/// A database exposed by a server.
struct ServerDatabase: Hashable, Identifiable, Codable {
    var name: String

    var id: String { name }
}

/// A database server (a "connection"). One server exposes many databases.
/// Credentials (username + password) are not stored here — they live in the
/// Keychain, keyed by `id`. `host` is stored as the combined "host:port".
struct DatabaseServer: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var engine: String
    var host: String
    var ssl: Bool
    var color: ServerColor
    var databases: [ServerDatabase]

    /// The host and port parsed from the stored "host:port" value (port
    /// defaults to 5432 when absent or unparseable).
    var endpoint: (host: String, port: Int) {
        guard let separator = host.lastIndex(of: ":") else { return (host, 5432) }
        return (String(host[..<separator]), Int(host[host.index(after: separator)...]) ?? 5432)
    }
}

/// A stored SQL query (a "shortcut"). The run metadata is recorded each time
/// the query is executed and is nil until it has run at least once.
struct SavedQuery: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var serverName: String
    var database: String
    var sql: String
    var lastRanAt: Date? = nil
    var durationMilliseconds: Int? = nil
    var rowCount: Int? = nil

    /// e.g. "1 row" / "25 rows", or nil if the query hasn't run.
    var rowsLabel: String? {
        rowCount.map { $0 == 1 ? "1 row" : "\($0) rows" }
    }

    /// e.g. "42 ms" / "1.2 s", or nil if the query hasn't run.
    var durationLabel: String? {
        durationMilliseconds.map { ms in
            ms < 1000 ? "\(ms) ms" : String(format: "%.1f s", Double(ms) / 1000)
        }
    }
}
