import Testing
import Foundation
@testable import ShortcutsQL

@Suite("Result table")
struct ResultTableTests {
    @Test("JSON renders rows as objects keyed by column name")
    func jsonRowsAsObjects() throws {
        let table = ResultTable(
            columns: [ResultColumn(name: "name", isNumeric: false),
                      ResultColumn(name: "mrr", isNumeric: true)],
            rows: [["acme", "100"], ["globex", "50"]],
            countLabel: "2 rows"
        )
        let parsed = try JSONSerialization.jsonObject(with: Data(table.json.utf8)) as? [[String: String]]
        #expect(parsed?.count == 2)
        #expect(parsed?.first?["name"] == "acme")
        #expect(parsed?.first?["mrr"] == "100")
        #expect(parsed?.last?["name"] == "globex")
    }

    @Test("An empty result is an empty JSON array")
    func jsonEmpty() throws {
        let table = ResultTable(
            columns: [ResultColumn(name: "x", isNumeric: false)],
            rows: [], countLabel: "0 rows"
        )
        let parsed = try JSONSerialization.jsonObject(with: Data(table.json.utf8)) as? [Any]
        #expect(parsed?.isEmpty == true)
    }

    // MARK: Building a table from driver output

    @Test("make pairs the reported column names with the rows")
    func makeUsesReportedColumns() {
        let table = ResultTable.make(
            columnNames: ["id", "email"],
            rows: [["1", "a@example.com"], ["2", "b@example.com"]]
        )
        #expect(table.columns.map(\.name) == ["id", "email"])
        #expect(table.countLabel == "2 rows")
    }

    @Test("A single row is labelled in the singular")
    func makeSingularCountLabel() {
        #expect(ResultTable.make(columnNames: ["n"], rows: [["1"]]).countLabel == "1 row")
        #expect(ResultTable.make(columnNames: ["n"], rows: []).countLabel == "0 rows")
    }

    @Test("Columns the server didn't name get positional placeholders")
    func makeFillsMissingColumnNames() {
        // MySQL's text protocol reports column metadata alongside the rows, so
        // a driver can hand over fewer names than the rows are wide.
        let table = ResultTable.make(columnNames: [], rows: [["a", "b", "c"]])
        #expect(table.columns.map(\.name) == ["column1", "column2", "column3"])
    }

    @Test("An all-numeric column is marked numeric, NULLs aside")
    func makeDetectsNumericColumns() {
        let table = ResultTable.make(
            columnNames: ["name", "mrr", "plan"],
            rows: [["acme", "100", "pro"], ["globex", "50.5", ResultTable.nullPlaceholder]]
        )
        #expect(table.columns[0].isNumeric == false)
        #expect(table.columns[1].isNumeric == true)
        #expect(table.columns[2].isNumeric == false)
    }

    @Test("A column of only NULLs is not numeric")
    func makeAllNullColumnIsNotNumeric() {
        let table = ResultTable.make(
            columnNames: ["maybe"],
            rows: [[ResultTable.nullPlaceholder], [ResultTable.nullPlaceholder]]
        )
        #expect(table.columns[0].isNumeric == false)
    }
}
