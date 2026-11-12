import Foundation

public enum Grade: Int, CaseIterable, Codable, Sendable {
    case again, hard, good, easy
}

/// Scheduling data of one card. A card without a state is new.
public struct CardState: Codable, Equatable, Sendable {
    /// Days until the next review. Below one day the card is still being learned.
    public var interval: Double
    /// Growth factor of the interval, as in SM-2.
    public var ease: Double
    public var due: Date
    public var lapses: Int

    public init(interval: Double, ease: Double, due: Date, lapses: Int = 0) {
        self.interval = interval
        self.ease = ease
        self.due = due
        self.lapses = lapses
    }
}

public enum CardStatus: Sendable {
    case new, learning, due, known
}

/// Spaced repetition: SM-2 with four grades, as in classic Anki.
public enum Scheduler {
    static let day: TimeInterval = 86_400
    static let startingEase = 2.5
    static let minimumEase = 1.3
    static let againStep: TimeInterval = 60
    static let hardStep: TimeInterval = 600
    static let graduatingInterval = 1.0
    static let easyInterval = 4.0
    /// A card reviewed at intervals this long counts as known.
    static let knownInterval = 21.0

    public static func next(_ state: CardState?, grade: Grade, now: Date) -> CardState {
        var card = state ?? CardState(interval: 0, ease: startingEase, due: now)
        let wasLearning = card.interval < 1

        switch (grade, wasLearning) {
        case (.again, _):
            if !wasLearning {
                card.lapses += 1
                card.ease = max(minimumEase, card.ease - 0.2)
            }
            card.interval = 0
            card.due = now.addingTimeInterval(againStep)
            return card
        case (.hard, true):
            card.interval = 0
            card.due = now.addingTimeInterval(hardStep)
            return card
        case (.good, true):
            card.interval = graduatingInterval
        case (.easy, true):
            card.interval = easyInterval
        case (.hard, false):
            card.ease = max(minimumEase, card.ease - 0.15)
            card.interval *= 1.2
        case (.good, false):
            card.interval *= card.ease
        case (.easy, false):
            card.ease += 0.15
            card.interval *= card.ease * 1.3
        }
        card.due = now.addingTimeInterval(card.interval * day)
        return card
    }

    /// Time until the card comes back if it gets this grade now. Shown under the grade buttons.
    public static func delay(_ state: CardState?, grade: Grade, now: Date) -> TimeInterval {
        next(state, grade: grade, now: now).due.timeIntervalSince(now)
    }

    public static func status(_ state: CardState?, now: Date) -> CardStatus {
        guard let state else { return .new }
        if state.due <= now { return .due }
        if state.interval >= knownInterval { return .known }
        return .learning
    }
}

/// Which cards a session shows.
public enum Session {
    public static let size = 10

    /// At most `limit` cards: due first, then new, then the ones being learned, then the known.
    public static func queue(from entries: [Entry], cards: [String: CardState], now: Date, limit: Int = size) -> [Entry] {
        let order: [CardStatus] = [.due, .new, .learning, .known]
        let ranked = order.flatMap { status in entries.filter { Scheduler.status(cards[$0.id], now: now) == status } }
        return Array(ranked.prefix(limit))
    }

    public static func due(in entries: [Entry], cards: [String: CardState], now: Date) -> [Entry] {
        entries.filter { Scheduler.status(cards[$0.id], now: now) == .due }
    }

    /// Share of the entries the learner has started, 0...1.
    public static func progress(of entries: [Entry], cards: [String: CardState]) -> Double {
        entries.isEmpty ? 0 : Double(entries.filter { cards[$0.id] != nil }.count) / Double(entries.count)
    }
}
