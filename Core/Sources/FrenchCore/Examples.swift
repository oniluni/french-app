import Foundation

/// A sentence that shows a word in use, with its translation.
public struct Example: Decodable, Equatable, Sendable {
    public let fr: String
    public let ru: String
    /// "T123" for Tatoeba sentence 123.
    public let src: String
}

/// Usage examples by lemma, from `examples.tsv` written by `tools/build-examples.mjs`.
/// The sentences come from Tatoeba (CC BY 2.0 FR).
public struct Examples: Sendable {
    private let lines: SortedLines

    public init(data: Data) {
        lines = SortedLines(bytes: data)
    }

    /// Examples of a lemma; those that contain `form` itself come first.
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
        // Stable: otherwise the file's order, closest to the ideal length first.
        return examples.filter(contains) + examples.filter { !contains($0) }
    }
}
