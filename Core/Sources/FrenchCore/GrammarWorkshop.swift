import Foundation

/// A short grammar lesson: theory to read, then a test on it. Bundled in `grammar.json`.
public struct GrammarWorkshop: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    /// An SF Symbol name.
    public let icon: String
    /// The level the lesson is written for: «A1», «A2–B1»…
    public let level: String
    public let blocks: [Block]
    public let questions: [GrammarQuestion]

    public init(id: String, title: String, subtitle: String, icon: String, level: String,
                blocks: [Block], questions: [GrammarQuestion]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.level = level
        self.blocks = blocks
        self.questions = questions
    }
}

/// One multiple-choice question of a grammar test.
public struct GrammarQuestion: Decodable, Hashable, Sendable {
    public let prompt: String
    /// The Russian translation of the phrase, when there is one.
    public let translation: String?
    public let options: [String]
    public let answer: Int
    /// Why the answer is right; shown after the pick.
    public let explanation: String

    public init(prompt: String, translation: String? = nil, options: [String], answer: Int, explanation: String) {
        self.prompt = prompt
        self.translation = translation
        self.options = options
        self.answer = answer
        self.explanation = explanation
    }
}

/// The grammar track bundled with the app: `grammar.json`, written by `tools/build-grammar.mjs`.
public struct GrammarWorkshops: Decodable, Sendable {
    public let workshops: [GrammarWorkshop]

    public init(workshops: [GrammarWorkshop] = []) {
        self.workshops = workshops
    }

    public static func decode(_ data: Data) throws -> GrammarWorkshops {
        try JSONDecoder().decode(GrammarWorkshops.self, from: data)
    }

    public func workshop(_ id: String) -> GrammarWorkshop? {
        workshops.first { $0.id == id }
    }
}
