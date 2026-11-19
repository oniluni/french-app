import Foundation

/// Everything the learner creates. Stored as one JSON file, which is also the backup:
/// a re-signed app with another certificate cannot be installed over the old one, so the
/// learner has to be able to carry this file across a reinstall.
public struct UserData: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = UserData.currentVersion
    /// Scheduling state by `Entry.id`.
    public var cards: [String: CardState] = [:]
    public var sets: [StudySet] = []
    public var notes: [Note] = []
    /// Words starred by the learner, in the order they were added.
    public var favorites: [Word] = []
    public var lastLesson: Int?
    /// Grammar workshops by id: the last test result and when to come back.
    public var grammar: [String: GrammarReview] = [:]

    public init() {}

    /// "addedWords" is the name favourites had when they were words added to the cards; backups
    /// made then keep loading.
    private enum CodingKeys: String, CodingKey {
        case version, cards, sets, notes, lastLesson, grammar
        case favorites = "addedWords"
    }

    /// Fields added by later versions are optional in older backups.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        cards = try container.decodeIfPresent([String: CardState].self, forKey: .cards) ?? [:]
        sets = try container.decodeIfPresent([StudySet].self, forKey: .sets) ?? []
        notes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
        favorites = try container.decodeIfPresent([Word].self, forKey: .favorites) ?? []
        lastLesson = try container.decodeIfPresent(Int.self, forKey: .lastLesson)
        grammar = try container.decodeIfPresent([String: GrammarReview].self, forKey: .grammar) ?? [:]
    }

    public enum Failure: Error, Equatable {
        case notABackup
        case newerVersion(Int)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> UserData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded: UserData
        do {
            decoded = try decoder.decode(UserData.self, from: data)
        } catch is DecodingError {
            throw Failure.notABackup
        }
        guard decoded.version <= currentVersion else { throw Failure.newerVersion(decoded.version) }
        return decoded
    }
}

/// A saved range of lessons. Its progress is derived from the card states.
public struct StudySet: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var first: Int
    public var last: Int

    public init(first: Int, last: Int) {
        self.first = min(first, last)
        self.last = max(first, last)
    }

    public var lessons: ClosedRange<Int> { first...last }
}

/// A grammar workshop the learner has tested, and when to return to it.
public struct GrammarReview: Codable, Equatable, Sendable {
    public var state: CardState
    public var correct: Int
    public var total: Int
    public var attempts: Int
    public var lastStudied: Date
    /// Prompts of the questions answered wrong last time.
    public var lastMistakes: [String]

    public init(state: CardState, correct: Int, total: Int, attempts: Int = 1,
                lastStudied: Date, lastMistakes: [String] = []) {
        self.state = state
        self.correct = correct
        self.total = total
        self.attempts = attempts
        self.lastStudied = lastStudied
        self.lastMistakes = lastMistakes
    }

    /// What the test result means for the schedule: perfect is easy, most right is good,
    /// a pass is hard, and a poor result sends the topic back to the start.
    public static func grade(correct: Int, total: Int) -> Grade {
        guard total > 0 else { return .again }
        let share = Double(correct) / Double(total)
        if share >= 0.99 { return .easy }
        if share >= 0.8 { return .good }
        if share >= 0.6 { return .hard }
        return .again
    }
}

public struct Note: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    /// What the note is attached to: `rule-5-r3` for a rule. Older backups also hold `text-5` (a
    /// lesson text) and `rule-5-3` (a rule of the vault's earlier layout); the app no longer shows them.
    public var target: String
    public var text: String
    /// The fragment the note is about, when it was written from a selection.
    public var fragment: Fragment?
    public var created: Date

    public init(target: String, text: String, fragment: Fragment? = nil, created: Date) {
        self.target = target
        self.text = text
        self.fragment = fragment
        self.created = created
    }

    /// Words `first...last` of one sentence of a lesson text; only older backups have it.
    public struct Fragment: Codable, Equatable, Sendable {
        public var quote: String
        public var section: Int
        public var item: Int
        public var first: Int
        public var last: Int

        public init(quote: String, section: Int, item: Int, first: Int, last: Int) {
            self.quote = quote
            self.section = section
            self.item = item
            self.first = first
            self.last = last
        }
    }
}
