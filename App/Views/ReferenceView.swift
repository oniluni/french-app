import FrenchCore
import SwiftUI

/// «Справочник»: every rule of the lessons by kind, function words of French by kind, and
/// kinds of expression.
struct ReferenceView: View {
    @Environment(Library.self) private var library

    var body: some View {
        let rules = library.content.lessons.flatMap(\.rules)
        List {
            Section("Правила уроков") {
                ForEach(AllRulesView.kinds, id: \.self) { kind in
                    NavigationLink(value: Route.rules(kind)) {
                        row(kind, count: rules.filter { $0.kind == kind }.count)
                    }
                }
            }
            ForEach(library.reference.sections, id: \.self) { section in
                Section {
                    ForEach(library.reference.categories.filter { $0.section == section }) { category in
                        NavigationLink(value: Route.category(category.id)) {
                            row(category.title, count: category.words.count)
                        }
                    }
                } header: {
                    Text(section)
                } footer: {
                    if section == library.reference.sections.last {
                        Text("Переводы и пояснения к служебным словам и выражениям составлены для справочника; остальные переводы — из уроков, иначе из словаря WikDict. Уровни A1–C2: FLELex.")
                    }
                }
            }
        }
        .navigationTitle("Справочник")
    }

    private func row(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
        }
    }
}

/// One kind of function word: its words, cards for them and, for prepositions and conjunctions,
/// sentences with a gap to fill.
struct CategoryView: View {
    let category: ReferenceCategory

    @Environment(Library.self) private var library
    @State private var session: SessionRequest?
    @State private var gaps: GapRequest?

    var body: some View {
        List {
            Section {
                Button {
                    let words = category.words.map { $0.word(reader: library.reader) }
                    session = SessionRequest(title: category.title, entries: library.content.entries(forWords: words))
                } label: {
                    Label("Учить карточками", systemImage: "rectangle.on.rectangle.angled")
                }
                if category.gaps?.isEmpty == false {
                    Button {
                        var generator = SystemRandomNumberGenerator()
                        let questions = GapFill.questions(from: category, count: 10, using: &generator)
                        if !questions.isEmpty { gaps = GapRequest(title: category.title, questions: questions) }
                    } label: {
                        Label("Вставь слово", systemImage: "text.badge.checkmark")
                    }
                }
            }
            Section(category.pos == nil ? plural(category.words.count, "выражение", "выражения", "выражений") : plural(category.words.count, "слово", "слова", "слов")) {
                ForEach(category.words, id: \.fr) { word in
                    let card = word.word(reader: library.reader)
                    // A phrase the dictionary lacks as a whole ("tout à fait") has no analysis to open: it is
                    // heard instead. Asked of the grammar, it would answer for its last word.
                    if library.lexicon.entry(for: word.fr)?.analyses.isEmpty ?? true {
                        HStack(alignment: .top) {
                            label(word, marked: card.m)
                            Spacer()
                            SpeakButton(text: word.fr)
                        }
                    } else {
                        NavigationLink(value: Route.word(word.fr)) { label(word, marked: card.m) }
                    }
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }
        .fullScreenCover(item: $gaps) { GapSessionView(request: $0) }
    }

    /// The word, its translation and what it is for.
    private func label(_ word: ReferenceWord, marked: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MarkedText(marked: marked, plain: word.fr, style: .title3)
                if let level = word.level { LevelTag(level: level) }
            }
            Text(word.ru).font(.subheadline).foregroundStyle(.secondary)
            if let use = word.use {
                Text(use).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Every rule of the lessons of one kind, by lesson.
struct AllRulesView: View {
    let kind: String

    @Environment(Library.self) private var library

    static let kinds = ["Грамматика", "Произношение", "Чтение", "Примечания"]

    var body: some View {
        List {
            ForEach(library.content.lessons) { lesson in
                let rules = lesson.rules.filter { $0.kind == kind }
                if !rules.isEmpty {
                    Section("Урок \(lesson.id)") {
                        ForEach(rules) { rule in
                            NavigationLink(value: Route.rule(rule.id)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rule.title).font(.subheadline.weight(.semibold))
                                    if !rule.summary.isEmpty { Text(rule.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(kind)
        .navigationBarTitleDisplayMode(.inline)
    }
}
