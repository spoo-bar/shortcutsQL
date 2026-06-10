import SwiftUI

/// iOS system tints available as server colors (the design's swatch palette).
enum ServerColor: String, CaseIterable, Identifiable {
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

/// A database exposed by a server. It may carry its own credentials
/// (`user`) or inherit the server's.
struct ServerDatabase: Hashable, Identifiable {
    var name: String
    var user: String?

    var id: String { name }
}

/// A database server (a "connection"). One server exposes many databases.
struct DatabaseServer: Identifiable, Hashable {
    let id: String
    var name: String
    var engine: String
    var host: String
    var user: String
    var color: ServerColor
    var databases: [ServerDatabase]

    /// The user a given database connects as (its own, or the server's).
    func user(forDatabase name: String) -> String {
        databases.first { $0.name == name }?.user ?? user
    }
}

/// A stored SQL query (a "shortcut").
struct SavedQuery: Identifiable, Hashable {
    let id: String
    var name: String
    var serverName: String
    var database: String
    var sql: String
    var lastRun: String
    var duration: String
    var rowsLabel: String
}
