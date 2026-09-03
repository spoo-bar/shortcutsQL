import Foundation

/// A single column in a query result.
struct ResultColumn: Hashable, Sendable {
    let name: String
    let isNumeric: Bool
}

/// A tabular query result returned by running a query. Cell values are the
/// raw text the server sends; a SQL NULL is shown as "NULL".
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

extension ResultTable {
    /// The placeholder shown for a SQL NULL.
    static let nullPlaceholder = "NULL"

    /// Builds a table from the raw text cells a driver produced. Column names
    /// the server didn't report are filled in as "column1", "column2", … so a
    /// short metadata list never truncates the visible data, and a column is
    /// marked numeric (for right-alignment) when every non-NULL cell parses as
    /// a number.
    static func make(columnNames: [String], rows: [[String]]) -> ResultTable {
        let width = max(columnNames.count, rows.map(\.count).max() ?? 0)
        let columns = (0..<width).map { index in
            ResultColumn(
                name: index < columnNames.count ? columnNames[index] : "column\(index + 1)",
                isNumeric: isNumericColumn(rows, index)
            )
        }
        return ResultTable(
            columns: columns,
            rows: rows,
            countLabel: rows.count == 1 ? "1 row" : "\(rows.count) rows"
        )
    }

    /// A column is treated as numeric when it has at least one non-NULL cell
    /// and every one of them parses as a number.
    private static func isNumericColumn(_ rows: [[String]], _ index: Int) -> Bool {
        var sawValue = false
        for row in rows where index < row.count {
            let cell = row[index]
            if cell == nullPlaceholder { continue }
            sawValue = true
            if Double(cell) == nil { return false }
        }
        return sawValue
    }
}
