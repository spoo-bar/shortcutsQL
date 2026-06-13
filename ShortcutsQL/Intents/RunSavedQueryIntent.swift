import AppIntents
import Foundation

/// Shortcuts action: run a saved query against its server/database and return
/// the result as text the rest of the shortcut pipeline can use.
struct RunSavedQueryIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Saved Query"
    static let description = IntentDescription(
        "Runs one of your saved SQL queries against its database and returns the result."
    )

    @Parameter(title: "Query")
    var query: SavedQueryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$query)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = QueryStore()
        guard let saved = store.queries.first(where: { $0.id == query.id }) else {
            throw ConnectionError(message: "That query no longer exists.")
        }
        guard let parameters = store.connectionParameters(for: saved) else {
            throw ConnectionError(
                message: "Couldn\u{2019}t find the server or saved credentials for \u{201C}\(saved.name)\u{201D}."
            )
        }

        let result = try await PostgresConnectionService.runQuery(saved.sql, parameters)

        // Persist the run so the Home screen reflects it (fresh store to avoid
        // sharing state across the awaited call).
        QueryStore().recordRun(
            queryID: saved.id,
            at: Date(),
            durationMilliseconds: result.durationMilliseconds,
            rowCount: result.table.rows.count
        )

        return .result(value: result.table.plainText)
    }
}
