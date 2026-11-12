import FrenchCore
import SwiftUI

extension AttributedString {
    /// French with pronunciation marks → styled text. The one look used by lesson texts, cards,
    /// rules, the reader and word analysis.
    init(marked: String, font: Font) {
        self.init()
        for part in Markup.parse(marked) {
            var run = AttributedString(part.kind == .arc ? "‿" : part.text)
            run.swiftUI.font = font
            switch part.kind {
            case .plain:
                break
            case .silent:
                // Never by colour alone: weight and a dotted underline carry it too.
                run.swiftUI.font = font.weight(.light)
                run.swiftUI.foregroundColor = .secondary
                run.swiftUI.underlineStyle = Text.LineStyle(pattern: .dot, color: .secondary)
            case .nasal:
                run.swiftUI.backgroundColor = Theme.nasal
            case .link:
                run.swiftUI.font = font.weight(.bold)
                run.swiftUI.foregroundColor = .accentColor
            case .arc:
                run.swiftUI.foregroundColor = .accentColor
            }
            append(run)
        }
    }
}

/// French text with its pronunciation marks, or as written when it has none.
struct MarkedText: View {
    let marked: String?
    /// Shown when there are no marks. Never parsed: it may hold brackets of its own.
    var plain = ""
    var style: Font.TextStyle = .body

    var body: some View {
        Group {
            if let marked {
                Text(AttributedString(marked: marked, font: Theme.french(style)))
            } else {
                Text(plain).font(Theme.french(style))
            }
        }
        .environment(\.locale, Locale(identifier: "fr"))
    }
}

struct SpeakButton: View {
    /// French, plain or marked.
    let text: String
    @Environment(Speech.self) private var speech

    var body: some View {
        Button {
            speech.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .frame(minWidth: 28, minHeight: 28)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Прослушать: \(Markup.plain(text))")
    }
}

/// Progress around a number or an icon.
struct ProgressRing<Label: View>: View {
    let progress: Double
    var size: CGFloat = 44
    @ViewBuilder let label: Label

    var body: some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: 4)
            Circle().trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((progress * 100).rounded())) %")
    }
}

/// Lays words out like text: left to right, wrapping to the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 7
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrange(subviews, width: bounds.width).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, CGSize(width: widest, height: y + lineHeight))
    }
}

extension CardStatus {
    var label: String {
        switch self {
        case .new: "Новое"
        case .learning: "Учу"
        case .due: "Пора повторить"
        case .known: "Знаю"
        }
    }

    var color: Color {
        switch self {
        case .new: .secondary
        case .learning: Theme.hard
        case .due: Theme.again
        case .known: Theme.good
        }
    }
}

extension TimeInterval {
    /// "1 мин", "10 мин", "3 ч", "4 дн", "2 мес": how soon a card comes back.
    var shortDelay: String {
        let minutes = self / 60
        if minutes < 60 { return "\(max(1, Int(minutes.rounded()))) мин" }
        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours.rounded())) ч" }
        let days = hours / 24
        if days < 30 { return "\(Int(days.rounded())) дн" }
        return "\(Int((days / 30).rounded())) мес"
    }
}

/// Russian plural: 1 слово, 2 слова, 5 слов.
func plural(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
    let lastTwo = count % 100
    let last = count % 10
    let word = (11...14).contains(lastTwo) ? many : last == 1 ? one : (2...4).contains(last) ? few : many
    return "\(count) \(word)"
}

/// A small label that names the kind of something: «Чтение», «Грамматика».
struct Tag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.accentSoft, in: Capsule())
    }
}

extension String {
    /// A marked or plain word without the punctuation around it: "« imag(es)." → "imag(es)".
    var withoutOuterPunctuation: String {
        let keeps: (Character) -> Bool = { $0.isLetter || $0.isNumber || "()[]{}".contains($0) }
        guard let first = firstIndex(where: keeps), let last = lastIndex(where: keeps) else { return "" }
        return String(self[first...last])
    }
}
