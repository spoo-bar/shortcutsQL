import Foundation

/// A single column in a query result.
struct ResultColumn: Hashable {
    let name: String
    let isNumeric: Bool
}

/// A tabular query result. Real results will populate this once database
/// execution is wired up.
struct ResultTable {
    let columns: [ResultColumn]
    let rows: [[String]]
    let countLabel: String
}
