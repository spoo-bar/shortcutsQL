import Testing
import Foundation
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

    @Test("SELECT of a bare function call without FROM passes")
    func selectFunctionCall() {
        #expect(SQLValidator.validate("SELECT now()") == nil)
        #expect(SQLValidator.validate("SELECT version()", engine: .mySQL) == nil)
    }

    // MARK: MySQL dialect

    @Test("Well-formed MySQL passes")
    func mySQLValidSelect() {
        #expect(SQLValidator.validate("SELECT COUNT(*) FROM users;", engine: .mySQL) == nil)
        #expect(SQLValidator.validate("SELECT 1", engine: .mySQL) == nil)
    }

    @Test("MySQL accepts DESCRIBE and SHOW, PostgreSQL only SHOW")
    func mySQLLeadingKeywords() {
        #expect(SQLValidator.validate("DESCRIBE users", engine: .mySQL) == nil)
        #expect(SQLValidator.validate("DESC users", engine: .mySQL) == nil)
        #expect(SQLValidator.validate("SHOW TABLES", engine: .mySQL) == nil)
        // DESCRIBE isn't a PostgreSQL statement, so it stays an error there.
        #expect(SQLValidator.validate("DESCRIBE users", engine: .postgreSQL) != nil)
        #expect(SQLValidator.validate("SHOW TABLES", engine: .postgreSQL) == nil)
    }

    @Test("A MySQL syntax error reads like MySQL, not PostgreSQL")
    func mySQLSyntaxErrorWording() throws {
        let error = try #require(SQLValidator.validate("SELEC * FORM logs", engine: .mySQL))
        #expect(error.hasPrefix("You have an error in your SQL syntax;"))
        #expect(error.contains("near 'SELEC' at line 1"))
        #expect(error.contains("your MySQL server version"))
        // The PostgreSQL caret block doesn't belong in a MySQL message.
        #expect(!error.contains("LINE 1:"))
    }

    @Test("MySQL still catches unbalanced parentheses and quotes")
    func mySQLStructuralErrors() {
        #expect(SQLValidator.validate("SELECT COUNT(* FROM users", engine: .mySQL)?
            .contains("unmatched opening parenthesis") == true)
        #expect(SQLValidator.validate("SELECT COUNT(*)) FROM users", engine: .mySQL)?
            .contains("unmatched closing parenthesis") == true)
        #expect(SQLValidator.validate("SELECT * FROM users WHERE plan = 'pro", engine: .mySQL)?
            .contains("unterminated quoted string") == true)
        #expect(SQLValidator.validate("SELECT signups", engine: .mySQL)?
            .contains("missing FROM clause") == true)
    }

    @Test("MySQL treats # as a line comment")
    func mySQLHashComment() {
        #expect(SQLValidator.validate("# just a note\n", engine: .mySQL) == "empty statement")
        #expect(SQLValidator.validate("SELECT id FROM users # trailing note", engine: .mySQL) == nil)
        // PostgreSQL has no # comment, so the same text is a syntax error there.
        #expect(SQLValidator.validate("# just a note\n", engine: .postgreSQL) != nil)
    }

    @Test("Comment stripping is engine-aware")
    func stripCommentsPerEngine() {
        #expect(SQLValidator.stripComments("SELECT 1 -- note", engine: .postgreSQL)
            .trimmingCharacters(in: .whitespaces) == "SELECT 1")
        #expect(SQLValidator.stripComments("SELECT 1 # note", engine: .mySQL)
            .trimmingCharacters(in: .whitespaces) == "SELECT 1")
        #expect(SQLValidator.stripComments("SELECT 1 # note", engine: .postgreSQL)
            .contains("# note"))
    }

    // MARK: MariaDB dialect

    @Test("Well-formed MariaDB passes")
    func mariaDBValidSelect() {
        #expect(SQLValidator.validate("SELECT COUNT(*) FROM users;", engine: .mariaDB) == nil)
        #expect(SQLValidator.validate("SELECT 1", engine: .mariaDB) == nil)
        #expect(SQLValidator.validate("SELECT version()", engine: .mariaDB) == nil)
    }

    @Test("MariaDB accepts the same leading keywords as MySQL")
    func mariaDBLeadingKeywords() {
        #expect(SQLValidator.validate("DESCRIBE users", engine: .mariaDB) == nil)
        #expect(SQLValidator.validate("DESC users", engine: .mariaDB) == nil)
        #expect(SQLValidator.validate("SHOW TABLES", engine: .mariaDB) == nil)
        #expect(SQLValidator.allowedLeadingKeywords(for: .mariaDB)
            == SQLValidator.allowedLeadingKeywords(for: .mySQL))
    }

    @Test("A MariaDB syntax error points at the MariaDB manual")
    func mariaDBSyntaxErrorWording() throws {
        let error = try #require(SQLValidator.validate("SELEC * FORM logs", engine: .mariaDB))
        #expect(error.hasPrefix("You have an error in your SQL syntax;"))
        #expect(error.contains("near 'SELEC' at line 1"))
        // MariaDB is its own server, so it shouldn't send users to MySQL's manual.
        #expect(error.contains("your MariaDB server version"))
        #expect(!error.contains("MySQL"))
        #expect(!error.contains("LINE 1:"))
    }

    @Test("MariaDB still catches unbalanced parentheses and quotes")
    func mariaDBStructuralErrors() {
        #expect(SQLValidator.validate("SELECT COUNT(* FROM users", engine: .mariaDB)?
            .contains("unmatched opening parenthesis") == true)
        #expect(SQLValidator.validate("SELECT COUNT(*)) FROM users", engine: .mariaDB)?
            .contains("unmatched closing parenthesis") == true)
        #expect(SQLValidator.validate("SELECT * FROM users WHERE plan = 'pro", engine: .mariaDB)?
            .contains("unterminated quoted string") == true)
        #expect(SQLValidator.validate("SELECT signups", engine: .mariaDB)?
            .contains("missing FROM clause") == true)
        // Every one of those reads like MariaDB rather than PostgreSQL.
        #expect(SQLValidator.validate("SELECT signups", engine: .mariaDB)?
            .contains("your MariaDB server version") == true)
    }

    @Test("MariaDB treats # as a line comment")
    func mariaDBHashComment() {
        #expect(SQLValidator.validate("# just a note\n", engine: .mariaDB) == "empty statement")
        #expect(SQLValidator.validate("SELECT id FROM users # trailing note",
                                      engine: .mariaDB) == nil)
        #expect(SQLValidator.stripComments("SELECT 1 # note", engine: .mariaDB)
            .trimmingCharacters(in: .whitespaces) == "SELECT 1")
    }
}
