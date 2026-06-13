import Foundation

/// A single column in a query result.
struct ResultColumn: Hashable, Sendable {
    let name: String
    let isNumeric: Bool
}

/// A tabular query result returned by running a query. Cell values are the
/// raw text Postgres sends; a SQL NULL is shown as "NULL".
struct ResultTable: Equatable, Sendable {
    let columns: [ResultColumn]
    let rows: [[String]]
    let countLabel: String

    /// A plain-text rendering for returning to the Shortcuts pipeline: a bare
    /// value for a single cell, otherwise a tab-separated table with a header.
    var plainText: String {
        if columns.count == 1 && rows.count == 1 { return rows[0][0] }
        var lines: [String] = []
        if !columns.isEmpty { lines.append(columns.map(\.name).joined(separator: "\t")) }
        lines.append(contentsOf: rows.map { $0.joined(separator: "\t") })
        return lines.joined(separator: "\n")
    }
}
