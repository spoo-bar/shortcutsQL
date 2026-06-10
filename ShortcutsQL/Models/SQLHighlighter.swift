import SwiftUI

enum SQLTokenKind: Equatable {
    case keyword
    case string
    case number
    case function
    case table
    case comment
    case operatorSymbol
    case plain
}

struct SQLToken: Equatable {
    let text: String
    let kind: SQLTokenKind
}

/// Tokenizes SQL into the design system's syntax classes and renders it as
/// an `AttributedString` using the brand's SQL palette.
enum SQLHighlighter {
    static let keywords: Set<String> = Set(
        ("select from where and or not in is null as on join left right inner outer full cross group by order " +
         "having limit offset distinct insert into values update set delete create table alter drop union all " +
         "asc desc between like ilike case when then else end with returning over partition using filter interval")
            .split(separator: " ").map(String.init)
    )

    private static let operatorCharacters = Set("(),;.*=<>!+-/%|")

    static func highlighted(_ sql: String) -> AttributedString {
        var output = AttributedString()
        for token in tokenize(sql) {
            var piece = AttributedString(token.text)
            if let color = color(for: token.kind) {
                piece.foregroundColor = color
            }
            if token.kind == .comment {
                piece.inlinePresentationIntent = .emphasized
            }
            output += piece
        }
        return output
    }

    static func tokenize(_ sql: String) -> [SQLToken] {
        var tokens: [SQLToken] = []
        let lines = sql.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() {
            if index > 0 { tokens.append(SQLToken(text: "\n", kind: .plain)) }
            tokens.append(contentsOf: tokenize(line: String(line)))
        }
        return tokens
    }

    static func tokenize(line: String) -> [SQLToken] {
        var tokens: [SQLToken] = []
        let characters = Array(line)
        var i = 0

        func take(while predicate: (Character) -> Bool) -> String {
            let start = i
            while i < characters.count, predicate(characters[i]) { i += 1 }
            return String(characters[start..<i])
        }

        while i < characters.count {
            let character = characters[i]

            if character == "-", i + 1 < characters.count, characters[i + 1] == "-" {
                tokens.append(SQLToken(text: String(characters[i...]), kind: .comment))
                break
            }

            if character == "'" {
                let start = i
                i += 1
                while i < characters.count {
                    if characters[i] == "'" {
                        if i + 1 < characters.count, characters[i + 1] == "'" {
                            i += 2 // escaped '' inside the literal
                            continue
                        }
                        i += 1
                        break
                    }
                    i += 1
                }
                tokens.append(SQLToken(text: String(characters[start..<i]), kind: .string))
                continue
            }

            if character.isNumber {
                var text = take(while: \.isNumber)
                if i < characters.count, characters[i] == ".",
                   i + 1 < characters.count, characters[i + 1].isNumber {
                    i += 1
                    text += "." + take(while: \.isNumber)
                }
                tokens.append(SQLToken(text: text, kind: .number))
                continue
            }

            if character.isLetter || character == "_" {
                let start = i
                let text = take(while: { $0.isLetter || $0.isNumber || $0 == "_" })
                var j = i
                while j < characters.count, characters[j] == " " { j += 1 }
                let kind: SQLTokenKind
                if keywords.contains(text.lowercased()) {
                    kind = .keyword
                } else if j < characters.count, characters[j] == "(" {
                    kind = .function
                } else if (start > 0 && characters[start - 1] == ".")
                    || (i < characters.count && characters[i] == ".") {
                    kind = .table
                } else {
                    kind = .plain
                }
                tokens.append(SQLToken(text: text, kind: kind))
                continue
            }

            if character.isWhitespace {
                tokens.append(SQLToken(text: take(while: \.isWhitespace), kind: .plain))
                continue
            }

            if operatorCharacters.contains(character) {
                tokens.append(SQLToken(text: take(while: { operatorCharacters.contains($0) }), kind: .operatorSymbol))
                continue
            }

            tokens.append(SQLToken(text: String(character), kind: .plain))
            i += 1
        }
        return tokens
    }

    private static func color(for kind: SQLTokenKind) -> Color? {
        switch kind {
        case .keyword: .synKeyword
        case .string: .synString
        case .number: .synNumber
        case .function: .synFunction
        case .table: .synTable
        case .comment: .synComment
        case .operatorSymbol: .synOperator
        case .plain: nil
        }
    }
}
