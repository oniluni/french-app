import FrenchCore
import SwiftUI

/// Transcription of the picked word or phrase, with the ways on from it:
/// the reading rule, the cards, the word analysis, a note.
struct WordPopover: View {
    let picked: Picked
    /// Nil where notes do not apply (the reader).
    var onNote: (() -> Void)?
    /// Called before navigating away, so that the popover closes first.
    let onLeave: () -> Void

    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    MarkedText(marked: picked.marked, plain: picked.plain, style: .title2)
                    if !picked.ipa.isEmpty { Text("[\(picked.ipa)]").font(Theme.ipa).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                SpeakButton(text: picked.plain)
            }

            if let translation = picked.translation, !translation.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if picked.isPhrase { caption("Перевод предложения") }
                    Text(translation).font(.subheadline)
                }
            }

            if let rule = picked.rule {
                Button {
                    onLeave()
                    navigator.push(.rule(rule.rule))
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            caption("Почему так читается")
                            Text(rule.label).font(.subheadline).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            actions
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
        .sensoryFeedback(.success, trigger: store.data.favorites.count)
    }

    @ViewBuilder private var actions: some View {
        let word = picked.word
        let hasForms = word.map { !library.grammar.analyses(of: $0.fr).isEmpty } ?? false
        if word != nil || onNote != nil {
            HStack(spacing: 8) {
                if let word {
                    let isFavorite = store.isFavorite(word.fr)
                    Button {
                        store.toggleFavorite(library.favorite(word))
                    } label: {
                        Label(isFavorite ? "В избранном" : "В избранное", systemImage: isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityIdentifier("favorite-toggle")
                    if hasForms {
                        Button {
                            onLeave()
                            navigator.push(.word(word.fr))
                        } label: { Label("Разбор", systemImage: "book") }
                    }
                }
                if let onNote {
                    Button(action: onNote) { Label("Заметка", systemImage: "note.text") }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }
}
