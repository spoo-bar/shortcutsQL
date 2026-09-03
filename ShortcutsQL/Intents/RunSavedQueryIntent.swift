import AppIntents
import Foundation

/// Shortcuts action: run a saved query against its server/database and return
/// the rows as JSON for the rest of the shortcut pipeline.
///
/// The query is selected by name via a dynamic options picker rather than an
/// AppEntity parameter: an intent whose only parameter is an AppEntity makes
/// Shortcuts surface that entity as the action's output instead of the
/// returned value, so a plain String parameter is used here.
struct RunSavedQueryIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Saved Query"
    static let description = IntentDescription(
        "Runs one of your saved SQL queries against its database and returns the rows as JSON."
    )

    @Parameter(title: "Query", optionsProvider: SavedQueryOptionsProvider())
    var queryName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$queryName)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = QueryStore()
        guard let saved = store.queries.first(where: { $0.name == queryName }) else {
            throw ConnectionError(message: "No saved query named \u{201C}\(queryName)\u{201D}.")
        }
        guard let parameters = store.connectionParameters(for: saved) else {
            throw ConnectionError(
                message: "Couldn\u{2019}t find the server or saved credentials for \u{201C}\(saved.name)\u{201D}."
            )
        }

        let result = try await DatabaseConnectionService.runQuery(saved.sql, parameters)

        // Persist the run so the Home screen reflects it (fresh store to avoid
        // sharing state across the awaited call).
        let ranAt = Date()
        let store2 = QueryStore()
        store2.recordRun(
            queryID: saved.id,
            at: ranAt,
            durationMilliseconds: result.durationMilliseconds,
            rowCount: result.table.rows.count
        )

        // When history is enabled, retain this result (trimmed to the query's
        // per-query limit) so the "Historical <query>" Shortcut can return it.
        if store2.isHistoryEnabled {
            store2.recordHistory(
                queryID: saved.id,
                entry: QueryHistoryEntry(
                    id: "h\(Int(ranAt.timeIntervalSince1970 * 1000))",
                    ranAt: ranAt,
                    resultJSON: result.table.json
                ),
                limit: saved.effectiveHistoryLimit
            )
        }

        return .result(value: result.table.json)
    }
}

/// Supplies the saved query names for the Shortcuts picker.
struct SavedQueryOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        QueryStore().queries.map(\.name)
    }
}
