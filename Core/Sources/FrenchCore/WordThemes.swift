import Foundation

/// The themes of the word-card practice: `themes.json`, written by `tools/build-themes.mjs`.
///
/// A theme is a hand-written list of words on one topic. The words may come from the lessons or
/// from the dictionary; `Content.entries(forWords:)` gives lesson words their lesson card and
/// every other word a card of its own.
public struct WordThemes: Decodable, Sendable {
    public let themes: [WordTheme]

    public init(themes: [WordTheme] = []) {
        self.themes = themes
    }

    public static func decode(_ data: Data) throws -> WordThemes {
        try JSONDecoder().decode(WordThemes.self, from: data)
    }

    public func theme(id: String) -> WordTheme? {
        themes.first { $0.id == id }
    }
}

public struct WordTheme: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// A SF Symbol name, e.g. `figure.walk` or `mountain.2.fill`.
    public let icon: String
    public let words: [Word]

    public init(id: String, title: String, icon: String, words: [Word]) {
        self.id = id
        self.title = title
        self.icon = icon
        self.words = words
    }
}
