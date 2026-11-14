import FrenchCore
import SwiftUI

/// Transcription of the picked word or phrase, with the ways on from it:
/// the reading rule, the favourites, the word analysis.
struct WordPopover: View {
    let picked: Picked
    /// Called before navigating away, so that the popover closes first.
    let onLeave: () -> Void

    @Environment(Library.self) private var library
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        MarkedText(marked: picked.marked, plain: picked.plain,
                                   size: Theme.frRow.size, weight: Theme.frRow.weight)
                        if let level = library.level(of: picked.word?.fr ?? picked.plain) {
                            LevelTag(level: level)
                        }
                    }
                    if !picked.ipa.isEmpty {
                        Text("[\(picked.ipa)]").font(Theme.ipa(15)).foregroundStyle(Theme.t2)
                    }
                }
                Spacer(minLength: 0)
                SpeakButton(text: picked.plain, kind: .plain)
            }

            if let translation = picked.translation, !translation.isEmpty {
                Text(translation).font(Theme.body)
            }

            if let word = picked.word, let form = library.shortForm(of: word.fr), !form.isEmpty {
                Text(form).font(Theme.subhead).foregroundStyle(Theme.t2)
            }

            if let rule = picked.rule {
                Button {
                    onLeave()
                    navigator.push(.rule(rule.rule))
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Почему так читается").font(Theme.footnote).foregroundStyle(Theme.t3)
                            Text(rule.label).font(Theme.sans(13, .medium, relativeTo: .footnote))
                                .foregroundStyle(Theme.acc)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.acc)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.accSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            actions
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.s2.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.line) }
        .presentationCompactAdaptation(.popover)
        .sensoryFeedback(.success, trigger: store.data.favorites.count)
    }

    @ViewBuilder private var actions: some View {
        if let word = picked.word {
            let isFavorite = store.isFavorite(word.fr)
            HStack(spacing: 8) {
                Button {
                    store.toggleFavorite(library.favorite(word))
                } label: {
                    Label(isFavorite ? "Убрать из избранного" : "В избранное",
                          systemImage: isFavorite ? "star.fill" : "star")
                        .lineLimit(1)
                }
                .buttonStyle(.pill(.outline, small: true))
                .accessibilityIdentifier("favorite-toggle")
                if !library.grammar.analyses(of: word.fr).isEmpty {
                    Button {
                        onLeave()
                        navigator.push(.word(word.fr))
                    } label: {
                        Label("Разбор", systemImage: "book").lineLimit(1)
                    }
                    .buttonStyle(.pill(.primary, small: true))
                }
            }
        }
    }
}
