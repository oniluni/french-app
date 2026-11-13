import Foundation
import FrenchCore
import Observation
import os

/// The learner's data: cards, sets, notes. One JSON file, rewritten on every change.
///
/// shortcut: the whole file is rewritten per change. It stays in the tens of kilobytes for the
/// full course; move to a database if a profile ever shows the writes.
@MainActor
@Observable
final class Store {
    private(set) var data: UserData
    /// A problem the learner has to know about. Shown as an alert by the root view.
    var failure: String?

    private let fileURL: URL
    private let log = Logger(subsystem: "io.github.oniluni.french", category: "store")

    init(fileURL: URL = Store.defaultURL) {
        self.fileURL = fileURL
        data = UserData()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            data = try UserData.decode(Data(contentsOf: fileURL))
        } catch {
            // Keep the unreadable file: the next save must not overwrite the only copy of the progress.
            let kept = fileURL.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? FileManager.default.removeItem(at: kept)
            try? FileManager.default.moveItem(at: fileURL, to: kept)
            log.error("Cannot read \(fileURL.path, privacy: .public): \(String(describing: error), privacy: .public)")
            failure = "Не удалось прочитать сохранённый прогресс. Файл оставлен в папке приложения под именем \(kept.lastPathComponent), приложение начато с чистого листа."
        }
    }

    nonisolated static var defaultURL: URL {
        let folder = URL.applicationSupportDirectory
        if ProcessInfo.processInfo.arguments.contains("-uitest") {
            // UI tests start from an empty profile every time.
            let scratch = URL.temporaryDirectory.appending(path: "uitest-progress.json")
            try? FileManager.default.removeItem(at: scratch)
            return scratch
        }
        return folder.appending(path: "progress.json")
    }

    func update(_ change: (inout UserData) -> Void) {
        change(&data)
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.encoded().write(to: fileURL, options: .atomic)
        } catch {
            log.error("Cannot save progress: \(String(describing: error), privacy: .public)")
            failure = "Не удалось сохранить прогресс: \(error.localizedDescription)"
        }
    }

    // MARK: Cards

    func grade(_ entry: Entry, _ grade: Grade, now: Date = .now) {
        update { $0.cards[entry.id] = Scheduler.next($0.cards[entry.id], grade: grade, now: now) }
    }

    func status(of entry: Entry, now: Date = .now) -> CardStatus {
        Scheduler.status(data.cards[entry.id], now: now)
    }

    func isFavorite(_ word: String) -> Bool {
        let key = Content.bare(word)
        return data.favorites.contains { Content.bare($0.fr) == key }
    }

    /// Stars the word, or unstars it if it is starred.
    func toggleFavorite(_ word: Word) {
        let key = Content.bare(word.fr)
        update { data in
            if data.favorites.contains(where: { Content.bare($0.fr) == key }) {
                data.favorites.removeAll { Content.bare($0.fr) == key }
            } else {
                data.favorites.append(word)
            }
        }
    }

    // MARK: Sets and notes

    func saveSet(first: Int, last: Int) -> StudySet {
        let wanted = StudySet(first: first, last: last)
        if let existing = data.sets.first(where: { $0.lessons == wanted.lessons }) { return existing }
        update { $0.sets.insert(wanted, at: 0) }
        return wanted
    }

    func delete(_ set: StudySet) {
        update { $0.sets.removeAll { $0.id == set.id } }
    }

    func notes(for target: String) -> [Note] {
        data.notes.filter { $0.target == target }
    }

    func addNote(_ text: String, to target: String) {
        update { $0.notes.append(Note(target: target, text: text, created: .now)) }
    }

    func delete(_ note: Note) {
        update { $0.notes.removeAll { $0.id == note.id } }
    }

    // MARK: Backup

    func backup() throws -> Data {
        try data.encoded()
    }

    func restore(from backup: Data) throws {
        let restored = try UserData.decode(backup)
        update { $0 = restored }
    }
}
