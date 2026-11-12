import FrenchCore
import SwiftUI

/// Which notes to show, and the fragment a new note would be attached to.
struct NotesRequest: Identifiable {
    /// `text-5` for the text of lesson 5, `rule-5-3` for a rule.
    let target: String
    let title: String
    let fragment: Note.Fragment?

    var id: String { "\(target)-\(fragment?.quote ?? "")" }
}

/// The small round button in the corner of a text or a rule, with the number of notes on it.
struct NotesButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "note.text")
                .font(.title3)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.accentColor, in: Capsule())
                    .offset(x: 4, y: -4)
            }
        }
        .padding(16)
        .accessibilityLabel(count == 0 ? "Заметки" : "Заметки: \(count)")
        .accessibilityIdentifier("notes-button")
    }
}

/// Notes on one lesson text or one rule.
struct NotesSheet: View {
    let request: NotesRequest

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isWriting: Bool

    var body: some View {
        let notes = store.notes(for: request.target)
        NavigationStack {
            List {
                Section {
                    if let fragment = request.fragment {
                        Text("«\(fragment.quote)»").font(Theme.french(.body)).italic().foregroundStyle(.secondary)
                    }
                    TextField("Новая заметка", text: $draft, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($isWriting)
                        .accessibilityIdentifier("note-field")
                }
                Section {
                    if notes.isEmpty {
                        Text("Заметок пока нет. Запишите, что хотите запомнить или спросить на занятии.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            if let fragment = note.fragment {
                                Text("«\(fragment.quote)»").font(Theme.french(.subheadline)).italic().foregroundStyle(.secondary)
                            }
                            Text(note.text)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { store.delete(notes[index]) }
                    }
                }
            }
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.addNote(draft.trimmingCharacters(in: .whitespacesAndNewlines), to: request.target, fragment: request.fragment)
                        draft = ""
                        if request.fragment != nil { dismiss() }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(trigger: store.notes(for: request.target).count) { old, new in new > old ? .success : nil }
        .onAppear { isWriting = request.fragment != nil }
    }
}

/// A rule of a lesson: what it is about, the explanation, examples that can be heard.
struct RuleView: View {
    let rule: Rule

    @Environment(Store.self) private var store
    @State private var notes: NotesRequest?

    private var target: String { "rule-\(rule.id)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Tag(text: rule.kind)
                Text(rule.title).font(.title2.bold())
                BlocksView(blocks: rule.blocks)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 88)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Урок \(rule.lesson)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            NotesButton(count: store.notes(for: target).count) { notes = NotesRequest(target: target, title: rule.title, fragment: nil) }
        }
        .sheet(item: $notes) { NotesSheet(request: $0) }
    }
}
