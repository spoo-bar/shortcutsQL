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
    var engine: DatabaseEngine
    var host: String
    var color: ServerColor
    var databases: [ServerDatabase]

    /// The host and port parsed from the stored "host:port" value (port
    /// defaults to the engine's standard port when absent or unparseable).
    var endpoint: (host: String, port: Int) {
        guard let separator = host.lastIndex(of: ":") else { return (host, engine.defaultPort) }
        return (
            String(host[..<separator]),
            Int(host[host.index(after: separator)...]) ?? engine.defaultPort
        )
    }
}

/// A stored SQL query (a "shortcut"). The run metadata is recorded each time
/// the query is executed and is nil until it has run at least once.
struct SavedQuery: Identifiable, Hashable, Codable {
    /// The per-query history cap used when none is set.
    static let defaultHistoryLimit = 5

    let id: String
    var name: String
    var serverName: String
    var database: String
    var sql: String
    var lastRanAt: Date? = nil
    var durationMilliseconds: Int? = nil
    var rowCount: Int? = nil
    /// How many past results to retain for this query when history is enabled.
    /// Optional so queries persisted before this feature still decode (a
    /// missing key must not fail the whole decode and drop every saved query).
    var historyLimit: Int? = nil

    /// The effective number of results to keep, clamped to a sane range.
    var effectiveHistoryLimit: Int {
        max(1, min(historyLimit ?? Self.defaultHistoryLimit, 50))
    }

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

/// A single retained result from running a saved query. Captured only when
/// history is enabled and only for Shortcuts runs. Stores the full result
/// snapshot (as `ResultTable.json`) plus when it ran.
struct QueryHistoryEntry: Identifiable, Hashable, Codable {
    let id: String
    let ranAt: Date
    /// A snapshot of `ResultTable.json` — a JSON array of row objects.
    let resultJSON: String

    /// Serializes history entries (newest first) into the JSON array returned
    /// by the "Historical <query>" Shortcut. Each element is
    /// `{ "ranAt": <ISO8601>, "result": [ {column: value}, ... ] }`. The stored
    /// `resultJSON` is parsed back into real JSON so it nests rather than being
    /// an escaped string. Returns "[]" if serialization fails.
    static func jsonArray(_ entries: [QueryHistoryEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        let objects: [[String: Any]] = entries.map { entry in
            let result = (entry.resultJSON.data(using: .utf8))
                .flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? []
            return ["ranAt": formatter.string(from: entry.ranAt), "result": result]
        }
        guard let data = try? JSONSerialization.data(
                withJSONObject: objects, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
