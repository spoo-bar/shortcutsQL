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

    /// A JSON array of row objects (each keyed by column name) for returning
    /// to the Shortcuts pipeline. Values are strings; a SQL NULL is the string
    /// "NULL". Returns "[]" if serialization fails.
    var json: String {
        let objects: [[String: String]] = rows.map { row in
            var object: [String: String] = [:]
            for (index, column) in columns.enumerated() where index < row.count {
                object[column.name] = row[index]
            }
            return object
        }
        guard let data = try? JSONSerialization.data(
                withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
