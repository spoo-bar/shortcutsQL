import AppIntents
import Foundation

/// Shortcuts action: return the retained history of results for a saved query
/// as a JSON array. Unlike "Run <query>", this does not touch the database —
/// it reads the results stored by past Shortcuts runs. Requires the History
/// setting to be enabled.
///
/// The query is selected by name via the same dynamic options picker used by
/// `RunSavedQueryIntent` (see `SavedQueryOptionsProvider`).
struct HistoricalQueryIntent: AppIntent {
    static let title: LocalizedStringResource = "Historical Query Results"
    static let description = IntentDescription(
        "Returns the stored history of results for one of your saved queries as a JSON array. Enable History in Settings to start retaining results."
    )

    @Parameter(title: "Query", optionsProvider: SavedQueryOptionsProvider())
    var queryName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Historical \(\.$queryName)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = QueryStore()
        guard store.isHistoryEnabled else {
            throw ConnectionError(
                message: "History is turned off. Enable it in ShortcutsQL \u{2192} Settings to start retaining results."
            )
        }
        guard let saved = store.queries.first(where: { $0.name == queryName }) else {
            throw ConnectionError(message: "No saved query named \u{201C}\(queryName)\u{201D}.")
        }

        let entries = store.history(forQueryID: saved.id)
        return .result(value: QueryHistoryEntry.jsonArray(entries))
    }
}
