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

/// A word laid out in running text in the reader.
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
        // The hold is felt when it starts a phrase, and each word the sweep adds is felt too.
        .sensoryFeedback(trigger: sweeping) { old, new in
            guard let new else { return nil }
            return old == nil ? .impact(weight: .light) : old != new ? .selection : nil
        }
    }

    private func wordView(_ word: TextWord, index: Int) -> some View {
        let isSelected = (sweeping ?? picked)?.contains(index) ?? false
        let font = Theme.french(.title3)
        return VStack(alignment: .leading, spacing: 1) {
            Text(word.marked.map { AttributedString(marked: $0, font: font) } ?? AttributedString(word.plain))
                .font(font)
            Text(word.ipa.isEmpty ? " " : (word.link.isEmpty ? "" : "\(word.link)‿") + word.ipa)
                .font(Theme.ipa)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
        .background(isSelected ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .topLeading) {
            if word.isTied { LiaisonArc().stroke(Color.accentColor, lineWidth: 1.5).frame(width: 15, height: 5).offset(x: -11, y: 24) }
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
