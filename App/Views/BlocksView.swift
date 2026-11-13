import FrenchCore
import SwiftUI

/// Formatted lesson text: paragraphs, lists, tables and callouts of a rule or an explanation.
struct BlocksView: View {
    let blocks: [Block]
    @Environment(Speech.self) private var speech

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                BlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // French examples are links with the scheme "speak": tapping one reads it aloud.
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == InlineText.speakScheme,
                  let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value else { return .systemAction }
            speech.speak(text)
            return .handled
        })
    }
}

private struct BlockView: View {
    let block: Block

    var body: some View {
        switch block {
        case .heading(_, let md):
            InlineText(md: md).font(.headline).padding(.top, 4)
        case .paragraph(let md):
            InlineText(md: md)
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(ordered ? "\(index + 1)." : "•").foregroundStyle(.secondary).monospacedDigit()
                        VStack(alignment: .leading, spacing: 8) {
                            InlineText(md: item.md)
                            if !item.blocks.isEmpty { BlocksView(blocks: item.blocks) }
                        }
                    }
                }
            }
        case .table(let head, let rows):
            TableView(head: head, rows: rows)
        case .callout(let kind, let title, let blocks):
            VStack(alignment: .leading, spacing: 10) {
                if !title.isEmpty {
                    Label(title, systemImage: kind == "warning" ? "exclamationmark.triangle" : "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(kind == "warning" ? Theme.hard : Color.accentColor)
                }
                BlocksView(blocks: blocks)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        case .divider:
            Divider()
        }
    }
}

/// A table wider than the screen scrolls sideways instead of squeezing its columns.
private struct TableView: View {
    let head: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    ForEach(Array(head.enumerated()), id: \.offset) { _, cell in
                        InlineText(md: cell).font(.subheadline.weight(.semibold))
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    // A wrapped cell would otherwise read as two rows.
                    if index > 0 { Divider().opacity(0.5) }
                    GridRow(alignment: .firstTextBaseline) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            InlineText(md: cell).frame(maxWidth: 260, alignment: .leading)
                        }
                    }
                }
            }
            .padding(12)
        }
        // The columns past the edge are easy to miss: the indicator shows there is more.
        .scrollIndicatorsFlash(onAppear: true)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// One run of text with inline Markdown. French examples, set in italics in the lesson files,
/// get the pronunciation marks and can be tapped to hear them.
struct InlineText: View {
    static let speakScheme = "speak"

    let md: String
    @Environment(Library.self) private var library

    var body: some View {
        Text(InlineText.cache.text(for: md, reader: library.reader))
            .fixedSize(horizontal: false, vertical: true)
    }

    @MainActor private static let cache = Cache()

    /// Rendering a rule looks up every French word in the dictionary; do it once per string.
    @MainActor
    private final class Cache {
        private var known: [String: AttributedString] = [:]

        func text(for md: String, reader: Reader) -> AttributedString {
            if let ready = known[md] { return ready }
            let made = InlineText.render(md, reader: reader)
            known[md] = made
            return made
        }
    }

    private static func render(_ md: String, reader: Reader) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let parsed = try? AttributedString(markdown: md, options: options) else { return AttributedString(md) }
        var result = AttributedString()
        for run in parsed.runs {
            let text = String(parsed[run.range].characters)
            let isItalicOnly = run.inlinePresentationIntent == .emphasized
            guard isItalicOnly, isFrench(text) else {
                result.append(AttributedString(parsed[run.range]))
                continue
            }
            let words = reader.read(text)
            let font = Theme.french(.body)
            // Fragments the dictionary does not know ("notr(e) ami", "-er") stay as they are written.
            var example = words.allSatisfy(\.isKnown) ? AttributedString(marked: words.marked, font: font) : AttributedString(text)
            if !words.allSatisfy(\.isKnown) { example.swiftUI.font = font.italic() }
            var address = URLComponents()
            address.scheme = speakScheme
            address.host = "say"
            address.queryItems = [URLQueryItem(name: "text", value: text)]
            example.link = address.url
            // Left in the link's accent colour: it tells the learner the example can be tapped.
            result.append(example)
        }
        return result
    }

    private static func isFrench(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter(CharacterSet.letters.contains)
        return !letters.isEmpty && !letters.contains { (0x0400...0x04FF).contains($0.value) }
    }
}
