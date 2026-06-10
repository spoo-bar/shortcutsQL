import SwiftUI
import UIKit

/// The ShortcutsQL SQL syntax palette, converted from the design system's
/// OKLCH tokens to sRGB for each appearance.
extension Color {
    static let synKeyword = dynamic(light: 0xB90D75, dark: 0xFF7BBD)
    static let synString = dynamic(light: 0x1E7729, dark: 0x8FE47D)
    static let synNumber = dynamic(light: 0xA15000, dark: 0xFFBC56)
    static let synFunction = dynamic(light: 0x006DA6, dark: 0x51C7F1)
    static let synComment = dynamic(light: 0x83868C, dark: 0x71757C)
    static let synOperator = dynamic(light: 0x44484E, dark: 0xB5B7BC)
    static let synTable = dynamic(light: 0x00656B, dark: 0x5DCBD1)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
