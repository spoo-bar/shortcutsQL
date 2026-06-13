import Testing
@testable import ShortcutsQL

@Suite("SQL validation")
struct SQLValidatorTests {
    @Test("Well-formed SELECT passes")
    func validSelect() {
        #expect(SQLValidator.validate("SELECT count(*) AS signups FROM users WHERE created_at >= current_date;") == nil)
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
