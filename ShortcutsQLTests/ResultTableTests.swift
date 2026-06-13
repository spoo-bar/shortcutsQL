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
}
