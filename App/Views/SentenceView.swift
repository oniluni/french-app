import FrenchCore
import SwiftUI

/// What the transcription popover shows for one word or a run of words.
struct Picked: Identifiable {
    let range: ClosedRange<Int>
    /// With pronunciation marks, ties included. Nil when a word of it has no marks.
    let marked: String?
    let plain: String
    let ipa: String
    /// Translation of the word, or of the sentence for a phrase.
    let translation: String?
    let isPhrase: Bool
    let rule: ReadingRule?
    /// Sound and marks of the single word, for adding it to the cards.
    let word: Word?

    var id: String { "\(range.lowerBound)-\(range.upperBound)-\(plain)" }
}

/// A word laid out in running text, the same in lesson texts and in the reader.
struct TextWord: Equatable {
    /// Nil for a word without marks; `plain` is shown instead.
    let marked: String?
    let plain: String
    let ipa: String
    let link: String
    let isTied: Bool
}

/// Words that can be tapped (one word) or held and swept (a phrase).
/// Holding first leaves a plain vertical swipe to the scroll view.
struct SelectableWords: View {
    let words: [TextWord]
    let showsPronunciation: Bool
    /// Ranges of words that have a note.
    var noted: [ClosedRange<Int>] = []
    /// Words currently shown in the popover.
    let picked: ClosedRange<Int>?
    let onPick: (ClosedRange<Int>, CGRect) -> Void

    @State private var frames = Frames()
    @State private var sweeping: ClosedRange<Int>?
    @Namespace private var space

    /// Word frames are only read when a touch arrives, so they must not invalidate the view.
    private final class Frames {
        var byIndex: [Int: CGRect] = [:]
    }

    var body: some View {
        FlowLayout {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                wordView(word, index: index)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { frames.byIndex[index] = $0 }
            }
        }
        .coordinateSpace(.named(space))
        .contentShape(Rectangle())
        .gesture(sweep)
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .named(space)).onEnded { tap in
            if let index = index(at: tap.location) { pick(index...index) }
        })
        .environment(\.locale, Locale(identifier: "fr"))
    }

    private func wordView(_ word: TextWord, index: Int) -> some View {
        let isSelected = (sweeping ?? picked)?.contains(index) ?? false
        let hasNote = noted.contains { $0.contains(index) }
        let font = Theme.french(.title3)
        return VStack(alignment: .leading, spacing: 1) {
            Text(showsPronunciation ? word.marked.map { AttributedString(marked: $0, font: font) } ?? AttributedString(word.plain) : AttributedString(word.plain))
                .font(font)
            if showsPronunciation {
                Text(word.ipa.isEmpty ? " " : (word.link.isEmpty ? "" : "\(word.link)‿") + word.ipa)
                    .font(Theme.ipa)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
        .background(isSelected ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .bottom) {
            if hasNote { Rectangle().fill(Color.accentColor).frame(height: 2).offset(y: 3) }
        }
        .overlay(alignment: .topLeading) {
            if showsPronunciation, word.isTied { LiaisonArc().stroke(Color.accentColor, lineWidth: 1.5).frame(width: 15, height: 5).offset(x: -11, y: 24) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word.plain)
        .accessibilityValue(word.ipa)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pick(index...index) }
    }

    private var sweep: some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(space)))
            .onChanged { value in
                guard case .second(true, let drag?) = value, let start = index(at: drag.startLocation) else { return }
                let end = index(at: drag.location) ?? sweeping.map { $0.lowerBound == start ? $0.upperBound : $0.lowerBound } ?? start
                sweeping = min(start, end)...max(start, end)
            }
            .onEnded { _ in
                if let sweeping { pick(sweeping) }
                sweeping = nil
            }
    }

    private func index(at point: CGPoint) -> Int? {
        frames.byIndex.first { $0.value.insetBy(dx: -4, dy: -5).contains(point) }?.key
    }

    private func pick(_ range: ClosedRange<Int>) {
        let rect = range.compactMap { frames.byIndex[$0] }.reduce(CGRect.null) { $0.union($1) }
        onPick(range, rect.isNull ? .zero : rect)
    }
}

/// The small arc under the gap between two words said together.
private struct LiaisonArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        return path
    }
}

/// One sentence of a lesson text, with its translation and explanation folded under it.
struct SentenceView: View {
    let sentence: Sentence
    let showsPronunciation: Bool
    let noted: [ClosedRange<Int>]
    /// Called with the quoted fragment and its word range when the learner asks for a note.
    let onNote: (String, ClosedRange<Int>) -> Void

    @Environment(Library.self) private var library
    @State private var picked: Picked?
    @State private var anchor = CGRect.zero
    @State private var showsTranslation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let speaker = sentence.speaker, !speaker.isEmpty, speaker != "—" {
                Text(speaker).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            SelectableWords(
                words: sentence.tokens.map { TextWord(marked: $0.marked, plain: $0.plain, ipa: $0.ipa ?? "", link: $0.link ?? "", isTied: $0.isTied) },
                showsPronunciation: showsPronunciation, noted: noted, picked: picked?.range
            ) { range, rect in
                anchor = rect
                picked = pickedWords(range)
            }
            .popover(item: $picked, attachmentAnchor: .rect(.rect(anchor))) { item in
                WordPopover(picked: item, onNote: {
                    picked = nil
                    onNote(item.plain, item.range)
                }, onLeave: { picked = nil })
            }
            if !showsPronunciation, let ipa = sentence.ipa {
                Text("[\(ipa)]").font(Theme.ipa).foregroundStyle(.secondary)
            }
            DisclosureGroup(isExpanded: $showsTranslation) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(sentence.ru).frame(maxWidth: .infinity, alignment: .leading)
                    if let note = sentence.note { BlocksView(blocks: note).font(.subheadline) }
                }
                .padding(.top, 6)
            } label: {
                Text("Перевод").font(.subheadline)
            }
            .tint(.secondary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func pickedWords(_ range: ClosedRange<Int>) -> Picked {
        let tokens = Array(sentence.tokens[range])
        let joined: (KeyPath<Token, String?>) -> String? = { path in
            let parts = tokens.map { $0[keyPath: path] }
            guard parts.allSatisfy({ $0 != nil }) else { return nil }
            return tokens.indices.map { index in (index == 0 ? "" : tokens[index].isTied ? "‿" : " ") + (parts[index] ?? "") }.joined()
        }
        let marked = joined(\.marked)?.withoutOuterPunctuation
        let plain = tokens.map(\.plain).joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        let ipa = tokens.enumerated().map { index, token in (index > 0 && token.link != nil ? "\(token.link ?? "")‿" : "") + (token.ipa ?? "…") }.joined(separator: " ")
        guard tokens.count == 1, let token = tokens.first else {
            return Picked(range: range, marked: marked, plain: plain, ipa: ipa, translation: sentence.ru, isPhrase: true, rule: nil, word: nil)
        }
        let rule = token.rule.flatMap { library.content.readingRules.indices.contains($0) ? library.content.readingRules[$0] : nil }
        return Picked(
            range: range, marked: marked, plain: plain, ipa: token.ipa ?? "", translation: token.gloss, isPhrase: false, rule: rule,
            word: Word(fr: plain, m: marked, ipa: token.ipa ?? "", ru: token.gloss ?? ""))
    }
}
