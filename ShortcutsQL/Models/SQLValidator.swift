import Foundation

/// Lightweight prototype validation: catches obviously malformed SQL before
/// "running" it. Returns nil when ok, or a Postgres-style error message.
enum SQLValidator {
    private static let allowedLeadingKeywords: Set<String> = [
        "select", "with", "explain", "show", "values",
    ]

    static func validate(_ sql: String) -> String? {
        let body = stripComments(sql).trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty { return "empty statement" }

        let firstWord = body.prefix { $0.isLetter }.lowercased()
        if !allowedLeadingKeywords.contains(firstWord) {
            let token = body.split(whereSeparator: \.isWhitespace).first.map { String($0) } ?? body
            return "syntax error at or near \"\(token)\"\nLINE 1: \(token) …\n        ^"
        }

        var depth = 0
        for character in body {
            if character == "(" { depth += 1 }
            if character == ")" { depth -= 1 }
            if depth < 0 {
                return "syntax error at or near \")\"\nHINT: unmatched closing parenthesis."
            }
        }
        if depth > 0 { return "syntax error at end of input\nHINT: unmatched opening parenthesis." }

        if body.count(where: { $0 == "'" }) % 2 == 1 {
            return "unterminated quoted string at or near \"'\""
        }

        let lowered = body.lowercased()
        if (firstWord == "select" || firstWord == "with"),
           !containsWord("from", in: lowered),
           lowered.firstMatch(of: /select\s+\d/) == nil {
            return "syntax error: missing FROM clause"
        }
        return nil
    }

    static func stripComments(_ sql: String) -> String {
        sql.replacing(/--[^\n]*/, with: "")
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "_" }.contains { $0 == word[...] }
    }
}
