import FrenchCore
import SwiftUI
import UniformTypeIdentifiers

/// Every word of the lessons, with the search field in the tab bar and a lesson filter;
/// or the learner's starred words.
struct DictionaryView: View {
    let query: String

    private enum Part: String, CaseIterable {
        case all = "Все слова", favorites = "Избранное"
    }

    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var part = Part.all
    /// Nil is every lesson.
    @State private var lesson: Int?

    @State private var session: SessionRequest?
    @State private var exported: BackupDocument?
    @State private var isImporting = false
    @State private var pending: Data?
    @State private var result: BackupResult?
    @State private var successes = 0
    @State private var failures = 0

    var body: some View {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        let matches: (Word) -> Bool = { word in
            wanted.isEmpty || word.fr.localizedStandardContains(wanted) || word.ru.localizedStandardContains(wanted)
        }

        Screen {
            VStack(spacing: 0) {
                NavSegments(options: Part.allCases.map { (value: $0, title: $0.rawValue) },
                            selection: $part)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                if part == .all {
                    lessonChips
                    allWords(matches: matches, wanted: wanted)
                } else {
                    favorites(matches: matches, wanted: wanted)
                }
            }
        }
        .navigationTitle(part == .all ? "Словарь" : "Избранное")
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }
        .fileExporter(isPresented: Binding { exported != nil } set: { if !$0 { exported = nil } },
                      document: exported, contentType: .json, defaultFilename: BackupDocument.filename) { outcome in
            if case .failure(let error) = outcome {
                result = .failure("Копия не сохранена: \(error.localizedDescription)")
                failures += 1
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { outcome in
            do {
                let url = try outcome.get()
                let isScoped = url.startAccessingSecurityScopedResource()
                defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
                pending = try Data(contentsOf: url)
            } catch {
                result = .failure("Не удалось открыть файл: \(error.localizedDescription)")
                failures += 1
            }
        }
        .overlay { backupOverlay }
        .sensoryFeedback(.success, trigger: successes)
        .sensoryFeedback(.error, trigger: failures)
    }

    // MARK: All words

    private var lessonChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "Все уроки", isOn: lesson == nil) { lesson = nil }
                ForEach(library.content.lessons) { item in
                    FilterChip(title: "Урок \(item.id)", isOn: lesson == item.id) { lesson = item.id }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.top, 4)
    }

    @ViewBuilder private func allWords(matches: @escaping (Word) -> Bool, wanted: String) -> some View {
        let lessons = library.content.lessons.filter { lesson == nil || $0.id == lesson }
        let groups = lessons.compactMap { item -> (lesson: Lesson, entries: [Entry])? in
            let entries = item.entries.filter { matches($0.word) }
            return entries.isEmpty ? nil : (lesson: item, entries: entries)
        }
        if groups.isEmpty {
            EmptyState(systemImage: "magnifyingglass", title: "Ничего не найдено",
                       text: lesson == nil
                           ? "Нет слов с «\(wanted)» ни по-французски, ни в переводе."
                           : "В уроке \(lesson ?? 0) нет «\(wanted)». Выберите «Все уроки», чтобы искать везде.")
                .padding(.top, 40)
        }
        ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
            SectionHeader(title: "Урок \(group.lesson.id)", trailing: "\(group.entries.count)")
            Card {
                ForEach(group.entries) { entry in
                    dictionaryRow(entry: entry, favorite: false)
                }
            }
        }
        if wanted.isEmpty && lesson == nil {
            backupSection
        }
    }

    // MARK: Favourites

    @ViewBuilder private func favorites(matches: (Word) -> Bool, wanted: String) -> some View {
        let words = store.data.favorites.filter(matches)
        if store.data.favorites.isEmpty {
            EmptyState(systemImage: "star", title: "В избранном пусто",
                       text: "Отмечайте слова звёздочкой в читалке или в разборе слова.") {
                Button("Открыть читалку") { navigator.tab = .analysis }
                    .buttonStyle(.pill(.quiet, small: true))
            }
            .padding(.top, 40)
        } else if words.isEmpty {
            EmptyState(systemImage: "magnifyingglass", title: "Ничего не найдено",
                       text: "В избранном нет «\(wanted)».")
                .padding(.top, 40)
        } else {
            let due = words.filter { word in
                guard let entry = library.entry(for: word.fr) else { return false }
                return store.status(of: entry) == .due
            }.count
            Card {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Учить избранное").font(Theme.bodyMedium)
                        Text("\(plural(words.count, "слово", "слова", "слов"))" + (due > 0 ? " · \(due) пора повторить" : ""))
                            .font(Theme.mono(13)).foregroundStyle(Theme.t2)
                    }
                    Spacer(minLength: 8)
                    Button("Начать") {
                        let entries = library.content.entries(forWords: words)
                        session = SessionRequest(title: "Избранное", entries: entries)
                    }
                    .buttonStyle(.pill(.primary, small: true))
                }
                .padding(16)
            }
            .padding(.top, 12)

            SectionHeader(title: plural(words.count, "слово", "слова", "слов"))
            Card {
                ForEach(words, id: \.fr) { word in
                    favoriteRow(word)
                }
            }
        }
    }

    // MARK: Rows

    private func dictionaryRow(entry: Entry, favorite: Bool) -> some View {
        let status = store.status(of: entry)
        return HStack(spacing: 0) {
            Button {
                navigator.push(.word(entry.word.fr))
            } label: {
                HStack(spacing: 12) {
                    wordText(fr: entry.word.fr, marked: entry.word.m, ipa: entry.word.ipa,
                             ru: entry.word.ru, pos: entry.word.pos)
                    if !favorite {
                        Chip(text: status.label, tone: status.tone)
                    }
                }
                .row()
            }
            .buttonStyle(.plain)
            if favorite {
                favoriteButton(entry.word)
            }
        }
    }

    private func favoriteRow(_ word: Word) -> some View {
        HStack(spacing: 0) {
            Button {
                navigator.push(.word(word.fr))
            } label: {
                wordText(fr: word.fr, marked: word.m, ipa: word.ipa, ru: firstSense(word.ru), pos: word.pos)
                    .row()
            }
            .buttonStyle(.plain)
            favoriteButton(word)
        }
    }

    /// The first sense of a dictionary translation, as the favorites list shows it.
    private func firstSense(_ translation: String) -> String {
        translation.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? translation
    }

    private func wordText(fr: String, marked: String?, ipa: String, ru: String, pos: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MarkedText(marked: marked, plain: fr, size: 19, weight: .medium)
                if !ipa.isEmpty {
                    Text("[\(ipa)]").font(Theme.ipa(13)).foregroundStyle(Theme.t2)
                }
                if let level = library.level(of: fr) { LevelTag(level: level) }
            }
            Text(ru).font(Theme.subhead).foregroundStyle(Theme.t2)
            if let form = library.shortForm(of: fr), !form.isEmpty {
                Text(form).font(Theme.caption1).foregroundStyle(Theme.t3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func favoriteButton(_ word: Word) -> some View {
        let isFavorite = store.isFavorite(word.fr)
        return Button {
            store.toggleFavorite(library.favorite(word))
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 17))
                .foregroundStyle(isFavorite ? Theme.acc : Theme.t3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Убрать из избранного" : "В избранное")
    }

    // MARK: Backup

    private var backupSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Резервная копия")
            Card {
                Button(action: exportBackup) {
                    backupRow("Сохранить в Файлы", "Копия карточек, заметок и избранного",
                              systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                Button { isImporting = true } label: {
                    backupRow("Восстановить из файла", "Файл .json, сохранённый приложением",
                              systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
            }
            Callout(isWarning: true) {
                Text("При переустановке приложения его данные удаляются. Копия в «Файлах» — единственный способ их сохранить.")
            }
            .padding(.top, 8)
        }
    }

    private func backupRow(_ title: String, _ subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 17)).foregroundStyle(Theme.acc)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.bodyMedium)
                Text(subtitle).font(Theme.subhead).foregroundStyle(Theme.t2)
            }
            Spacer(minLength: 0)
            Chevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func exportBackup() {
        do {
            exported = BackupDocument(data: try store.backup())
        } catch {
            result = .failure("Не удалось подготовить копию: \(error.localizedDescription)")
            failures += 1
        }
    }

    @ViewBuilder private var backupOverlay: some View {
        if let pending {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Заменить текущий прогресс копией?").font(Theme.title3)
                        .multilineTextAlignment(.center)
                    Text("Карточки, наборы и заметки на этом устройстве будут заменены содержимым файла.")
                        .font(Theme.subhead).foregroundStyle(Theme.t2)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 8) {
                        Button("Заменить") {
                            restore(pending)
                        }
                        .buttonStyle(.pill(.danger, small: true))
                        Button("Отмена") { self.pending = nil }
                            .buttonStyle(.pill(.quiet, small: true))
                    }
                    .padding(.top, 4)
                }
                .padding(24)
                .padding(.bottom, 8)
                .frame(maxWidth: 320)
                .background(Theme.s2.opacity(0.96), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.12)) }
            }
            .transition(.opacity)
        } else if let result {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 12) {
                    switch result {
                    case .success:
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.green)
                            .frame(width: 44, height: 44)
                            .background(Theme.greenSoft, in: Circle())
                        Text("Копия восстановлена").font(Theme.title3)
                        Text("Карточки, заметки и избранное снова на месте.")
                            .font(Theme.subhead).foregroundStyle(Theme.t2)
                            .multilineTextAlignment(.center)
                    case .failure(let message):
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.red)
                            .frame(width: 44, height: 44)
                            .background(Theme.redSoft, in: Circle())
                        Text("Не удалось восстановить").font(Theme.title3)
                        Text(message).font(Theme.subhead).foregroundStyle(Theme.t2)
                            .multilineTextAlignment(.center)
                    }
                    Button("Готово") { self.result = nil }
                        .buttonStyle(.pill(.primary, small: true))
                        .padding(.top, 4)
                }
                .padding(24)
                .padding(.bottom, 8)
                .frame(maxWidth: 320)
                .background(Theme.s2.opacity(0.96), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.12)) }
            }
            .transition(.opacity)
        }
    }

    private func restore(_ data: Data) {
        do {
            try store.restore(from: data)
            result = .success
            successes += 1
        } catch UserData.Failure.newerVersion {
            result = .failure("Копия сделана более новой версией приложения. Обновите приложение и повторите.")
            failures += 1
        } catch {
            result = .failure("Это не копия прогресса этого приложения. Выберите файл, сохранённый приложением.")
            failures += 1
        }
        pending = nil
    }
}

private enum BackupResult: Equatable {
    case success
    case failure(String)
}

/// The progress file as a document the system can save to and open from «Файлы».
struct BackupDocument: FileDocument {
    static let filename = "Français — прогресс"
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
