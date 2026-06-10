import Runestone
import UIKit

/// Runestone theme mapping tree-sitter SQL capture names to the brand
/// syntax palette. Surfaces are transparent so the editor blends into the
/// surrounding inset background.
final class SQLTheme: Runestone.Theme {
    let font: UIFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    let textColor: UIColor = .label

    let gutterBackgroundColor: UIColor = .clear
    let gutterHairlineColor: UIColor = .clear
    let lineNumberColor: UIColor = .tertiaryLabel
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 11, weight: .regular)

    let selectedLineBackgroundColor: UIColor = .clear
    let selectedLinesLineNumberColor: UIColor = .secondaryLabel
    let selectedLinesGutterBackgroundColor: UIColor = .clear

    let invisibleCharactersColor: UIColor = .quaternaryLabel

    let pageGuideHairlineColor: UIColor = .clear
    let pageGuideBackgroundColor: UIColor = .clear

    let markedTextBackgroundColor: UIColor = .systemFill

    func textColor(for highlightName: String) -> UIColor? {
        switch rootCapture(of: highlightName) {
        case "keyword": SQLPalette.keyword
        case "string": SQLPalette.string
        case "number", "constant": SQLPalette.number
        case "function": SQLPalette.function
        case "comment": SQLPalette.comment
        case "operator", "punctuation": SQLPalette.operator
        case "type", "property", "variable", "attribute": SQLPalette.table
        default: nil
        }
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        rootCapture(of: highlightName) == "comment" ? .italic : []
    }

    /// tree-sitter capture names are dotted (e.g. `punctuation.delimiter`);
    /// match on the root segment.
    private func rootCapture(of highlightName: String) -> Substring {
        highlightName.prefix { $0 != "." }
    }
}
