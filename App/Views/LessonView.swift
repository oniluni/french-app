import FrenchCore
import SwiftUI

/// One lesson: its rules and its words. The vault keeps no lesson texts.
struct LessonView: View {
    let lesson: Lesson

    private enum Part: String, CaseIterable {
        case rules = "Правила", words = "Слова"
    }

    @Environment(Store.self) private var store
    @State private var part = Part.rules
    @State private var session: SessionRequest?

    var body: some View {
        Group {
            switch part {
            case .rules: rules
            case .words: words
            }
        }
        .navigationTitle("Урок \(lesson.id)")
        .navigationBarTitleDisplayMode(.inline)
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

    private var rules: some View {
        List {
            Section {
                ForEach(lesson.rules) { rule in
                    NavigationLink(value: Route.rule(rule.id)) {
                        VStack(alignment: .leading, spacing: 5) {
                            Tag(text: rule.kind)
                            Text(rule.title).font(.headline)
                            // A rule that is only a table has no summary.
                            if !rule.summary.isEmpty { Text(rule.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                Text(lesson.topic).textCase(nil)
            }
        }
    }

    private var words: some View {
        List {
            Section {
                Button {
                    session = SessionRequest(title: "Урок \(lesson.id)", entries: lesson.entries)
                } label: {
                    Label("Учить слова урока", systemImage: "rectangle.on.rectangle.angled")
                }
            }
            Section(plural(lesson.words.count, "слово", "слова", "слов")) {
                ForEach(lesson.entries) { entry in
                    NavigationLink(value: Route.word(entry.word.fr)) {
                        WordRow(entry: entry)
                    }
                }
            }
        }
    }
}

/// A vocabulary entry in a list: the word with its marks, the translation, the sound, the card status.
struct WordRow: View {
    let entry: Entry
    @Environment(Store.self) private var store

    var body: some View {
        let status = store.status(of: entry)
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                MarkedText(marked: entry.word.m, plain: entry.word.fr, style: .title3)
                Spacer(minLength: 8)
                Text(status.label).font(.caption.weight(.medium)).foregroundStyle(status.color)
            }
            Text(entry.word.ru).font(.subheadline).foregroundStyle(.secondary)
            if !entry.word.ipa.isEmpty {
                Text("[\(entry.word.ipa)]").font(Theme.ipa).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
