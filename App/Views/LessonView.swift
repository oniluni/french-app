import FrenchCore
import SwiftUI

/// One lesson: its rules and its words. The vault keeps no lesson texts.
struct LessonView: View {
    let lesson: Lesson

    private enum Part: String, CaseIterable {
        case rules = "Правила", words = "Слова"
    }

    /// Kinds in the order the lesson lists them; a kind outside this list goes last.
    private static let kinds = ["Произношение", "Чтение", "Грамматика", "Примечания"]

    @Environment(Store.self) private var store
    @State private var part = Part.rules
    @State private var session: SessionRequest?

    var body: some View {
        Screen {
            switch part {
            case .rules: rules
            case .words: words
            }
        }
        .navigationTitle("Урок \(lesson.id)")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Раздел урока", selection: $part) {
                    ForEach(Part.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 180)
            }
        }
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }
        .onAppear {
            if store.data.lastLesson != lesson.id { store.update { $0.lastLesson = lesson.id } }
        }
    }

    @ViewBuilder private var rules: some View {
        Text(lesson.topic).font(Theme.subhead).foregroundStyle(Theme.t2).padding(.horizontal, 4)
        let kinds = LessonView.kinds + Set(lesson.rules.map(\.kind)).subtracting(LessonView.kinds).sorted()
        ForEach(kinds, id: \.self) { kind in
            let rules = lesson.rules.filter { $0.kind == kind }
            if !rules.isEmpty {
                SectionHeader(title: kind, trailing: "\(rules.count)")
                Card {
                    ForEach(rules) { rule in
                        NavRow(route: .rule(rule.id)) {
                            // A rule that is only a table has no summary.
                            RowTitles(title: rule.title, subtitle: rule.summary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var words: some View {
        let entries = lesson.entries
        let statuses = entries.map { store.status(of: $0) }
        Button {
            session = SessionRequest(title: "Урок \(lesson.id)", entries: entries)
        } label: {
            Label("Учить слова урока", systemImage: "rectangle.stack")
        }
        .buttonStyle(.pill(.primary, wide: true))
        Text(([plural(entries.count, "слово", "слова", "слов")]
              + countLabel(statuses.filter { $0 == .new }.count, "новое", "новых", "новых")
              + countLabel(statuses.filter { $0 == .due }.count, "пора повторить", "пора повторить", "пора повторить"))
            .joined(separator: " · "))
            .font(Theme.caption1)
            .foregroundStyle(Theme.t3)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        ForEach(Word.groups, id: \.self) { group in
            let members = entries.filter { $0.word.group == group }
            if !members.isEmpty {
                SectionHeader(title: group, trailing: "\(members.count)")
                Card {
                    ForEach(members) { entry in
                        NavigationLink(value: Route.word(entry.word.fr)) { WordRow(entry: entry) }
                            .buttonStyle(RowButtonStyle())
                    }
                }
            }
        }
    }

    /// «31 новое», or nothing for none.
    private func countLabel(_ count: Int, _ one: String, _ few: String, _ many: String) -> [String] {
        count == 0 ? [] : [plural(count, one, few, many)]
    }
}

/// A vocabulary entry in a list: the word with its marks, the sound, the translation, the card status.
struct WordRow: View {
    let entry: Entry
    @Environment(Store.self) private var store

    var body: some View {
        let status = store.status(of: entry)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                MarkedText(marked: entry.word.m, plain: entry.word.fr)
                if !entry.word.ipa.isEmpty { IPAText(ipa: entry.word.ipa, isBracketed: false) }
                Text(entry.word.ru).font(Theme.subhead).foregroundStyle(Theme.t2).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Chip(text: status.label, tone: status.tone)
        }
        .row()
    }
}
