import FrenchCore
import SwiftUI

/// Cards to go through in one sitting.
struct SessionRequest: Identifiable {
    let id = UUID()
    let title: String
    let entries: [Entry]
}

/// Forms to drill in one sitting.
struct DrillRequest: Identifiable {
    let id = UUID()
    let title: String
    let questions: [DrillQuestion]
}

/// Practice: word cards by lesson range, and drills of word forms.
struct PracticeView: View {
    private enum Part: String, CaseIterable {
        case words = "Слова", forms = "Формы"
    }

    @State private var part = Part.words

    var body: some View {
        Group {
            switch part {
            case .words: WordsPractice()
            case .forms: FormsPractice()
            }
        }
        .navigationTitle("Практика")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Вид практики", selection: $part) {
                    ForEach(Part.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 200)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WordsPractice: View {
    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @State private var session: SessionRequest?
    /// First and second tap on the lesson grid; a third tap starts over.
    @State private var first: Int?
    @State private var last: Int?

    private var range: ClosedRange<Int>? {
        guard let first else { return nil }
        return min(first, last ?? first)...max(first, last ?? first)
    }

    var body: some View {
        let cards = store.data.cards
        let everything = library.content.entries + store.data.addedEntries
        let due = Session.due(in: everything, cards: cards, now: .now)
        List {
            Section("Сегодня") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plural(due.count, "карточка", "карточки", "карточек")).font(.title3.weight(.semibold))
                        Text(due.isEmpty ? "На сегодня всё повторено" : "пора повторить").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Повторить") { session = SessionRequest(title: "Сегодня", entries: due) }
                        .buttonStyle(.borderedProminent)
                        .disabled(due.isEmpty)
                }
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(library.content.lessons) { lesson in
                        let isChosen = range?.contains(lesson.id) ?? false
                        Button {
                            choose(lesson.id)
                        } label: {
                            Text("\(lesson.id)")
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(isChosen ? Color.white : Color.primary)
                                .background(isChosen ? Color.accentColor : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Урок \(lesson.id)")
                        .accessibilityAddTraits(isChosen ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
                HStack {
                    if let range {
                        let count = library.content.entries(in: range).count
                        Text(range.count == 1 ? "Урок \(range.lowerBound)" : "Уроки \(range.lowerBound)–\(range.upperBound)")
                        Text("· \(plural(count, "слово", "слова", "слов"))").foregroundStyle(.secondary)
                    } else {
                        Text("Выберите первый и последний урок").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Начать") {
                        guard let range else { return }
                        let set = store.saveSet(first: range.lowerBound, last: range.upperBound)
                        start(set)
                        first = nil
                        last = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(range == nil)
                }
                .font(.subheadline)
            } header: {
                Text("Новый набор")
            }

            if !store.data.sets.isEmpty || !store.data.addedWords.isEmpty {
                Section("Мои наборы") {
                    ForEach(store.data.sets) { set in
                        setRow(title: title(of: set), entries: library.content.entries(in: set.lessons)) { start(set) }
                    }
                    .onDelete { offsets in
                        for set in offsets.map({ store.data.sets[$0] }) { store.delete(set) }
                    }
                    if !store.data.addedWords.isEmpty {
                        setRow(title: "Добавленные слова", entries: store.data.addedEntries) {
                            session = SessionRequest(title: "Добавленные слова", entries: store.data.addedEntries)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }
    }

    private func choose(_ lesson: Int) {
        if first == nil || last != nil {
            first = lesson
            last = nil
        } else {
            last = lesson
        }
    }

    private func title(of set: StudySet) -> String {
        set.first == set.last ? "Урок \(set.first)" : "Уроки \(set.first)–\(set.last)"
    }

    private func start(_ set: StudySet) {
        session = SessionRequest(title: title(of: set), entries: library.content.entries(in: set.lessons))
    }

    private func setRow(title: String, entries: [Entry], action: @escaping () -> Void) -> some View {
        let cards = store.data.cards
        let started = entries.filter { cards[$0.id] != nil }.count
        let due = Session.due(in: entries, cards: cards, now: .now).count
        return Button(action: action) {
            HStack(spacing: 14) {
                ProgressRing(progress: Session.progress(of: entries, cards: cards)) {
                    Image(systemName: "rectangle.on.rectangle.angled").font(.footnote).foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Color.primary)
                    Text("Начато \(started) из \(entries.count)" + (due > 0 ? " · повторить \(due)" : ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.fill").foregroundStyle(Color.accentColor)
            }
        }
    }
}

private struct FormsPractice: View {
    @Environment(Library.self) private var library
    @State private var drill: DrillRequest?
    /// Nil is every tense.
    @State private var tense: String?
    @State private var words: [FormWord] = []

    var body: some View {
        let verbs = words.filter { $0.wordClass == .verb }
        let others = words.filter { $0.wordClass != .verb }
        List {
            Section {
                Button {
                    start(title: "Смешанная тренировка", words: Array(words.shuffled().prefix(12)), tense: nil, count: 8)
                } label: {
                    Label("Смешанная тренировка", systemImage: "shuffle")
                }
                .disabled(words.isEmpty)
            } footer: {
                Text("Восемь вопросов по глаголам, существительным и прилагательным из уроков.")
            }

            Section("Спряжения") {
                Picker("Время", selection: $tense) {
                    Text("Все").tag(String?.none)
                    ForEach(Grammar.tenseNames, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                .pickerStyle(.segmented)
                ForEach(verbs) { word in row(word) }
            }

            Section("Род и число") {
                ForEach(others) { word in row(word) }
            }
        }
        .task { words = library.formWords }
        .fullScreenCover(item: $drill) { DrillSessionView(request: $0) }
    }

    private func row(_ word: FormWord) -> some View {
        Button {
            start(title: word.lemma, words: [word], tense: word.wordClass == .verb ? tense : nil, count: 8)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.lemma).font(Theme.french(.title3)).foregroundStyle(Color.primary)
                    Text(word.entry.word.ru).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text("урок \(word.entry.lesson)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func start(title: String, words: [FormWord], tense: String?, count: Int) {
        var generator = SystemRandomNumberGenerator()
        let paradigms = words.compactMap { library.grammar.paradigm(lemma: $0.lemma, as: $0.wordClass) }
        let questions = Drill.questions(from: paradigms, tense: tense, count: count, using: &generator)
        if !questions.isEmpty { drill = DrillRequest(title: title, questions: questions) }
    }
}
