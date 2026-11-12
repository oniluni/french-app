import FrenchCore
import SwiftUI

/// «Справочник»: function words of French by kind, and every rule of the lessons in one place.
struct ReferenceView: View {
    @Environment(Library.self) private var library

    var body: some View {
        List {
            Section("Служебные слова") {
                ForEach(library.reference.categories) { category in
                    NavigationLink(value: Route.category(category.id)) {
                        HStack {
                            Text(category.title)
                            Spacer()
                            Text("\(category.words.count)").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            Section {
                NavigationLink(value: Route.rules) {
                    Label("Правила уроков", systemImage: "text.book.closed")
                }
            } footer: {
                Text("Переводы служебных слов: из уроков, иначе из словаря WikDict. Уровни A1–C2: FLELex.")
            }
        }
        .navigationTitle("Справочник")
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
                    session = SessionRequest(title: category.title, entries: library.content.entries(forWords: category.words.map(\.word)))
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
            Section(plural(category.words.count, "слово", "слова", "слов")) {
                ForEach(category.words, id: \.fr) { word in
                    NavigationLink(value: Route.word(word.fr)) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                MarkedText(marked: word.m, plain: word.fr, style: .title3)
                                if let level = word.level { LevelTag(level: level) }
                            }
                            Text(word.ru).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }
        .fullScreenCover(item: $gaps) { GapSessionView(request: $0) }
    }
}

/// Every rule of every lesson, by kind.
struct AllRulesView: View {
    @Environment(Library.self) private var library

    private static let kinds = ["Произношение", "Чтение", "Грамматика", "Примечания"]

    var body: some View {
        let rules = library.content.lessons.flatMap(\.rules)
        List {
            ForEach(AllRulesView.kinds, id: \.self) { kind in
                Section(kind) {
                    ForEach(rules.filter { $0.kind == kind }) { rule in
                        NavigationLink(value: Route.rule(rule.id)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rule.title).font(.subheadline.weight(.semibold))
                                Text("Урок \(rule.lesson) · \(rule.summary)").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Правила уроков")
        .navigationBarTitleDisplayMode(.inline)
    }
}
