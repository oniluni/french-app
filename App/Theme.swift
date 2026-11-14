import SwiftUI
import UIKit

/// Colours and type of the design. Values come from `design/app.css`; the app is dark only.
enum Theme {
    // MARK: Surfaces and lines

    static let bg = Color(hex: 0x0A0A0A)
    static let s1 = Color(hex: 0x111111)
    static let s2 = Color(hex: 0x171717)
    /// Fill: buttons, chips, progress tracks. Tertiary text fails contrast on it.
    static let s3 = Color(hex: 0x1F1F1F)
    /// The chosen segment of a picker in content.
    static let s4 = Color(hex: 0x2E2E2E)
    static let line = Color(hex: 0x262626)
    static let line2 = Color(hex: 0x2E2E2E)

    // MARK: Text

    static let t1 = Color(hex: 0xFAFAFA)
    static let t2 = Color(hex: 0xA1A1A1)
    static let t3 = Color(hex: 0x858585)
    /// Text of a disabled button.
    static let off = Color(hex: 0x6E6E6E)

    // MARK: Accent: interactive elements, selection, liaison

    static let acc = Color(hex: 0x8FA2FF)
    static let accSoft = acc.opacity(0.14)
    static let accLine = acc.opacity(0.5)
    /// Text on the accent.
    static let ink = Color(hex: 0x0A0A0A)

    /// Underlay of a nasal vowel. Ochre appears nowhere else.
    static let nasal = Color(hex: 0xE2B048).opacity(0.32)

    // MARK: Grades, verdicts, card status: never the only sign, always with a word or an icon

    static let red = Color(hex: 0xFF7070)
    static let redSoft = red.opacity(0.14)
    static let amber = Color(hex: 0xF2A446)
    static let amberSoft = amber.opacity(0.14)
    static let green = Color(hex: 0x4CC38A)
    static let greenSoft = green.opacity(0.14)

    // MARK: Type

    enum Weight {
        case regular, medium, semibold, bold
    }

    /// Geist, for the interface and for French alike: French differs by size and marks, not by face.
    static func sans(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let face = switch weight {
        case .regular: "Geist-Regular"
        case .medium: "Geist-Medium"
        case .semibold: "Geist-SemiBold"
        case .bold: "Geist-Bold"
        }
        return .custom(face, size: size, relativeTo: style)
    }

    /// Geist Mono: counters, lesson numbers, intervals, levels. Digits keep one width.
    static func mono(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight == .regular ? "GeistMono-Regular" : "GeistMono-Medium", size: size, relativeTo: style)
    }

    static let largeTitle = sans(32, .semibold, relativeTo: .largeTitle)
    static let title1 = sans(26, .semibold, relativeTo: .title)
    static let title2 = sans(22, .semibold, relativeTo: .title2)
    static let title3 = sans(19, .semibold, relativeTo: .title3)
    static let headline = sans(16, .semibold, relativeTo: .headline)
    static let body = sans(16)
    static let bodyMedium = sans(16, .medium)
    static let callout = sans(15, relativeTo: .callout)
    static let subhead = sans(14, relativeTo: .subheadline)
    static let footnote = sans(13, relativeTo: .footnote)
    static let caption1 = sans(12, relativeTo: .caption)
    static let caption2 = sans(11, relativeTo: .caption2)

    /// French in a list row: fr-row 19/24 · 500.
    static let frRow = (size: CGFloat(19), weight: Weight.medium)
    /// French on a card or a word's header: fr-card 40/44 · 600.
    static let frCard = (size: CGFloat(40), weight: Weight.semibold)

    /// IPA is set in the system face: it holds a letter and its combining tilde in one font, so ɛ̃
    /// renders whole; web-style subsets of Geist would split them.
    static func ipa(_ size: CGFloat = 13) -> Font {
        .system(size: size)
    }

    /// Fonts of the navigation bars, which SwiftUI cannot set: Geist for the titles.
    @MainActor
    static func applyToNavigationBars() {
        let bar = UINavigationBar.appearance()
        if let large = UIFont(name: "Geist-SemiBold", size: 32) {
            bar.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large), .kern: -1.1]
        }
        if let inline = UIFont(name: "Geist-Medium", size: 16) {
            bar.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline)]
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
