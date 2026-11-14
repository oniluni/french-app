import FrenchCore
import SwiftUI

/// Formatted lesson text: paragraphs, lists, tables and callouts of a rule or an explanation.
struct BlocksView: View {
    let blocks: [Block]
    @Environment(Speech.self) private var speech

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                BlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // body 16/24
        .lineSpacing(4)
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
            InlineText(md: md).font(Theme.title3).padding(.top, 10)
        case .paragraph(let md):
            InlineText(md: md)
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(ordered ? "\(index + 1)." : "•").font(Theme.mono(14)).foregroundStyle(Theme.t3).frame(minWidth: 14, alignment: .trailing)
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
            Callout(isWarning: kind == "warning") {
                VStack(alignment: .leading, spacing: 8) {
                    if !title.isEmpty { Text(title).font(Theme.sans(15, .semibold, relativeTo: .callout)) }
                    BlocksView(blocks: blocks)
                }
            }
        case .divider:
            Theme.line.frame(height: 1).padding(.vertical, 2)
        }
    }
}

/// A table wider than the screen scrolls sideways instead of squeezing its columns.
private struct TableView: View {
    let head: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(head.enumerated()), id: \.offset) { column, cell in
                        cellView(InlineText(md: cell).font(Theme.sans(12, .medium, relativeTo: .caption)).foregroundStyle(Theme.t2), column: column)
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    // A wrapped cell would otherwise read as two rows.
                    Theme.line.frame(height: 1).gridCellUnsizedAxes(.horizontal)
                    GridRow(alignment: .top) {
                        ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                            cellView(InlineText(md: cell).font(Theme.callout).frame(maxWidth: 240, alignment: .leading), column: column)
                        }
                    }
                }
            }
        }
        // The columns past the edge are easy to miss: the indicator shows there is more.
        .scrollIndicatorsFlash(onAppear: true)
        .surface(radius: 16)
    }

    private func cellView(_ content: some View, column: Int) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .leading) { if column > 0 { Theme.line.frame(width: 1) } }
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
            // Fragments the dictionary does not know ("notr(e) ami", "-er") stay as they are written.
            var example = words.allSatisfy(\.isKnown) ? AttributedString(marked: words.marked, size: 16, weight: .medium) : AttributedString(text)
            if !words.allSatisfy(\.isKnown) { example.swiftUI.font = Theme.sans(16, .medium) }
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
