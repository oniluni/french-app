import Foundation

/// The lessons bundled with the app: `content.json`, written by `tools/import-vault.mjs`.
public struct Content: Decodable, Sendable {
    public let lessons: [Lesson]
    /// Reading rules that words of a text link to, by index (`Token.rule`).
    public let readingRules: [ReadingRule]
    /// Remarks on the conjugation of a verb, by lowercased infinitive.
    public let verbNotes: [String: String]

    public init(lessons: [Lesson], readingRules: [ReadingRule] = [], verbNotes: [String: String] = [:]) {
        self.lessons = lessons
        self.readingRules = readingRules
        self.verbNotes = verbNotes
    }

    public static func decode(_ data: Data) throws -> Content {
        try JSONDecoder().decode(Content.self, from: data)
    }

    /// Vocabulary of lessons `first...last`, in lesson order.
    public func entries(in lessons: ClosedRange<Int>) -> [Entry] {
        self.lessons.filter { lessons.contains($0.id) }.flatMap(\.entries)
    }

    public var entries: [Entry] { lessons.flatMap(\.entries) }

    public func rule(id: String) -> Rule? {
        lessons.lazy.flatMap(\.rules).first { $0.id == id }
    }

    private static let articles = ["le ", "la ", "les ", "un ", "une ", "l'", "l’"]

    /// A word or phrase compared without case, surrounding punctuation or a leading article:
    /// "La famille." and "famille" are the same entry.
    public static func bare(_ text: String) -> String {
        var word = text.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        if let article = articles.first(where: { word.hasPrefix($0) }) { word.removeFirst(article.count) }
        return word
    }

    /// The vocabulary entry for a word of a text.
    public func entry(for text: String) -> Entry? {
        let wanted = Content.bare(text)
        guard !wanted.isEmpty else { return nil }
        return entries.first { Content.bare($0.word.fr) == wanted }
    }

    /// Cards for words from outside a lesson (favourites, the reference): a word the lessons teach
    /// keeps its lesson card and progress,
    /// any other word is a card of its own (lesson 0).
    public func entries(forWords words: [Word]) -> [Entry] {
        words.map { entry(for: $0.fr) ?? Entry(lesson: 0, word: $0) }
    }

    /// The translation of a form, as the vocabulary gives it.
    ///
    /// The form itself when the lessons teach it ("je vais" → «я иду»; an entry "a, b" counts as
    /// both), otherwise the lemma's translation, marked as such. Russian verbs are not conjugated
    /// by rule: aspect makes that unreliable.
    public func translation(ofForm form: String, lemma: String) -> Translation? {
        let wanted = Content.bare(form)
        for entry in entries where entry.word.fr.split(separator: ",").contains(where: { Content.bare(String($0)) == wanted }) {
            return .form(entry.word.ru)
        }
        return entry(for: lemma).map { .lemma($0.word.ru) }
    }

    public enum Translation: Equatable, Sendable {
        /// Translates exactly this form: «я иду».
        case form(String)
        /// Translates the dictionary form only: «идти, ехать».
        case lemma(String)
    }
}

public struct Lesson: Decodable, Identifiable, Sendable {
    public let id: Int
    public let topic: String
    public let words: [Word]
    public let sections: [TextSection]
    public let rules: [Rule]

    public var entries: [Entry] { words.map { Entry(lesson: id, word: $0) } }
}

public struct Word: Codable, Hashable, Sendable {
    /// As written, without pronunciation marks.
    public let fr: String
    /// With pronunciation marks. Absent when the entry could not be aligned with its sound.
    public let m: String?
    public let ipa: String
    public let ru: String
    public let pos: String

    public init(fr: String, m: String? = nil, ipa: String, ru: String, pos: String = "") {
        self.fr = fr
        self.m = m
        self.ipa = ipa
        self.ru = ru
        self.pos = pos
    }

}

/// A word as a card: the same spelling taught in two lessons is two cards.
public struct Entry: Identifiable, Hashable, Sendable {
    /// 0 for a word the learner added from a text or the reader.
    public let lesson: Int
    public let word: Word

    public init(lesson: Int, word: Word) {
        self.lesson = lesson
        self.word = word
    }

    public var id: String { "\(lesson):\(word.fr)" }
}

public struct TextSection: Decodable, Sendable {
    public let title: String
    public let items: [SectionItem]
}

public enum SectionItem: Decodable, Sendable {
    case sentence(Sentence)
    case block(Block)

    private enum CodingKeys: String, CodingKey { case sentence, block }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let sentence = try container.decodeIfPresent(Sentence.self, forKey: .sentence) {
            self = .sentence(sentence)
        } else {
            self = .block(try container.decode(Block.self, forKey: .block))
        }
    }
}

public struct Sentence: Decodable, Sendable {
    public let ru: String
    /// Who says the line of a dialogue.
    public let speaker: String?
    /// Transcription of the whole sentence, kept only when it could not be split by word.
    public let ipa: String?
    public let tokens: [Token]
    public let note: [Block]?
}

public struct Token: Decodable, Hashable, Sendable {
    private let m: String?
    private let t: String?
    public let ipa: String?
    /// Liaison consonant heard before this word: "z", "t", "n".
    public let link: String?
    private let tie: Bool?
    /// Translation of the word, from the vocabulary of the lessons.
    public let gloss: String?
    /// Index into `Content.readingRules`.
    public let rule: Int?

    private enum CodingKeys: String, CodingKey { case m, t, ipa, link, tie, gloss = "g", rule = "r" }

    public init(marked: String, ipa: String? = nil, link: String? = nil, isTied: Bool = false, gloss: String? = nil, rule: Int? = nil) {
        m = marked
        t = nil
        self.ipa = ipa
        self.link = link
        tie = isTied
        self.gloss = gloss
        self.rule = rule
    }

    /// With pronunciation marks. Nil for a word that could not be aligned: its text may hold
    /// brackets of its own ("(te)"), which must not be read as marks.
    public var marked: String? { m }
    public var plain: String { m.map(Markup.plain) ?? t ?? "" }
    /// Said together with the previous word: a liaison or a carried-over consonant.
    public var isTied: Bool { tie ?? false }
}

public struct Rule: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    /// «Произношение», «Чтение», «Грамматика» or «Примечания».
    public let kind: String
    public let title: String
    public let summary: String
    public let blocks: [Block]

    public var lesson: Int { Int(id.prefix { $0 != "-" }) ?? 0 }
}

public struct ReadingRule: Decodable, Hashable, Sendable {
    /// Id of the «Правила чтения» page that explains it.
    public let rule: String
    public let label: String
    public let pattern: ReadingPattern
}

/// What a reading rule says, as written by `tools/import-vault.mjs` (`patternFor`).
public enum ReadingPattern: Decodable, Hashable, Sendable {
    /// "un ami": n heard after a nasal vowel.
    case nasalLink
    /// A silent final consonant heard before the next word.
    case liaison
    case nasal
    /// Letters read as a sound: "ch" as [ʃ].
    case sound(letters: String, sound: String)
    /// A silent h.
    case h
    /// A final letter that is not pronounced.
    case silentFinal(String)
    /// A final letter that is pronounced.
    case heardFinal(String)
    /// A pronounced final consonant carried over to the next word.
    case tie

    /// When several rules explain a word, the lowest rank is the one shown.
    public var rank: Int {
        switch self {
        case .nasalLink: 0
        case .liaison: 1
        case .nasal: 2
        case .sound, .h: 3
        case .silentFinal: 4
        case .heardFinal: 5
        case .tie: 6
        }
    }

    private enum CodingKeys: String, CodingKey { case kind, letters, sound, letter }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "nasal-link": self = .nasalLink
        case "liaison": self = .liaison
        case "nasal": self = .nasal
        case "sound": self = .sound(letters: try container.decode(String.self, forKey: .letters), sound: try container.decode(String.self, forKey: .sound))
        case "h": self = .h
        case "silent-final": self = .silentFinal(try container.decode(String.self, forKey: .letter))
        case "heard-final": self = .heardFinal(try container.decode(String.self, forKey: .letter))
        case "tie": self = .tie
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown reading rule kind \"\(kind)\"")
        }
    }
}

/// A piece of formatted lesson text. Inline markup inside `md` strings is Markdown.
public indirect enum Block: Decodable, Hashable, Sendable {
    case heading(level: Int, md: String)
    case paragraph(md: String)
    case list(ordered: Bool, items: [ListItem])
    case table(head: [String], rows: [[String]])
    case callout(kind: String, title: String, blocks: [Block])
    case divider

    private enum CodingKeys: String, CodingKey { case t, level, md, ordered, items, head, rows, kind, title, blocks }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .t)
        switch type {
        case "h":
            self = .heading(level: try container.decode(Int.self, forKey: .level), md: try container.decode(String.self, forKey: .md))
        case "p":
            self = .paragraph(md: try container.decode(String.self, forKey: .md))
        case "list":
            self = .list(ordered: try container.decode(Bool.self, forKey: .ordered), items: try container.decode([ListItem].self, forKey: .items))
        case "table":
            self = .table(head: try container.decode([String].self, forKey: .head), rows: try container.decode([[String]].self, forKey: .rows))
        case "callout":
            self = .callout(
                kind: try container.decode(String.self, forKey: .kind),
                title: try container.decode(String.self, forKey: .title),
                blocks: try container.decode([Block].self, forKey: .blocks))
        case "hr":
            self = .divider
        default:
            throw DecodingError.dataCorruptedError(forKey: .t, in: container, debugDescription: "Unknown block type \"\(type)\"")
        }
    }
}

public struct ListItem: Decodable, Hashable, Sendable {
    public let md: String
    public let blocks: [Block]
}
