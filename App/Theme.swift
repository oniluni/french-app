import SwiftUI
import UIKit

/// Colours and type of the design. Values come from `prototype/styles.css`; everything not
/// listed here uses the system's own colours, which match the prototype's neutral tokens.
enum Theme {
    /// Underlay of a nasal vowel.
    static let nasal = dynamic(light: 0xF6DFA6, dark: 0xE2B048, darkAlpha: 0.32)
    static let hero = dynamic(light: 0x2141D0, dark: 0x2B47CC)
    static let again = dynamic(light: 0xCF3A3A, dark: 0xFF7070)
    static let hard = dynamic(light: 0xB0660A, dark: 0xF2A446)
    static let good = dynamic(light: 0x1E8650, dark: 0x4CC38A)
    static let accentSoft = Color.accentColor.opacity(0.12)

    /// French study text is set in a serif face, the interface in the system sans.
    static func french(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif)
    }

    /// The system font holds a letter and its combining tilde in one face, so ɛ̃ renders whole.
    static let ipa = Font.system(.footnote)

    private static func dynamic(light: UInt32, dark: UInt32, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: 1)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
