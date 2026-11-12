import XCTest
@testable import FrenchCore

final class SchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func entry(_ fr: String, lesson: Int = 1) -> Entry {
        Entry(lesson: lesson, word: Word(fr: fr, ipa: "", ru: ""))
    }

    func testNewCardStepsThroughLearning() {
        XCTAssertEqual(Scheduler.delay(nil, grade: .again, now: now), 60)
        XCTAssertEqual(Scheduler.delay(nil, grade: .hard, now: now), 600)
        XCTAssertEqual(Scheduler.delay(nil, grade: .good, now: now), 86_400)
        XCTAssertEqual(Scheduler.delay(nil, grade: .easy, now: now), 4 * 86_400)
        XCTAssertEqual(Scheduler.next(nil, grade: .hard, now: now).interval, 0)
    }

    func testReviewGrowsByEase() {
        let card = CardState(interval: 10, ease: 2.5, due: now)
        XCTAssertEqual(Scheduler.next(card, grade: .good, now: now).interval, 25)
        XCTAssertEqual(Scheduler.next(card, grade: .hard, now: now), CardState(interval: 12, ease: 2.35, due: now.addingTimeInterval(12 * 86_400)))
        let easy = Scheduler.next(card, grade: .easy, now: now)
        XCTAssertEqual(easy.ease, 2.65, accuracy: 1e-9)
        XCTAssertEqual(easy.interval, 10 * 2.65 * 1.3, accuracy: 1e-9)
    }

    func testForgettingSendsTheCardBackAndLowersEase() {
        let lapsed = Scheduler.next(CardState(interval: 30, ease: 1.4, due: now), grade: .again, now: now)
        XCTAssertEqual(lapsed, CardState(interval: 0, ease: 1.3, due: now.addingTimeInterval(60), lapses: 1))
        // Failing a card that is still being learned is not a lapse.
        XCTAssertEqual(Scheduler.next(lapsed, grade: .again, now: now).lapses, 1)
    }

    func testStatus() {
        XCTAssertEqual(Scheduler.status(nil, now: now), .new)
        XCTAssertEqual(Scheduler.status(CardState(interval: 3, ease: 2.5, due: now.addingTimeInterval(1)), now: now), .learning)
        XCTAssertEqual(Scheduler.status(CardState(interval: 3, ease: 2.5, due: now), now: now), .due)
        XCTAssertEqual(Scheduler.status(CardState(interval: 21, ease: 2.5, due: now.addingTimeInterval(1)), now: now), .known)
    }

    func testQueueOrderAndLimit() {
        let later = now.addingTimeInterval(1000)
        let entries = ["known", "learning", "new", "due"].map { entry($0) }
        let cards = [
            "1:known": CardState(interval: 30, ease: 2.5, due: later),
            "1:learning": CardState(interval: 2, ease: 2.5, due: later),
            "1:due": CardState(interval: 2, ease: 2.5, due: now),
        ]
        XCTAssertEqual(Session.queue(from: entries, cards: cards, now: now).map(\.word.fr), ["due", "new", "learning", "known"])
        XCTAssertEqual(Session.queue(from: entries, cards: cards, now: now, limit: 2).map(\.word.fr), ["due", "new"])
        XCTAssertEqual(Session.due(in: entries, cards: cards, now: now).map(\.word.fr), ["due"])
        XCTAssertEqual(Session.progress(of: entries, cards: cards), 0.75)
        XCTAssertEqual(Session.progress(of: [], cards: cards), 0)
    }

    func testSameSpellingInTwoLessonsIsTwoCards() {
        XCTAssertNotEqual(entry("ce", lesson: 2).id, entry("ce", lesson: 5).id)
    }
}

final class UserDataTests: XCTestCase {
    func testBackupRoundTrip() throws {
        var data = UserData()
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        data.cards["5:la sœur"] = CardState(interval: 4, ease: 2.5, due: created, lapses: 1)
        data.sets = [StudySet(first: 10, last: 5)]
        data.notes = [Note(target: "text-5", text: "проверить", fragment: .init(quote: "ils prennent", section: 1, item: 2, first: 3, last: 4), created: created)]
        data.addedWords = [Word(fr: "matin", m: "mat[in]", ipa: "matɛ̃", ru: "")]
        data.lastLesson = 5

        XCTAssertEqual(try UserData.decode(data.encoded()), data)
        XCTAssertEqual(data.sets[0].lessons, 5...10)
        XCTAssertEqual(data.addedEntries.map(\.id), ["0:matin"])
    }

    func testOlderBackupWithoutNewerFieldsStillLoads() throws {
        let loaded = try UserData.decode(Data(#"{"version":1,"cards":{}}"#.utf8))
        XCTAssertEqual(loaded, UserData())
    }

    func testRejectsForeignFilesAndNewerVersions() {
        XCTAssertThrowsError(try UserData.decode(Data("[1, 2]".utf8))) { XCTAssertEqual($0 as? UserData.Failure, .notABackup) }
        XCTAssertThrowsError(try UserData.decode(Data(#"{"version":99}"#.utf8))) { XCTAssertEqual($0 as? UserData.Failure, .newerVersion(99)) }
    }
}
