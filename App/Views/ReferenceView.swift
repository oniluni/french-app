import FrenchCore
import SwiftUI

/// «Справочник»: the rules of the lessons and the function words, by kind.
struct ReferenceView: View {
    @Environment(Library.self) private var library

    var body: some View {
        Screen {
            VStack(spacing: 0) {
                SectionHeader(title: "Правила уроков", top: 4)
                Card {
                    ForEach(AllRulesView.kinds, id: \.self) { kind in
                        let count = library.content.lessons.flatMap(\.rules).filter { $0.kind == kind }.count
                        NavigationLink(value: Route.rules(kind)) {
                            row(title: kind, subtitle: nil, count: count)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach(library.reference.sections, id: \.self) { section in
                    let categories = library.reference.categories.filter { $0.section == section }
                    if !categories.isEmpty {
                        SectionHeader(title: section)
                        Card {
                            ForEach(categories) { category in
                                NavigationLink(value: Route.category(category.id)) {
                                    row(title: category.title,
                                        subtitle: category.section == "Выражения"
                                            ? category.words.prefix(2).map(\.fr).joined(separator: ", ")
                                            : nil,
                                        count: category.words.count)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Справочник")
    }

    private func row(title: String, subtitle: String?, count: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.bodyMedium)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(Theme.sans(14)).foregroundStyle(Theme.t2)
                }
            }
            Spacer(minLength: 0)
            Text("\(count)").font(Theme.mono(13)).foregroundStyle(Theme.t2)
            Chevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// One kind of function word or expression: its cards, its gap drill and its words.
struct CategoryView: View {
    let category: ReferenceCategory

    @Environment(Library.self) private var library

    @State private var session: SessionRequest?
    @State private var gaps: GapRequest?

    var body: some View {
        Screen {
            VStack(spacing: 0) {
                Card {
                    Button(action: teach) {
                        actionRow("Учить карточками", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Учить карточками")
                    if !(category.gaps ?? []).isEmpty {
                        Button(action: fillGap) {
                            actionRow("Вставь слово", systemImage: "rectangle.and.pencil.and.ellipsis")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Вставь слово")
                    }
                }

                if category.id == "verb-prepositions" {
                    let withA = category.words.filter { $0.fr.hasSuffix(" à") }
                    let withDe = category.words.filter { $0.fr.hasSuffix(" de") }
                    wordSection(title: "с предлогом à", words: withA)
                    wordSection(title: "с предлогом de", words: withDe)
                } else {
                    wordSection(title: countTitle(category.words.count), words: category.words)
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }
        .fullScreenCover(item: $gaps) { GapSessionView(request: $0) }
    }

    private func actionRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).font(.system(size: 17))
            Text(title).font(Theme.sans(16, .medium))
            Spacer(minLength: 0)
            Chevron().foregroundStyle(Theme.acc)
        }
        .foregroundStyle(Theme.acc)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func teach() {
        let words = category.words.map { $0.word(reader: library.reader) }
        session = SessionRequest(title: category.title,
                                 entries: library.content.entries(forWords: words))
    }

    private func fillGap() {
        var generator = SystemRandomNumberGenerator()
        let questions = GapFill.questions(from: category, count: 10, using: &generator)
        if !questions.isEmpty {
            gaps = GapRequest(title: category.title, questions: questions)
        }
    }

    @ViewBuilder private func wordSection(title: String, words: [ReferenceWord]) -> some View {
        if !words.isEmpty {
            SectionHeader(title: title, trailing: title.hasPrefix("с предлогом") ? "\(words.count)" : nil)
            Card {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    wordRow(word)
                }
            }
        }
    }

    @ViewBuilder private func wordRow(_ word: ReferenceWord) -> some View {
        if word.fr.contains(" ") {
            HStack(alignment: .center, spacing: 8) {
                wordText(word)
                SpeakButton(text: word.m ?? word.fr, kind: .plain)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        } else {
            NavigationLink(value: Route.word(word.fr)) {
                HStack(spacing: 12) {
                    wordText(word)
                    Chevron()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func wordText(_ word: ReferenceWord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MarkedText(marked: word.m, plain: word.fr, size: 19, weight: .medium)
                if let ipa = word.ipa, !ipa.isEmpty {
                    Text("[\(ipa)]").font(Theme.ipa(13)).foregroundStyle(Theme.t2)
                }
                if let level = word.level {
                    LevelTag(level: level)
                }
            }
            Text(word.ru).font(Theme.subhead).foregroundStyle(Theme.t2)
            if let use = word.use, !use.isEmpty {
                Text(use).font(Theme.caption1.weight(.medium)).foregroundStyle(Theme.t3)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func countTitle(_ count: Int) -> String {
        category.section == "Выражения"
            ? plural(count, "выражение", "выражения", "выражений")
            : plural(count, "слово", "слова", "слов")
    }
}

/// All rules of one kind, grouped by lesson.
struct AllRulesView: View {
    let kind: String

    @Environment(Library.self) private var library

    static let kinds = ["Грамматика", "Произношение", "Чтение", "Примечания"]

    var body: some View {
        Screen {
            VStack(spacing: 0) {
                ForEach(library.content.lessons) { lesson in
                    let rules = lesson.rules.filter { $0.kind == kind }
                    if !rules.isEmpty {
                        SectionHeader(title: "Урок \(lesson.id)", trailing: "\(rules.count)")
                        Card {
                            ForEach(rules) { rule in
                                NavigationLink(value: Route.rule(rule.id)) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(rule.title).font(Theme.bodyMedium)
                                            if !rule.summary.isEmpty {
                                                Text(rule.summary)
                                                    .font(Theme.subhead)
                                                    .foregroundStyle(Theme.t2)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        Chevron()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
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
