import SwiftUI
import UIKit

/// The ShortcutsQL SQL syntax palette, converted from the design system's
/// OKLCH tokens to sRGB for each appearance. Exposed as both `UIColor`
/// (for Runestone's `Theme`) and `Color` (for SwiftUI), from one source.
enum SQLPalette {
    static let keyword = dynamic(light: 0xB90D75, dark: 0xFF7BBD)
    static let string = dynamic(light: 0x1E7729, dark: 0x8FE47D)
    static let number = dynamic(light: 0xA15000, dark: 0xFFBC56)
    static let function = dynamic(light: 0x006DA6, dark: 0x51C7F1)
    static let comment = dynamic(light: 0x83868C, dark: 0x71757C)
    static let `operator` = dynamic(light: 0x44484E, dark: 0xB5B7BC)
    static let table = dynamic(light: 0x00656B, dark: 0x5DCBD1)

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        }
    }
}

extension Color {
    static let synKeyword = Color(uiColor: SQLPalette.keyword)
    static let synString = Color(uiColor: SQLPalette.string)
    static let synNumber = Color(uiColor: SQLPalette.number)
    static let synFunction = Color(uiColor: SQLPalette.function)
    static let synComment = Color(uiColor: SQLPalette.comment)
    static let synOperator = Color(uiColor: SQLPalette.operator)
    static let synTable = Color(uiColor: SQLPalette.table)
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
