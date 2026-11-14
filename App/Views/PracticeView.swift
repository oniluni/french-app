import FrenchCore
import OSLog
import SwiftUI

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
        Screen {
            switch part {
            case .words: WordsPractice()
            case .forms: FormsPractice()
            case .rules: RulesPractice()
            }
        }
        .navigationTitle("Практика")
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavSegments(options: Part.allCases.map { (value: $0, title: $0.rawValue) },
                            selection: $part)
            }
        }
    }
}

private struct WordsPractice: View {
    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @State private var session: SessionRequest?
    @State private var range: ClosedRange<Int>?

    var body: some View {
        let cards = store.data.cards
        let favorites = library.content.entries(forWords: store.data.favorites)
        // Starred lesson words already are lesson cards; only the others are added.
        let everything = library.content.entries + favorites.filter { $0.lesson == 0 }
        let due = Session.due(in: everything, cards: cards, now: .now)

        // The main button moves to «Начать» once a range is chosen.
        DueTile(count: due.count, button: range == nil ? .primary : .quiet) {
            session = SessionRequest(title: "Сегодня", entries: due)
        }
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }

        SectionHeader(title: "Новый набор")
        LessonRangeCard(range: $range) { range in
            let words = library.content.entries(in: range).count
            return "\(plural(words, "слово", "слова", "слов")) · \(min(words, Session.size)) в сессии"
        } start: { range in
            start(store.saveSet(first: range.lowerBound, last: range.upperBound))
        }
        Footer(text: "Карточка показывает слово: вспомните перевод и произношение, откройте ответ и оцените себя. Набор сохранится в «Моих наборах».")

        if !store.data.sets.isEmpty || !favorites.isEmpty {
            SectionHeader(title: "Мои наборы", trailing: "\(store.data.sets.count + (favorites.isEmpty ? 0 : 1))")
            Card {
                if !favorites.isEmpty {
                    setRow(title: "Избранное", entries: favorites, icon: true) {
                        session = SessionRequest(title: "Избранное", entries: favorites)
                    }
                }
                ForEach(store.data.sets) { set in
                    setRow(title: title(of: set), entries: library.content.entries(in: set.lessons)) { start(set) }
                        .contextMenu {
                            Button("Удалить набор", systemImage: "trash", role: .destructive) { store.delete(set) }
                        }
                }
            }
            Footer(text: "Чтобы удалить набор, нажмите на него и подержите.")
        }
    }

    private func title(of set: StudySet) -> String {
        lessonsTitle(set.first...set.last)
    }

    private func start(_ set: StudySet) {
        session = SessionRequest(title: title(of: set), entries: library.content.entries(in: set.lessons))
    }

    /// A set: its progress, how much of it is started, what is due.
    private func setRow(title: String, entries: [Entry], icon: Bool = false, action: @escaping () -> Void) -> some View {
        let cards = store.data.cards
        let started = entries.filter { cards[$0.id] != nil }.count
        let due = Session.due(in: entries, cards: cards, now: .now).count
        let progress = Session.progress(of: entries, cards: cards)
        let state = due > 0 ? "\(due) пора повторить" : started > 0 ? "всё повторено" : "не начат"
        return Button(action: action) {
            HStack(spacing: 12) {
                if icon {
                    EmptyIcon(systemImage: "star.fill", color: Theme.acc, fill: Theme.accSoft, size: 40)
                } else {
                    ProgressRing(progress: progress) {
                        Text("\(Int((progress * 100).rounded()))%").font(Theme.mono(11, .medium, relativeTo: .caption2))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.bodyMedium)
                    Text(icon ? "\(plural(entries.count, "слово", "слова", "слов")) · \(state)" : "\(started) из \(entries.count) · \(state)")
                        .font(Theme.mono(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.t2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron()
            }
            .row()
        }
        .buttonStyle(RowButtonStyle())
    }
}

/// A grid of lesson numbers: the first tap sets the start, the second the end, a third starts over.
private struct LessonRangeCard: View {
    @Binding var range: ClosedRange<Int>?
    /// What the range holds: «12 слов · 10 в сессии».
    let describe: (ClosedRange<Int>) -> String
    let start: (ClosedRange<Int>) -> Void

    @Environment(Library.self) private var library
    /// Set by the second tap; until then the range is one lesson.
    @State private var hasEnd = false

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(library.content.lessons) { lesson in
                    cell(lesson.id)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    if let range {
                        Text(lessonsTitle(range)).font(Theme.bodyMedium)
                        Text(describe(range)).font(Theme.mono(14, relativeTo: .subheadline)).foregroundStyle(Theme.t2)
                    } else {
                        Text("Выберите первый урок").font(Theme.bodyMedium)
                        Text("Потом последний — получится диапазон").font(Theme.subhead).foregroundStyle(Theme.t2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Начать") {
                    guard let range else { return }
                    start(range)
                    self.range = nil
                    hasEnd = false
                }
                .buttonStyle(.pill(.primary, small: true))
                .disabled(range == nil)
            }
        }
        .panel()
        .sensoryFeedback(.selection, trigger: range)
    }

    private func cell(_ lesson: Int) -> some View {
        let isEnd = range.map { $0.lowerBound == lesson || $0.upperBound == lesson } ?? false
        let isInside = (range?.contains(lesson) ?? false) && !isEnd
        return Button {
            choose(lesson)
        } label: {
            Text("\(lesson)")
                .font(Theme.mono(16, .medium))
                .foregroundStyle(isEnd ? Theme.ink : isInside ? Theme.acc : Theme.t1)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(isEnd ? Theme.acc : isInside ? Theme.accSoft : Theme.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { if !isEnd && !isInside { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line) } }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Урок \(lesson)")
        .accessibilityAddTraits(isEnd || isInside ? .isSelected : [])
    }

    private func choose(_ lesson: Int) {
        if let range, !hasEnd {
            self.range = min(range.lowerBound, lesson)...max(range.lowerBound, lesson)
            hasEnd = true
        } else {
            range = lesson...lesson
            hasEnd = false
        }
    }
}

/// A row that starts a quiz on one topic.
private struct TopicRow: View {
    let title: String
    let detail: String
    var isDetailFrench = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.bodyMedium)
                    Text(detail).font(Theme.subhead).foregroundStyle(Theme.t2)
                        .environment(\.locale, Locale(identifier: isDetailFrench ? "fr" : "ru"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron()
            }
            .row()
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityIdentifier("topic-\(title)")
    }
}

private struct FormsPractice: View {
    @Environment(Library.self) private var library
    @State private var drill: DrillRequest?
    @State private var words: [FormWord] = []
    @State private var tense = Grammar.tenseNames.first ?? "Présent"
    @State private var range: ClosedRange<Int>?

    var body: some View {
        let verbs = words.filter { $0.wordClass == .verb }
        let nouns = words.filter { $0.wordClass == .noun }
        let adjectives = words.filter { $0.wordClass == .adjective }
        let lessons = library.content.lessons.map(\.id)

        HStack(spacing: 12) {
            EmptyIcon(systemImage: "shuffle", color: Theme.acc, fill: Theme.accSoft, size: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text("Смешанная тренировка").font(Theme.bodyMedium)
                Text(plural(FormsPractice.count, "вопрос", "вопроса", "вопросов")).font(Theme.subhead).foregroundStyle(Theme.t2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Начать") { start("Смешанная тренировка", forms: words, genders: nouns) }
                .buttonStyle(.pill(.primary, small: true))
                .disabled(words.isEmpty)
                .accessibilityIdentifier("mixed-drill")
        }
        .panel()
        Footer(text: "Восемь вопросов по словам всех уроков: спряжения, род, артикли и число.")

        SectionHeader(title: "Спряжения")
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Grammar.tenseNames, id: \.self) { name in
                    FilterChip(title: name, isOn: tense == name, isFrench: true) { tense = name }
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Глаголы уроков \(lessons.min() ?? 0)–\(lessons.max() ?? 0)").font(Theme.bodyMedium)
                    Text("лицо и число в \(tense)").font(Theme.subhead).foregroundStyle(Theme.t2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Начать") { start(tense, forms: verbs, tense: tense) }
                    .buttonStyle(.pill(.tinted, small: true))
                    .disabled(verbs.isEmpty)
                    .accessibilityIdentifier("conjugation-drill")
            }
        }
        .panel()
        Footer(text: "Дано местоимение, например nous…: выберите форму глагола, которая к нему подходит.")

        SectionHeader(title: "Род и число")
        Card {
            TopicRow(title: "Род существительных", detail: "un или une", isDetailFrench: true) {
                start("Род существительных", forms: [], genders: nouns)
            }
            TopicRow(title: "Артикль и число", detail: "le, la, l', les · un, une, des", isDetailFrench: true) {
                start("Артикль и число", forms: nouns)
            }
            TopicRow(title: "Прилагательные", detail: "мужской и женский род, множественное число") {
                start("Прилагательные", forms: adjectives)
            }
        }

        SectionHeader(title: "По урокам")
        LessonRangeCard(range: $range) { range in
            plural(words.filter { range.contains($0.entry.lesson) }.count, "слово", "слова", "слов") + " с формами"
        } start: { range in
            let chosen = words.filter { range.contains($0.entry.lesson) }
            start(lessonsTitle(range), forms: chosen, genders: chosen.filter { $0.wordClass == .noun })
        }
        Footer(text: "Вопросы о формах слов из выбранных уроков. В каждом вопросе нужно выбрать одну форму из нескольких.")
            // Finding the lemmas of every lesson word takes a moment: not on the first frame.
            .task { words = library.formWords }
            .fullScreenCover(item: $drill) { DrillSessionView(request: $0) }
    }

    private static let count = 8

    /// Eight questions: forms of `forms` (in `tense` only, if given), and a couple on the gender of
    /// `genders` (all eight when there are no forms to ask).
    private func start(_ title: String, forms: [FormWord], genders: [FormWord] = [], tense: String? = nil) {
        let count = FormsPractice.count
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
    @State private var range: ClosedRange<Int>?

    private static let kinds = ["Грамматика", "Произношение", "Чтение"]
    private static let count = 8

    var body: some View {
        let rules = library.content.lessons.flatMap(\.rules).filter(\.isAsked)
        SectionHeader(title: "По урокам", top: 4)
            .fullScreenCover(item: $quiz) { RuleSessionView(request: $0) }
        LessonRangeCard(range: $range) { range in
            let count = rules.filter { range.contains($0.lesson) }.count
            return "\(plural(count, "правило", "правила", "правил")) · \(plural(RulesPractice.count, "вопрос", "вопроса", "вопросов"))"
        } start: { range in
            start("Правила · \(lessonsTitle(range).lowercased())", rules.filter { range.contains($0.lesson) })
        }
        Footer(text: "Вы увидите фразу со словами выбранных уроков и четыре правила. Выберите правило, которое в этой фразе работает; после ответа слова, к которым оно относится, выделятся.")

        SectionHeader(title: "По видам")
        Card {
            ForEach(RulesPractice.kinds, id: \.self) { kind in
                let pool = rules.filter { $0.kind == kind }
                // One rule is no choice: it would be the answer to every question.
                if pool.count > 1 {
                    TopicRow(title: kind, detail: plural(pool.count, "правило", "правила", "правил")) {
                        start(kind, pool)
                    }
                }
            }
        }
    }

    private static let log = Logger(subsystem: "io.github.oniluni.french", category: "rules-practice")

    private func start(_ title: String, _ rules: [Rule]) {
        var generator = SystemRandomNumberGenerator()
        let questions: [RuleQuestion]
        do {
            questions = try library.content.ruleQuestions(on: rules, reader: library.reader, examples: library.examples,
                                                          count: RulesPractice.count, using: &generator)
        } catch {
            // A broken examples file is a build mistake; the session then says it has no questions.
            RulesPractice.log.error("Rule questions for \(title, privacy: .public): broken examples: \(String(describing: error), privacy: .public)")
            questions = []
        }
        quiz = RuleRequest(title: title, questions: questions)
    }
}
