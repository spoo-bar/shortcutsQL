import Foundation

/// A database engine ShortcutsQL can actually connect to.
///
/// The raw value is both the display name and what gets persisted inside
/// `DatabaseServer`, so it must stay stable across releases.
enum DatabaseEngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case postgreSQL = "PostgreSQL"
    case mySQL = "MySQL"

    var id: String { rawValue }

    /// The engine assumed for servers saved before the engine was recorded,
    /// or saved with an engine that is no longer offered.
    static let fallback = DatabaseEngine.postgreSQL

    /// The port used when a server's stored "host:port" carries no usable port.
    var defaultPort: Int {
        switch self {
        case .postgreSQL: 5432
        case .mySQL: 3306
        }
    }

    /// The database to connect to when a query doesn't name one. PostgreSQL
    /// requires a database name in the startup message; MySQL is happy to
    /// connect without one selected.
    var defaultDatabase: String {
        switch self {
        case .postgreSQL: "postgres"
        case .mySQL: ""
        }
    }

    /// Subtitle for the engine picker, e.g. "default port 3306".
    var pickerSubtitle: String { "default port \(defaultPort)" }

    /// Matches an engine by its display name, case-insensitively. Returns nil
    /// for names this build can't connect to (e.g. "SQL Server").
    static func named(_ name: String) -> DatabaseEngine? {
        allCases.first { $0.rawValue.compare(name, options: .caseInsensitive) == .orderedSame }
    }

    /// Decodes unknown engine names as `fallback` instead of throwing: a
    /// single unrecognised value would otherwise fail the array decode and
    /// silently drop *every* saved server.
    init(from decoder: any Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        self = Self.named(name) ?? Self.fallback
    }
}
