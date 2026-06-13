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
}
