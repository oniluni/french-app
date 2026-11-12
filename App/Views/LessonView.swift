import FrenchCore
import SwiftUI

/// One lesson: its text, its rules and its words.
struct LessonView: View {
    let lesson: Lesson

    private enum Part: String, CaseIterable {
        case text = "Текст", rules = "Правила", words = "Слова"
    }

    @Environment(Store.self) private var store
    @State private var part = Part.text
    @State private var session: SessionRequest?
    /// One setting for every lesson, as the pronunciation layer is a way of reading, not a property of a text.
    @AppStorage("showsPronunciation") private var showsPronunciation = true

    var body: some View {
        Group {
            switch part {
            case .text: LessonTextView(lesson: lesson, showsPronunciation: showsPronunciation)
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
                .frame(minWidth: 230)
            }
            if part == .text {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $showsPronunciation) {
                        Text("[ə]").font(.body.weight(.semibold))
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel("Произношение")
                    .accessibilityIdentifier("pronunciation-toggle")
                }
            }
        }
        .fullScreenCover(item: $session) { CardSessionView(request: $0) }
        .sensoryFeedback(.selection, trigger: showsPronunciation)
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
                            Text(rule.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
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

/// The text of a lesson: sections of phrases, each word with its marks and sound.
struct LessonTextView: View {
    let lesson: Lesson
    let showsPronunciation: Bool

    @Environment(Store.self) private var store
    @State private var notes: NotesRequest?

    private var target: String { "text-\(lesson.id)" }

    var body: some View {
        let lessonNotes = store.notes(for: target)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text(lesson.topic).font(.subheadline).foregroundStyle(.secondary)
                ForEach(Array(lesson.sections.enumerated()), id: \.offset) { sectionIndex, section in
                    SectionHeader(section: section)
                    ForEach(Array(section.items.enumerated()), id: \.offset) { itemIndex, item in
                        switch item {
                        case .sentence(let sentence):
                            SentenceView(
                                sentence: sentence, showsPronunciation: showsPronunciation,
                                noted: lessonNotes.compactMap(\.fragment).filter { $0.section == sectionIndex && $0.item == itemIndex }.map { $0.first...$0.last },
                                onNote: { quote, range in
                                    notes = NotesRequest(target: target, title: "Урок \(lesson.id), текст",
                                        fragment: .init(quote: quote, section: sectionIndex, item: itemIndex, first: range.lowerBound, last: range.upperBound))
                                })
                        case .block(let block):
                            BlocksView(blocks: [block])
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 88)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            NotesButton(count: lessonNotes.count) { notes = NotesRequest(target: target, title: "Урок \(lesson.id), текст", fragment: nil) }
        }
        .sheet(item: $notes) { NotesSheet(request: $0) }
    }
}

private struct SectionHeader: View {
    let section: TextSection

    var body: some View {
        let spoken = section.items.compactMap { item -> String? in
            if case .sentence(let sentence) = item { return sentence.tokens.map(\.plain).joined(separator: " ") }
            return nil
        }
        HStack(alignment: .firstTextBaseline) {
            Text(section.title).font(.title2.bold())
            Spacer()
            if !spoken.isEmpty { SpeakButton(text: spoken.joined(separator: " ")) }
        }
        .padding(.top, 10)
    }
}
