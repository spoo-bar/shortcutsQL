import Foundation

/// Lightweight prototype validation: catches obviously malformed SQL before
/// running it. Returns nil when ok, or an error message written in the flavour
/// of the target engine so the editor reads like the server it talks to.
enum SQLValidator {
    /// Statements every engine accepts as a read-only entry point.
    private static let sharedLeadingKeywords: Set<String> = [
        "select", "with", "explain", "show", "values", "table",
    ]

    /// The statements an engine may start with. The MySQL protocol engines
    /// (MySQL and MariaDB) add their own spellings of Postgres' `\d`
    /// (`DESCRIBE` / `DESC`).
    static func allowedLeadingKeywords(for engine: DatabaseEngine) -> Set<String> {
        engine.usesMySQLProtocol
            ? sharedLeadingKeywords.union(["describe", "desc"])
            : sharedLeadingKeywords
    }

    static func validate(_ sql: String, engine: DatabaseEngine = .postgreSQL) -> String? {
        let body = stripComments(sql, engine: engine)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty { return "empty statement" }

        let firstWord = body.prefix { $0.isLetter }.lowercased()
        if !allowedLeadingKeywords(for: engine).contains(firstWord) {
            let token = body.split(whereSeparator: \.isWhitespace).first.map { String($0) } ?? body
            guard engine.usesMySQLProtocol else {
                return "syntax error at or near \"\(token)\"\nLINE 1: \(token) …\n        ^"
            }
            return mySQLSyntaxError("near '\(token)' at line 1", engine: engine)
        }

        var depth = 0
        for character in body {
            if character == "(" { depth += 1 }
            if character == ")" { depth -= 1 }
            if depth < 0 {
                guard engine.usesMySQLProtocol else {
                    return "syntax error at or near \")\"\nHINT: unmatched closing parenthesis."
                }
                return mySQLSyntaxError("near ')' at line 1", engine: engine)
                    + "\nHINT: unmatched closing parenthesis."
            }
        }
        if depth > 0 {
            guard engine.usesMySQLProtocol else {
                return "syntax error at end of input\nHINT: unmatched opening parenthesis."
            }
            return mySQLSyntaxError("at the end of the statement", engine: engine)
                + "\nHINT: unmatched opening parenthesis."
        }

        if body.count(where: { $0 == "'" }) % 2 == 1 {
            guard engine.usesMySQLProtocol else {
                return "unterminated quoted string at or near \"'\""
            }
            return mySQLSyntaxError("", engine: engine) + "\nHINT: unterminated quoted string."
        }

        let lowered = body.lowercased()
        if (firstWord == "select" || firstWord == "with"),
           !containsWord("from", in: lowered),
           !selectsExpressionsOnly(body) {
            guard engine.usesMySQLProtocol else { return "syntax error: missing FROM clause" }
            return mySQLSyntaxError("", engine: engine) + "\nHINT: missing FROM clause."
        }
        return nil
    }

    /// Every engine allows a FROM-less SELECT of bare expressions — `SELECT 1`,
    /// `SELECT 'x'`, `SELECT now()`. Parentheses are already known to be
    /// balanced by this point, so one anywhere in the statement is a good
    /// enough stand-in for "the select list calls a function".
    private static func selectsExpressionsOnly(_ body: String) -> Bool {
        if body.contains("(") { return true }
        // Skip the leading keyword and the space after it to reach the list.
        let selectList = body.drop { $0.isLetter }.drop { $0.isWhitespace }
        guard let first = selectList.first else { return false }
        return first.isNumber || first == "'" || first == "\""
    }

    /// Strips line comments. MySQL and MariaDB also treat `#` as a comment
    /// introducer.
    static func stripComments(_ sql: String, engine: DatabaseEngine = .postgreSQL) -> String {
        let stripped = sql.replacing(/--[^\n]*/, with: "")
        guard engine.usesMySQLProtocol else { return stripped }
        return stripped
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in String(line.prefix { $0 != "#" }) }
            .joined(separator: "\n")
    }

    /// The stock parser complaint shared by MySQL and MariaDB, with `location`
    /// naming where the parser gave up. Each server points at its own manual,
    /// so the engine's display name goes into the message.
    private static func mySQLSyntaxError(_ location: String, engine: DatabaseEngine) -> String {
        let preamble = "You have an error in your SQL syntax; check the manual that "
            + "corresponds to your \(engine.rawValue) server version for the right syntax to use"
        return location.isEmpty ? preamble : "\(preamble) \(location)"
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "_" }.contains { $0 == word[...] }
    }
}
