import Foundation

/// Translations and CEFR levels by lemma, from `dictionary.tsv` written by
/// `tools/build-dictionary.mjs` (WikDict for translations, FLELex for levels).
public struct Glossary: Sendable {
    private let lines: SortedLines

    public init(data: Data) {
        lines = SortedLines(bytes: data)
    }

    public struct Info: Equatable, Sendable {
        /// "A1" … "C2".
        public let level: String?
        public let translation: String?
    }

    public func info(of lemma: String) -> Info? {
        guard let line = lines.line(key: Lexicon.key(lemma)) else { return nil }
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 3 else { return nil }
        return Info(level: fields[1].isEmpty ? nil : fields[1], translation: fields[2].isEmpty ? nil : fields[2])
    }
}

/// The «Справочник» tab: function words by kind, from `reference.json` written by
/// `tools/build-reference.mjs`.
public struct ReferenceBook: Decodable, Sendable {
    public let categories: [ReferenceCategory]

    public static func decode(_ data: Data) throws -> ReferenceBook {
        try JSONDecoder().decode(ReferenceBook.self, from: data)
    }
}

public struct ReferenceCategory: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let words: [ReferenceWord]
    /// Sentences to drill the kind with a gap; only prepositions and conjunctions have them.
    public let gaps: [Gap]?
}

public struct ReferenceWord: Decodable, Hashable, Sendable {
    public let fr: String
    public let m: String?
    public let ipa: String
    public let ru: String
    public let level: String?

    public var word: Word { Word(fr: fr, m: m, ipa: ipa, ru: ru) }
}

/// A sentence with one word taken out.
public struct Gap: Decodable, Equatable, Sendable {
    public let before: String
    public let answer: String
    public let after: String
    public let ru: String
    /// "L5" for lesson 5, "T123" for Tatoeba sentence 123.
    public let src: String

    public init(before: String, answer: String, after: String, ru: String, src: String) {
        self.before = before
        self.answer = answer
        self.after = after
        self.ru = ru
        self.src = src
    }
}

public struct GapQuestion: Equatable, Sendable {
    public let gap: Gap
    /// Lowercase words of the same kind; the answer is one of them.
    public let options: [String]
    public let answer: Int
}

public enum GapFill {
    /// Up to `count` questions, each with the answer and three other words of its kind.
    public static func questions<Generator: RandomNumberGenerator>(
        from category: ReferenceCategory, count: Int, using generator: inout Generator
    ) -> [GapQuestion] {
        let words = category.words.map { $0.fr.lowercased() }
        return (category.gaps ?? []).shuffled(using: &generator).prefix(count).compactMap { gap in
            let right = gap.answer.lowercased()
            let wrong = Array(Set(words.filter { $0 != right })).sorted().shuffled(using: &generator).prefix(3)
            guard wrong.count == 3 else { return nil }
            let options = ([right] + wrong).shuffled(using: &generator)
            return GapQuestion(gap: gap, options: options, answer: options.firstIndex(of: right) ?? 0)
        }
    }
}
