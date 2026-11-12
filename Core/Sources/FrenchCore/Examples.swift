import Foundation

/// A sentence that shows a word in use, with its translation.
public struct Example: Decodable, Equatable, Sendable {
    public let fr: String
    /// With pronunciation marks; lesson phrases only. Other sentences go through the reader.
    public let m: String?
    public let ru: String
    /// "L5" for lesson 5, "T123" for Tatoeba sentence 123.
    public let src: String

    /// The lesson the phrase comes from; nil for a Tatoeba sentence.
    public var lesson: Int? { src.hasPrefix("L") ? Int(src.dropFirst()) : nil }
}

/// Usage examples by lemma, from `examples.tsv` written by `tools/build-examples.mjs`.
/// Lesson phrases come first, then sentences from Tatoeba (CC BY 2.0 FR).
public struct Examples: Sendable {
    private let lines: SortedLines

    public init(data: Data) {
        lines = SortedLines(bytes: data)
    }

    /// Examples of a lemma; those that contain `form` itself come first within each source.
    /// Throws when the line exists but is not valid JSON: the bundled file is broken.
    public func of(lemma: String, preferring form: String? = nil) throws -> [Example] {
        guard let line = lines.line(key: Lexicon.key(lemma)), let tab = line.firstIndex(of: "\t") else { return [] }
        let examples = try JSONDecoder().decode([Example].self, from: Data(line[line.index(after: tab)...].utf8))
        guard let form = form.map(Lexicon.key), !form.isEmpty else { return examples }
        let contains: (Example) -> Bool = { example in
            example.fr.split { !$0.isLetter && $0 != "'" && $0 != "’" }.contains { word in
                let key = Lexicon.key(String(word))
                return key == form || key.hasSuffix("'\(form)")
            }
        }
        // Stable: lesson phrases stay ahead of Tatoeba, the typed form moves up within each.
        let ranked = examples.enumerated().sorted { a, b in
            let rank = { (item: (offset: Int, element: Example)) in (item.element.lesson == nil ? 2 : 0) + (contains(item.element) ? 0 : 1) }
            return (rank(a), a.offset) < (rank(b), b.offset)
        }
        return ranked.map(\.element)
    }
}
