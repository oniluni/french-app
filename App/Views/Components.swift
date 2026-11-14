import FrenchCore
import SwiftUI

// MARK: - Pronunciation markup

extension AttributedString {
    /// French with pronunciation marks → styled text. The one look used by the reader, cards,
    /// rules and word analysis.
    init(marked: String, size: CGFloat, weight: Theme.Weight = .regular) {
        self.init()
        let font = Theme.sans(size, weight)
        for part in Markup.parse(marked) {
            var run = AttributedString(part.kind == .arc ? "‿" : part.text)
            run.swiftUI.font = font
            switch part.kind {
            case .plain:
                break
            case .silent:
                // Never by colour alone: weight and a dotted underline carry it too.
                run.swiftUI.font = Theme.sans(size, .regular)
                run.swiftUI.foregroundColor = Theme.t3
                run.swiftUI.underlineStyle = Text.LineStyle(pattern: .dot, color: Theme.t3)
            case .nasal:
                run.swiftUI.backgroundColor = Theme.nasal
            case .link:
                run.swiftUI.font = Theme.sans(size, .bold)
                run.swiftUI.foregroundColor = Theme.acc
            case .arc:
                run.swiftUI.foregroundColor = Theme.acc
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
    var size = Theme.frRow.size
    var weight = Theme.frRow.weight

    var body: some View {
        Group {
            if let marked {
                Text(AttributedString(marked: marked, size: size, weight: weight))
            } else {
                Text(plain).font(Theme.sans(size, weight))
            }
        }
        .environment(\.locale, Locale(identifier: "fr"))
    }
}

/// IPA in brackets, in the system face.
struct IPAText: View {
    let ipa: String
    var size: CGFloat = 13
    var isBracketed = true

    var body: some View {
        Text(isBracketed ? "[\(ipa)]" : ipa).font(Theme.ipa(size)).foregroundStyle(Theme.t2).lineLimit(1)
    }
}

// MARK: - Screen and groups

/// A scrolling screen on the app background, with the 16 pt margins of the design.
struct Screen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Room for the floating tab bar.
                .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
    }
}

/// A group of rows: one surface, a line between rows.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    if row.id != rows.first?.id { Theme.line.frame(height: 1) }
                    row
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(radius: 24)
    }
}

extension View {
    /// The opaque content surface: s1, a 1 pt line, no shadow.
    func surface(radius: CGFloat = 24, fill: Color = Theme.s1) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(fill, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.line))
    }

    /// A padded surface for a block that is not a list of rows.
    func panel() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading).surface()
    }

    /// The layout of a row: 56 pt high at least, 16 pt in from the sides.
    func row(minHeight: CGFloat = 56) -> some View {
        frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
    }
}

/// The heading over a group: its name and, on the right, a count or a note.
struct SectionHeader: View {
    let title: String
    var trailing: String?
    /// Counts are mono; a note such as «род: мужской и женский» is sans.
    var trailingMono = true
    var top: CGFloat = 20

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(trailingMono ? Theme.mono(13) : Theme.sans(13, .medium, relativeTo: .footnote))
            }
        }
        .font(Theme.sans(13, .medium, relativeTo: .footnote))
        .foregroundStyle(Theme.t2)
        .padding(.horizontal, 4)
        .padding(.top, top)
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Small text under a group: what it does, where the data comes from.
struct Footer: View {
    let text: String

    var body: some View {
        Text(text).font(Theme.caption1).foregroundStyle(Theme.t3).padding(.horizontal, 4).padding(.top, 8)
    }
}

/// Title, and the lines under it, of a row.
struct RowTitles: View {
    let title: String
    var subtitle: String?
    /// Counts and lesson numbers, in mono.
    var detail: String?
    var subtitleLines = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.bodyMedium).multilineTextAlignment(.leading)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle).font(Theme.subhead).foregroundStyle(Theme.t2).lineLimit(subtitleLines).multilineTextAlignment(.leading)
            }
            if let detail { Text(detail).font(Theme.mono(12)).foregroundStyle(Theme.t3) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.t3).accessibilityHidden(true)
    }
}

/// A row that pushes a screen: its content and a chevron.
struct NavRow<Label: View>: View {
    let route: Route
    @ViewBuilder let label: Label

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                label
                Chevron()
            }
            .row()
        }
        .buttonStyle(RowButtonStyle())
    }
}

/// A row that acts: the pressed row darkens a little.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.t1)
            .background(configuration.isPressed ? Theme.s3 : .clear)
    }
}

// MARK: - Chips

struct Chip: View {
    enum Tone {
        case neutral, level, new, learning, due, known
    }

    let text: String
    var tone = Tone.neutral

    var body: some View {
        Text(text)
            .font(tone == .level ? Theme.mono(11, .medium, relativeTo: .caption2) : Theme.sans(11, .medium, relativeTo: .caption2))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .background(background, in: Capsule())
            .overlay { if tone == .level { Capsule().strokeBorder(Theme.line2) } }
            .fixedSize()
    }

    private var foreground: Color {
        switch tone {
        case .neutral, .level: Theme.t2
        case .new: Theme.acc
        case .learning: Theme.amber
        case .due: Theme.red
        case .known: Theme.green
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: Theme.s3
        case .level: .clear
        case .new: Theme.accSoft
        case .learning: Theme.amberSoft
        case .due: Theme.redSoft
        case .known: Theme.greenSoft
        }
    }
}

/// CEFR level of a word: «A1» … «C2».
struct LevelTag: View {
    let level: String

    var body: some View {
        Chip(text: level, tone: .level).accessibilityLabel("Уровень \(level)")
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

    var tone: Chip.Tone {
        switch self {
        case .new: .new
        case .learning: .learning
        case .due: .due
        case .known: .known
        }
    }
}

/// A filter or a choice of a set in content: «Урок 3», «Présent».
struct FilterChip: View {
    let title: String
    let isOn: Bool
    var isFrench = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(isOn ? Theme.acc : Theme.t2)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(isOn ? Theme.accSoft : Theme.s2, in: Capsule())
                .overlay { if !isOn { Capsule().strokeBorder(Theme.line) } }
                .environment(\.locale, Locale(identifier: isFrench ? "fr" : "ru"))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A segmented choice inside content, without glass.
struct InlineSegments<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(Theme.sans(13, .medium, relativeTo: .footnote))
                        .lineLimit(1)
                        .foregroundStyle(isOn ? Theme.t1 : Theme.t2)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isOn ? Theme.s4 : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.s2, in: Capsule())
    }
}

/// The glass switch that sits in the navigation bar, over the screen.
struct NavSegments<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(Theme.sans(13, .medium, relativeTo: .footnote))
                        .lineLimit(1)
                        .foregroundStyle(isOn ? Theme.t1 : Theme.t2)
                        .padding(.horizontal, 14)
                        .frame(minWidth: 84, minHeight: 36)
                        .background(isOn ? Color(hex: 0x3A3A3E) : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(hex: 0x202024).opacity(0.7), in: Capsule())
        .overlay { Capsule().strokeBorder(.white.opacity(0.14)) }
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}

// MARK: - Buttons

/// The pill buttons of the design. A disabled one goes grey whatever its kind.
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        /// Accent fill: the one main action of a screen.
        case primary
        /// Grey fill.
        case quiet
        /// A line around.
        case outline
        /// Soft accent.
        case tinted
        /// Soft red: replaces data.
        case danger
    }

    let kind: Kind
    var isSmall = false
    var isWide = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(isSmall ? 14 : 16, .semibold, relativeTo: isSmall ? .subheadline : .body))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, isSmall ? 16 : 20)
            .frame(maxWidth: isWide ? .infinity : nil, minHeight: isSmall ? 44 : 50)
            .background(background, in: Capsule())
            .overlay { if kind == .outline && isEnabled { Capsule().strokeBorder(Theme.line2) } }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var foreground: Color {
        guard isEnabled else { return Theme.off }
        switch kind {
        case .primary: return Theme.ink
        case .quiet, .outline: return Theme.t1
        case .tinted: return Theme.acc
        case .danger: return Theme.red
        }
    }

    private var background: Color {
        guard isEnabled else { return Theme.s2 }
        switch kind {
        case .primary: return Theme.acc
        case .quiet: return Theme.s3
        case .outline: return .clear
        case .tinted: return Theme.accSoft
        case .danger: return Theme.redSoft
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind, small: Bool = false, wide: Bool = false) -> PillButtonStyle {
        PillButtonStyle(kind: kind, isSmall: small, isWide: wide)
    }
}

/// A round 44 pt icon button.
struct IconButtonStyle: ButtonStyle {
    enum Kind {
        case outline, filled, on, glass
        /// No circle at all: a speaker in a tight row.
        case plain
    }

    var kind = Kind.outline

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(size: 18))
            .foregroundStyle(kind == .on ? Theme.acc : kind == .plain ? Theme.t2 : Theme.t1)
            .frame(width: 44, height: 44)
            .contentShape(kind == .plain ? AnyShape(Rectangle()) : AnyShape(Circle()))
            .opacity(configuration.isPressed ? 0.6 : 1)
        if kind == .glass {
            label.glassEffect(.regular.interactive(), in: Circle())
        } else if kind == .plain {
            label
        } else {
            label
                .background(kind == .filled ? Theme.s3 : kind == .on ? Theme.accSoft : .clear, in: Circle())
                .overlay { if kind == .outline { Circle().strokeBorder(Theme.line2) } }
        }
    }
}

struct SpeakButton: View {
    /// French, plain or marked.
    let text: String
    var kind = IconButtonStyle.Kind.outline
    @Environment(Speech.self) private var speech

    var body: some View {
        Button {
            speech.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2")
        }
        .buttonStyle(IconButtonStyle(kind: kind))
        .accessibilityLabel("Прослушать: \(Markup.plain(text))")
    }
}

/// The star that adds a word to «Избранное» or takes it out. Sits in the navigation bar.
struct FavoriteButton: View {
    let word: Word
    @Environment(Store.self) private var store
    @Environment(Library.self) private var library

    var body: some View {
        let isFavorite = store.isFavorite(word.fr)
        Button {
            store.toggleFavorite(library.favorite(word))
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star").foregroundStyle(isFavorite ? Theme.acc : Theme.t1)
        }
        .accessibilityLabel(isFavorite ? "Убрать из избранного" : "В избранное")
        .accessibilityIdentifier("favorite-toggle")
        .sensoryFeedback(.success, trigger: isFavorite)
    }
}

// MARK: - Blocks

/// An info or warning note.
struct Callout<Content: View>: View {
    var isWarning = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isWarning ? "exclamationmark.triangle" : "info.circle")
                .font(.system(size: 18))
                .foregroundStyle(isWarning ? Theme.amber : Theme.acc)
                .accessibilityLabel(isWarning ? "Внимание" : "Заметка")
            content.font(Theme.callout).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isWarning ? Theme.amberSoft : Theme.accSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The round icon of an empty state or a summary.
struct EmptyIcon: View {
    let systemImage: String
    var color = Theme.t2
    var fill: Color?
    var size: CGFloat = 64

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.4))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(fill ?? Theme.s2, in: Circle())
            .overlay { if fill == nil { Circle().strokeBorder(Theme.line) } }
            .accessibilityHidden(true)
    }
}

/// Nothing to show yet, or nothing found: what happened and what to do.
struct EmptyState<Actions: View>: View {
    let systemImage: String
    var iconColor = Theme.t2
    var iconFill: Color?
    let title: String
    let text: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 10) {
            EmptyIcon(systemImage: systemImage, color: iconColor, fill: iconFill).padding(.bottom, 6)
            Text(title).font(Theme.title3)
            Text(text).font(Theme.subhead).foregroundStyle(Theme.t2)
            actions.padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

extension EmptyState where Actions == EmptyView {
    init(systemImage: String, iconColor: Color = Theme.t2, iconFill: Color? = nil, title: String, text: String) {
        self.init(systemImage: systemImage, iconColor: iconColor, iconFill: iconFill, title: title, text: text) { EmptyView() }
    }
}

/// A text field of the design: s2, a line that turns accent while typing.
struct FieldBackground: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .font(Theme.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 50)
            .background(Theme.s2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isFocused ? Theme.acc : Theme.line))
    }
}

// MARK: - Progress

/// Progress around a number.
struct ProgressRing<Label: View>: View {
    let progress: Double
    var size: CGFloat = 40
    @ViewBuilder let label: Label

    var body: some View {
        let value = min(max(progress, 0), 1)
        ZStack {
            if value < 1 { Circle().stroke(Theme.s4, lineWidth: 3) }
            Circle().trim(from: 0, to: value)
                .stroke(Theme.acc, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: value)
            label
        }
        .padding(1.5)
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((value * 100).rounded())) %")
    }
}

/// The thin bar of a session.
struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(Theme.s3)
                .overlay(alignment: .leading) {
                    Capsule().fill(Theme.acc).frame(width: geometry.size.width * min(max(value, 0), 1))
                }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.3), value: value)
        .accessibilityElement()
        .accessibilityLabel("Пройдено")
        .accessibilityValue("\(Int((min(max(value, 0), 1) * 100).rounded())) %")
    }
}

// MARK: - Layout and text helpers

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

/// «Урок 3», «Уроки 3–5».
func lessonsTitle(_ range: ClosedRange<Int>) -> String {
    range.count == 1 ? "Урок \(range.lowerBound)" : "Уроки \(range.lowerBound)–\(range.upperBound)"
}

extension String {
    /// A marked or plain word without the punctuation around it: "« imag(es)." → "imag(es)".
    var withoutOuterPunctuation: String {
        let keeps: (Character) -> Bool = { $0.isLetter || $0.isNumber || "()[]{}".contains($0) }
        guard let first = firstIndex(where: keeps), let last = lastIndex(where: keeps) else { return "" }
        return String(self[first...last])
    }
}
