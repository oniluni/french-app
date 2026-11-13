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
    @State private var part = Part.all
    /// Nil is every lesson.
    @State private var lesson: Int?

    var body: some View {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        // Case and accents do not matter: "eleve" finds "élève".
        let matches: (Word) -> Bool = { word in
            wanted.isEmpty || word.fr.localizedStandardContains(wanted) || word.ru.localizedStandardContains(wanted)
        }

        List {
            Section {
                Picker("Что показать", selection: $part) {
                    ForEach(Part.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                if part == .all {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            chip("Все", isOn: lesson == nil) { lesson = nil }
                            ForEach(library.content.lessons) { item in
                                chip("Урок \(item.id)", isOn: lesson == item.id) { lesson = item.id }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            switch part {
            case .all: allWords(matches: matches, wanted: wanted)
            case .favorites: favorites(matches: matches, wanted: wanted)
            }
        }
        .navigationTitle("Словарь")
    }

    @ViewBuilder private func allWords(matches: @escaping (Word) -> Bool, wanted: String) -> some View {
        let lessons = library.content.lessons.filter { lesson == nil || $0.id == lesson }
        let groups = lessons.map { ($0, $0.entries.filter { matches($0.word) }) }.filter { !$0.1.isEmpty }
        if groups.isEmpty {
            ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass",
                description: Text(lesson == nil
                    ? "Нет слов с «\(wanted)» ни по-французски, ни в переводе."
                    : "В уроке \(lesson ?? 0) нет «\(wanted)». Выберите «Все», чтобы искать во всех уроках."))
        }
        ForEach(groups, id: \.0.id) { item, entries in
            Section("Урок \(item.id)") {
                ForEach(entries) { entry in
                    NavigationLink(value: Route.word(entry.word.fr)) { WordRow(entry: entry) }
                }
            }
        }
    }

    @ViewBuilder private func favorites(matches: (Word) -> Bool, wanted: String) -> some View {
        let words = store.data.favorites.filter(matches)
        if store.data.favorites.isEmpty {
            ContentUnavailableView("Избранного пока нет", systemImage: "star",
                description: Text("Отмечайте слова звёздочкой в читалке или в разборе слова."))
        } else if words.isEmpty {
            ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass",
                description: Text("В избранном нет «\(wanted)»."))
        } else {
            Section(plural(words.count, "слово", "слова", "слов")) {
                ForEach(words, id: \.fr) { word in
                    NavigationLink(value: Route.word(word.fr)) { FavoriteRow(word: word) }
                }
                .onDelete { offsets in
                    for index in offsets { store.toggleFavorite(words[index]) }
                }
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(isOn ? Color.accentColor : Color(uiColor: .tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A starred word: its marks, translation, what kind of word it is and its level.
struct FavoriteRow: View {
    let word: Word
    @Environment(Library.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MarkedText(marked: word.m, plain: word.fr, style: .title3)
                if let level = library.level(of: word.fr) { LevelTag(level: level) }
            }
            let translation = word.ru.isEmpty ? library.translation(of: word.fr) : word.ru
            Text(translation ?? "Перевода нет в словаре").font(.subheadline).foregroundStyle(translation == nil ? HierarchicalShapeStyle.tertiary : HierarchicalShapeStyle.secondary)
            if let form = library.shortForm(of: word.fr) {
                Text(form).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// The progress file as a document the system can save to and open from «Файлы».
struct BackupDocument: FileDocument {
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

/// Saving and restoring the learner's data. A re-signed app may have to be deleted and installed
/// again, and its data goes with it, so a copy in «Файлы» is the only way across.
struct BackupButtons: View {
    @Environment(Store.self) private var store
    @State private var exported: BackupDocument?
    @State private var isImporting = false
    @State private var pending: Data?
    @State private var message: String?
    /// Counts finished saves and restores, for the success haptic.
    @State private var successes = 0
    /// Counts failed ones, for the error haptic.
    @State private var failures = 0

    var body: some View {
        Button {
            do {
                exported = BackupDocument(data: try store.backup())
            } catch {
                failures += 1
                message = "Не удалось подготовить копию: \(error.localizedDescription)"
            }
        } label: {
            Label("Сохранить копию в Файлы", systemImage: "square.and.arrow.up")
        }
        Button {
            isImporting = true
        } label: {
            Label("Восстановить из копии", systemImage: "square.and.arrow.down")
        }
        .fileExporter(isPresented: Binding { exported != nil } set: { if !$0 { exported = nil } },
                      document: exported, contentType: .json, defaultFilename: "Français — прогресс") { result in
            switch result {
            case .success: successes += 1
            case .failure(let error):
                failures += 1
                message = "Копия не сохранена: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let isScoped = url.startAccessingSecurityScopedResource()
                defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
                pending = try Data(contentsOf: url)
            } catch {
                failures += 1
                message = "Не удалось открыть файл: \(error.localizedDescription)"
            }
        }
        .confirmationDialog("Заменить текущий прогресс копией?", isPresented: Binding { pending != nil } set: { if !$0 { pending = nil } },
                            titleVisibility: .visible) {
            Button("Заменить", role: .destructive) {
                guard let pending else { return }
                do {
                    try store.restore(from: pending)
                    successes += 1
                    message = "Прогресс восстановлен."
                } catch UserData.Failure.newerVersion {
                    failures += 1
                    message = "Копия сделана более новой версией приложения. Обновите приложение и повторите."
                } catch {
                    failures += 1
                    message = "Это не копия прогресса этого приложения. Выберите файл, сохранённый кнопкой «Сохранить копию в Файлы»."
                }
                self.pending = nil
            }
        } message: {
            Text("Карточки, наборы и заметки на этом устройстве будут заменены содержимым файла.")
        }
        .sensoryFeedback(.success, trigger: successes)
        .sensoryFeedback(.error, trigger: failures)
        .alert(message ?? "", isPresented: Binding { message != nil } set: { if !$0 { message = nil } }) {
            Button("Понятно", role: .cancel) {}
        }
    }
}
