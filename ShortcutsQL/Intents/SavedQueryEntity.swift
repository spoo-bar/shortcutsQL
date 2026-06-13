import AppIntents

/// A saved query exposed to the Shortcuts app so it can be picked as a
/// parameter and run from a shortcut.
struct SavedQueryEntity: AppEntity {
    let id: String
    let name: String
    let serverName: String
    let database: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Saved Query" }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(serverName) · \(database)"
        )
    }

    static let defaultQuery = SavedQueryEntityQuery()

    init(id: String, name: String, serverName: String, database: String) {
        self.id = id
        self.name = name
        self.serverName = serverName
        self.database = database
    }

    init(_ query: SavedQuery) {
        self.init(id: query.id, name: query.name, serverName: query.serverName, database: query.database)
    }
}

/// Surfaces every stored query to Shortcuts: `suggestedEntities` populates the
/// parameter picker, `entities(for:)` resolves a previously chosen query.
struct SavedQueryEntityQuery: EntityQuery {
    func entities(for identifiers: [SavedQueryEntity.ID]) async throws -> [SavedQueryEntity] {
        QueryStore().queries
            .filter { identifiers.contains($0.id) }
            .map(SavedQueryEntity.init)
    }

    func suggestedEntities() async throws -> [SavedQueryEntity] {
        QueryStore().queries.map(SavedQueryEntity.init)
    }
}
