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

    public init() {}

    /// "addedWords" is the name favourites had when they were words added to the cards; backups
    /// made then keep loading.
    private enum CodingKeys: String, CodingKey {
        case version, cards, sets, notes, lastLesson
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

public struct Note: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    /// What the note is attached to: `text-5` for a lesson text, `rule-5-3` for a rule.
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

    /// Words `first...last` of one sentence of a lesson text.
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
