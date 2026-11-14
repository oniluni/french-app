import FrenchCore
import SwiftUI

/// Which notes to show.
struct NotesRequest: Identifiable {
    /// `rule-5-r3` for a rule. Notes kept for lesson texts (`text-5`) or for rules of the vault's
    /// earlier layout (`rule-5-3`) stay in the backup but have nowhere to be shown.
    let target: String
    let title: String
    let lesson: Int

    var id: String { target }
}

/// The round glass button in the corner of a rule, with the number of notes on it.
struct NotesButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
                .foregroundStyle(Theme.t1)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                Text("\(count)")
                    .font(Theme.mono(11, .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Theme.acc, in: Capsule())
                    .offset(x: 3, y: -3)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        .accessibilityLabel(count == 0 ? "Заметки" : "Заметки: \(count)")
        .accessibilityIdentifier("notes-button")
    }
}

/// Notes on one rule.
struct NotesSheet: View {
    let request: NotesRequest

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isTyping: Bool

    private static let date: Date.FormatStyle = .dateTime.day().month(.wide).hour().minute().locale(Locale(identifier: "ru"))

    var body: some View {
        let notes = store.notes(for: request.target)
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Заметки").font(Theme.title2)
                        if !notes.isEmpty { Text("\(notes.count)").font(Theme.mono(16)).foregroundStyle(Theme.t2) }
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(IconButtonStyle(kind: .filled))
                        .accessibilityLabel("Закрыть")
                }
                Text("\(request.title) · урок \(request.lesson)").font(Theme.subhead).foregroundStyle(Theme.t2)

                if notes.isEmpty {
                    EmptyState(systemImage: "square.and.pencil", title: "Заметок пока нет",
                               text: "Запишите, что хотите запомнить об этом правиле.")
                        .padding(.vertical, -12)
                } else {
                    VStack(spacing: 8) {
                        ForEach(notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text).font(Theme.callout)
                                Text(note.created.formatted(NotesSheet.date)).font(Theme.caption1).foregroundStyle(Theme.t3)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .surface(radius: 18, fill: Theme.s2)
                            .contextMenu {
                                Button("Удалить заметку", systemImage: "trash", role: .destructive) { store.delete(note) }
                            }
                        }
                    }
                    .padding(.top, 16)
                }

                Text("Новая заметка").font(Theme.footnote).foregroundStyle(Theme.t2).padding(.leading, 4).padding(.top, 16).padding(.bottom, 8)
                TextField("Что стоит запомнить", text: $draft, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($isTyping)
                    .modifier(FieldBackground(isFocused: isTyping))
                    .accessibilityIdentifier("note-field")
                Button {
                    store.addNote(text, to: request.target)
                    draft = ""
                } label: {
                    Text("Сохранить")
                }
                .buttonStyle(.pill(.primary, wide: true))
                .disabled(text.isEmpty)
                .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(40)
        .sensoryFeedback(trigger: notes.count) { old, new in new > old ? .success : nil }
    }
}

/// A rule of a lesson: its kind, title and text, and the notes on it.
struct RuleView: View {
    let rule: Rule

    @Environment(Store.self) private var store
    @State private var notes: NotesRequest?

    private var target: String { "rule-\(rule.id)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Chip(text: rule.kind)
                Text(rule.title).font(Theme.title1).padding(.top, 8).padding(.bottom, 16)
                BlocksView(blocks: rule.blocks)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(Theme.bg)
        .navigationTitle("Урок \(rule.lesson)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            NotesButton(count: store.notes(for: target).count) {
                notes = NotesRequest(target: target, title: rule.title, lesson: rule.lesson)
            }
        }
        .sheet(item: $notes) { NotesSheet(request: $0) }
    }
}
