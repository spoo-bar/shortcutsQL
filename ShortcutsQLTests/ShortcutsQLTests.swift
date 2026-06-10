import Testing
@testable import ShortcutsQL

@Suite("SQL validation")
struct SQLValidatorTests {
    @Test("Well-formed SELECT passes")
    func validSelect() {
        #expect(SQLValidator.validate(MockData.queries[0].sql) == nil)
    }

    @Test("Literal SELECT without FROM passes")
    func selectLiteral() {
        #expect(SQLValidator.validate("SELECT 1") == nil)
    }

    @Test("CTE passes")
    func cte() {
        #expect(SQLValidator.validate("WITH x AS (SELECT 1) SELECT * FROM x") == nil)
    }

    @Test("Misspelled keyword is a syntax error naming the token")
    func misspelledKeyword() {
        let error = SQLValidator.validate("SELEC * FORM logs")
        #expect(error?.hasPrefix("syntax error at or near \"SELEC\"") == true)
    }

    @Test("Unmatched opening parenthesis is caught")
    func unmatchedOpeningParen() {
        let error = SQLValidator.validate("SELECT count(* FROM users")
        #expect(error?.contains("unmatched opening parenthesis") == true)
    }

    @Test("Unmatched closing parenthesis is caught")
    func unmatchedClosingParen() {
        let error = SQLValidator.validate("SELECT count(*)) FROM users")
        #expect(error?.contains("unmatched closing parenthesis") == true)
    }

    @Test("Unterminated string literal is caught")
    func unterminatedString() {
        let error = SQLValidator.validate("SELECT * FROM users WHERE plan = 'pro")
        #expect(error?.contains("unterminated quoted string") == true)
    }

    @Test("SELECT of a column without FROM is caught")
    func missingFrom() {
        let error = SQLValidator.validate("SELECT signups")
        #expect(error?.contains("missing FROM clause") == true)
    }

    @Test("Empty statement is caught")
    func emptyStatement() {
        #expect(SQLValidator.validate("  -- only a comment\n") == "empty statement")
    }
}

@Suite("Result shape")
struct ResultShapeTests {
    @Test("Single aggregate is a scalar")
    func scalar() {
        #expect(ResultShape.shape(of: "SELECT count(*) AS signups FROM users") == .scalar)
    }

    @Test("Few columns is a narrow table")
    func narrow() {
        #expect(ResultShape.shape(of: "SELECT name, mrr_usd FROM accounts") == .narrow)
    }

    @Test("The 12-column export is a wide table")
    func wide() {
        let query = MockData.queries.first { $0.id == "subs" }!
        #expect(ResultShape.shape(of: query.sql) == .wide)
        #expect(ResultShape.selectColumnCount(query.sql) == 12)
    }

    @Test("Commas inside parens don't count as columns")
    func nestedParens() {
        #expect(ResultShape.selectColumnCount("SELECT round(sum(amount)/100.0, 0) AS mrr FROM s") == 1)
    }
}

@Suite("Query store")
struct QueryStoreTests {
    @Test("Saving a new query prepends it")
    func saveNew() {
        let store = QueryStore()
        let initialCount = store.queries.count
        let query = SavedQuery(id: "new", name: "Active trials",
                               serverName: "prod-readonly", database: "app_production",
                               sql: "SELECT count(*) FROM trials;",
                               lastRun: "just now", duration: "84 ms", rowsLabel: "1 row")
        store.save(query)
        #expect(store.queries.count == initialCount + 1)
        #expect(store.queries.first?.id == "new")
    }

    @Test("Saving an existing query updates it in place")
    func saveExisting() {
        let store = QueryStore()
        let initialCount = store.queries.count
        var query = store.queries[2]
        query.name = "Renamed"
        store.save(query)
        #expect(store.queries.count == initialCount)
        #expect(store.queries[2].name == "Renamed")
    }

    @Test("Deleting removes the query")
    func delete() {
        let store = QueryStore()
        let id = store.queries[0].id
        store.deleteQuery(id: id)
        #expect(!store.queries.contains { $0.id == id })
    }

    @Test("Database user falls back to the server's")
    func databaseUser() {
        let server = MockData.servers[0]
        #expect(server.user(forDatabase: "app_billing") == "billing_ro")
        #expect(server.user(forDatabase: "app_production") == "readonly")
    }
}
