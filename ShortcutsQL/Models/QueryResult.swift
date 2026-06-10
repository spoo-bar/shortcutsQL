import Foundation

/// The shape a query's mock result takes. The row data is illustrative
/// (no real database), but the shape is driven by the SQL itself.
enum ResultShape {
    case scalar
    case narrow
    case wide

    /// Single aggregate → scalar; ≥8 selected columns → wide table.
    static func shape(of sql: String) -> ResultShape {
        if looksScalar(sql) { return .scalar }
        return selectColumnCount(sql) >= 8 ? .wide : .narrow
    }

    static func looksScalar(_ sql: String) -> Bool {
        let body = SQLValidator.stripComments(sql).lowercased()
        let list: Substring
        if let match = body.firstMatch(of: /select\s+(.*?)\s+from/.dotMatchesNewlines()) {
            list = match.1
        } else {
            list = body[...]
        }
        let aggregate = list.firstMatch(of: /(count|sum|avg|min|max|round)\s*\(/) != nil
        return aggregate && !list.contains(",")
    }

    /// Counts top-level columns in the SELECT list (commas outside parens).
    static func selectColumnCount(_ sql: String) -> Int {
        let body = SQLValidator.stripComments(sql)
        guard let match = body.firstMatch(of: /select\s+(.*?)\s+from\b/.ignoresCase().dotMatchesNewlines()) else {
            return 1
        }
        var depth = 0
        var count = 1
        for character in match.1 {
            switch character {
            case "(": depth += 1
            case ")": depth -= 1
            case "," where depth == 0: count += 1
            default: break
            }
        }
        return count
    }
}

struct ResultColumn: Hashable {
    let name: String
    let isNumeric: Bool
}

struct ResultTable {
    let columns: [ResultColumn]
    let rows: [[String]]
    let countLabel: String
}

/// Canned results returned by "Run query" — scalar, narrow, or wide,
/// depending on the SQL's shape.
enum MockResults {
    static let scalarValue = "1,284"
    static let scalarUnit = "signups"
    static let scalarCountLabel = "1 row"

    static let narrowTable = ResultTable(
        columns: [
            ResultColumn(name: "account", isNumeric: false),
            ResultColumn(name: "plan", isNumeric: false),
            ResultColumn(name: "seats", isNumeric: true),
            ResultColumn(name: "mrr_usd", isNumeric: true),
        ],
        rows: [
            ["acme-corp", "Enterprise", "120", "12,400"],
            ["initech", "Business", "64", "9,820"],
            ["hooli", "Business", "48", "7,640"],
            ["globex", "Pro", "30", "6,210"],
            ["umbrella", "Pro", "22", "5,005"],
        ],
        countLabel: "5 rows"
    )

    // Wide result (>10 columns) — exercises the table's horizontal scroll.
    static let wideTable = ResultTable(
        columns: [
            ResultColumn(name: "id", isNumeric: true),
            ResultColumn(name: "email", isNumeric: false),
            ResultColumn(name: "full_name", isNumeric: false),
            ResultColumn(name: "plan", isNumeric: false),
            ResultColumn(name: "seats", isNumeric: true),
            ResultColumn(name: "mrr_usd", isNumeric: true),
            ResultColumn(name: "country", isNumeric: false),
            ResultColumn(name: "signup_date", isNumeric: false),
            ResultColumn(name: "last_seen", isNumeric: false),
            ResultColumn(name: "trial_ends", isNumeric: false),
            ResultColumn(name: "verified", isNumeric: false),
            ResultColumn(name: "churn_risk", isNumeric: false),
        ],
        rows: [
            ["1042", "ada@acme.co", "Ada Lovelace", "Enterprise", "120", "12,400", "US", "2023-04-12", "2026-06-09", "—", "true", "low"],
            ["2087", "grace@initech.io", "Grace Hopper", "Business", "64", "9,820", "US", "2023-09-30", "2026-06-08", "—", "true", "low"],
            ["3310", "alan@hooli.com", "Alan Turing", "Business", "48", "7,640", "GB", "2024-01-18", "2026-06-09", "—", "true", "med"],
            ["4521", "edsger@globex.dev", "E. Dijkstra", "Pro", "30", "6,210", "NL", "2024-06-02", "2026-06-05", "—", "false", "med"],
            ["5093", "linus@umbrella.co", "Linus T.", "Pro", "22", "5,005", "FI", "2024-08-21", "2026-06-09", "—", "true", "low"],
            ["6644", "margaret@soylent.io", "M. Hamilton", "Pro", "18", "4,180", "US", "2025-02-14", "2026-05-28", "2026-06-14", "false", "high"],
        ],
        countLabel: "50 rows"
    )

    static func table(for shape: ResultShape) -> ResultTable {
        shape == .wide ? wideTable : narrowTable
    }

    static func rowsLabel(for shape: ResultShape) -> String {
        switch shape {
        case .scalar: "1 row"
        case .narrow: "5 rows"
        case .wide: "50 rows"
        }
    }
}
