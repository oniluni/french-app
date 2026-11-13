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

/// Practice: word cards, drills of word forms and questions on rules, each by lesson range or by topic.
struct PracticeView: View {
    private enum Part: String, CaseIterable {
        case words = "Слова", forms = "Формы", rules = "Правила"
    }

    @State private var part = Part.words

    var body: some View {
        Group {
            switch part {
            case .words: WordsPractice()
            case .forms: FormsPractice()
            case .rules: RulesPractice()
            }
        }
        .navigationTitle("Практика")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Вид практики", selection: $part) {
                    ForEach(Part.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 280)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WordsPractice: View {
    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @State private var session: SessionRequest?

    var body: some View {
        let cards = store.data.cards
        let favorites = library.content.entries(forWords: store.data.favorites)
        // Starred lesson words already are lesson cards; only the others are added.
        let everything = library.content.entries + favorites.filter { $0.lesson == 0 }
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

            LessonRangeSection(
                header: "Новый набор",
                footer: "Карточка показывает слово: вспомните перевод и произношение, откройте ответ и оцените себя. Набор сохранится в «Моих наборах».",
                describe: { plural(library.content.entries(in: $0).count, "слово", "слова", "слов") }
            ) { range in
                start(store.saveSet(first: range.lowerBound, last: range.upperBound))
            }

            if !store.data.sets.isEmpty || !favorites.isEmpty {
                Section("Мои наборы") {
                    ForEach(store.data.sets) { set in
                        setRow(title: title(of: set), entries: library.content.entries(in: set.lessons)) { start(set) }
                    }
                    .onDelete { offsets in
                        for set in offsets.map({ store.data.sets[$0] }) { store.delete(set) }
                    }
                    if !favorites.isEmpty {
                        setRow(title: "Избранное", entries: favorites) {
                            session = SessionRequest(title: "Избранное", entries: favorites)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }
    }

    private func title(of set: StudySet) -> String {
        lessonsTitle(set.first...set.last)
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

/// «Урок 3», «Уроки 3–5».
private func lessonsTitle(_ range: ClosedRange<Int>) -> String {
    range.count == 1 ? "Урок \(range.lowerBound)" : "Уроки \(range.lowerBound)–\(range.upperBound)"
}

/// A grid of lesson numbers: the first tap sets the start, the second the end, a third starts over.
private struct LessonRangeSection: View {
    let header: String
    let footer: String
    /// What the range holds: «12 слов».
    let describe: (ClosedRange<Int>) -> String
    let start: (ClosedRange<Int>) -> Void

    @Environment(Library.self) private var library
    @State private var first: Int?
    @State private var last: Int?

    private var range: ClosedRange<Int>? {
        guard let first else { return nil }
        return min(first, last ?? first)...max(first, last ?? first)
    }

    var body: some View {
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
                    Text(lessonsTitle(range))
                    Text("· \(describe(range))").foregroundStyle(.secondary)
                } else {
                    Text("Выберите первый и последний урок").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Начать") {
                    guard let range else { return }
                    start(range)
                    first = nil
                    last = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(range == nil)
            }
            .font(.subheadline)
        } header: {
            Text(header)
        } footer: {
            Text(footer)
        }
        .sensoryFeedback(.selection, trigger: range)
    }

    private func choose(_ lesson: Int) {
        if first == nil || last != nil {
            first = lesson
            last = nil
        } else {
            last = lesson
        }
    }
}

/// A row that starts a quiz on one topic.
private struct TopicRow: View {
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Color.primary)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.fill").foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityIdentifier("topic-\(title)")
    }
}

private struct FormsPractice: View {
    @Environment(Library.self) private var library
    @State private var drill: DrillRequest?
    @State private var words: [FormWord] = []

    var body: some View {
        let verbs = words.filter { $0.wordClass == .verb }
        let nouns = words.filter { $0.wordClass == .noun }
        let adjectives = words.filter { $0.wordClass == .adjective }
        List {
            Section {
                Button {
                    start("Смешанная тренировка", forms: words, genders: nouns)
                } label: {
                    Label("Смешанная тренировка", systemImage: "shuffle")
                }
                .disabled(words.isEmpty)
            } footer: {
                Text("Восемь вопросов по словам всех уроков: спряжения, род, артикли и число.")
            }

            LessonRangeSection(
                header: "По урокам",
                footer: "Вопросы о формах слов из выбранных уроков. В каждом вопросе нужно выбрать одну форму из нескольких.",
                describe: { range in plural(words.filter { range.contains($0.entry.lesson) }.count, "слово", "слова", "слов") + " с формами" }
            ) { range in
                let chosen = words.filter { range.contains($0.entry.lesson) }
                start(lessonsTitle(range), forms: chosen, genders: chosen.filter { $0.wordClass == .noun })
            }

            Section {
                ForEach(Grammar.tenseNames, id: \.self) { tense in
                    TopicRow(title: tense, detail: "\(plural(verbs.count, "глагол", "глагола", "глаголов")) из уроков") {
                        start(tense, forms: verbs, tense: tense)
                    }
                }
            } header: {
                Text("Спряжения")
            } footer: {
                Text("Дано местоимение, например nous…: выберите форму глагола, которая к нему подходит.")
            }

            Section {
                TopicRow(title: "Род существительных", detail: "un или une: мужской или женский род") {
                    start("Род существительных", forms: [], genders: nouns)
                }
                TopicRow(title: "Артикль и число", detail: "le, la, les · un, une, des") {
                    start("Артикль и число", forms: nouns)
                }
                TopicRow(title: "Прилагательные", detail: "мужской и женский род, единственное и множественное число") {
                    start("Прилагательные", forms: adjectives)
                }
            } header: {
                Text("Род и число")
            }
        }
        // Finding the lemmas of every lesson word takes a moment: not on the first frame.
        .task { words = library.formWords }
        .fullScreenCover(item: $drill) { DrillSessionView(request: $0) }
    }

    /// Eight questions: forms of `forms` (in `tense` only, if given), and a couple on the gender of
    /// `genders` (all eight when there are no forms to ask).
    private func start(_ title: String, forms: [FormWord], genders: [FormWord] = [], tense: String? = nil) {
        let count = 8
        var generator = SystemRandomNumberGenerator()
        let grammar = library.grammar
        let genderQuestions = grammar.genderQuestions(nouns: genders.map(\.lemma), count: forms.isEmpty ? count : 2, using: &generator)
        // A dozen words give enough forms; building every paradigm would only slow the start.
        let paradigms = forms.shuffled(using: &generator).prefix(12).compactMap { grammar.paradigm(lemma: $0.lemma, as: $0.wordClass) }
        let formQuestions = Drill.questions(from: paradigms, tense: tense, count: count - genderQuestions.count, using: &generator)
        drill = DrillRequest(title: title, questions: (genderQuestions + formQuestions).shuffled(using: &generator))
    }
}

private struct RulesPractice: View {
    @Environment(Library.self) private var library
    @State private var quiz: RuleRequest?

    private static let kinds = ["Грамматика", "Произношение", "Чтение"]

    var body: some View {
        // Notes have no trigger: there is no phrase to ask them on.
        let rules = library.content.lessons.flatMap(\.rules).filter { $0.trigger != nil }
        List {
            LessonRangeSection(
                header: "По урокам",
                footer: "Вы увидите фразу из урока и четыре правила. Выберите правило, которое в этой фразе работает; после ответа слова, к которым оно относится, выделятся.",
                describe: { range in plural(rules.filter { range.contains($0.lesson) }.count, "правило", "правила", "правил") }
            ) { range in
                start(lessonsTitle(range), rules.filter { range.contains($0.lesson) })
            }

            Section("По видам") {
                ForEach(RulesPractice.kinds, id: \.self) { kind in
                    let pool = rules.filter { $0.kind == kind }
                    TopicRow(title: kind, detail: "\(plural(pool.count, "правило", "правила", "правил")) из всех уроков") {
                        start(kind, pool)
                    }
                }
            }
        }
        .fullScreenCover(item: $quiz) { RuleSessionView(request: $0) }
    }

    private func start(_ title: String, _ rules: [Rule]) {
        var generator = SystemRandomNumberGenerator()
        quiz = RuleRequest(title: title, questions: library.content.ruleQuestions(on: rules, reader: library.reader, count: 8, using: &generator))
    }
}
