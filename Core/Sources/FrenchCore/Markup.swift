/// One run of a pronunciation-marked French string.
public struct MarkedPart: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case plain
        /// `(x)`: letters that are not pronounced.
        case silent
        /// `[x]`: a nasal vowel.
        case nasal
        /// `{x}`: a consonant heard only because of a liaison.
        case link
        /// `‿`: a liaison between two words. Its text is empty.
        case arc
    }

    public let text: String
    public let kind: Kind

    public init(_ text: String, _ kind: Kind = .plain) {
        self.text = text
        self.kind = kind
    }
}

/// The pronunciation markup shared by lesson texts, cards, rules and the reader.
public enum Markup {
    private static let closers: [Character: (Character, MarkedPart.Kind)] = [
        "(": (")", .silent), "[": ("]", .nasal), "{": ("}", .link),
    ]

    /// `enf[an](t)` → plain "enf", nasal "an", silent "t".
    ///
    /// Lenient on purpose: an unclosed bracket is kept as plain text. Marked strings are
    /// generated and validated by `tools/`, so a view never has to handle a parse error.
    public static func parse(_ source: String) -> [MarkedPart] {
        var parts: [MarkedPart] = []
        var plain = ""
        var rest = Substring(source)
        while let char = rest.first {
            rest = rest.dropFirst()
            if char == "‿" {
                if !plain.isEmpty { parts.append(MarkedPart(plain)) }
                plain = ""
                parts.append(MarkedPart("", .arc))
            } else if let (closer, kind) = closers[char], let end = rest.firstIndex(of: closer) {
                if !plain.isEmpty { parts.append(MarkedPart(plain)) }
                plain = ""
                parts.append(MarkedPart(String(rest[..<end]), kind))
                rest = rest[rest.index(after: end)...]
            } else {
                plain.append(char)
            }
        }
        if !plain.isEmpty { parts.append(MarkedPart(plain)) }
        return parts
    }

    /// The inverse of `parse`.
    public static func string(from parts: [MarkedPart]) -> String {
        parts.map { part in
            switch part.kind {
            case .plain: part.text
            case .silent: "(\(part.text))"
            case .nasal: "[\(part.text)]"
            case .link: "{\(part.text)}"
            case .arc: "‿"
            }
        }.joined()
    }

    /// The string without marks, as it is spelled and spoken. A liaison becomes a word gap.
    public static func plain(_ source: String) -> String {
        parse(source).map { $0.kind == .arc ? " " : $0.text }.joined()
    }

    /// Letters of one kind: the silent ones of `peti(t) déjeune(r)` are "t" and "r".
    public static func letters(of kind: MarkedPart.Kind, in source: String) -> [String] {
        parse(source).filter { $0.kind == kind }.map(\.text)
    }
}
