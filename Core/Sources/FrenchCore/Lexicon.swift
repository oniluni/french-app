import Foundation

public enum WordClass: String, CaseIterable, Sendable {
    case verb = "V", noun = "N", adjective = "A"

    /// What each cell of a paradigm set holds, in order.
    public var cellLabels: [String] {
        switch self {
        case .verb: ["я", "ты", "он, она", "мы", "вы", "они"]
        case .noun: ["определённый, ед. ч.", "определённый, мн. ч.", "неопределённый, ед. ч.", "неопределённый, мн. ч."]
        case .adjective: ["мужской, ед. ч.", "женский, ед. ч.", "мужской, мн. ч.", "женский, мн. ч."]
        }
    }
}

/// One way to say a spelling: `fils` is [fis] (son) or [fil] (threads).
public struct Pronunciation: Equatable, Sendable {
    public let marked: String
    public let ipa: String

    public init(marked: String, ipa: String) {
        self.marked = marked
        self.ipa = ipa
    }
}

/// What a spelling can be: `lit` is a form of the verb lire, and the noun lit.
public struct Analysis: Equatable, Sendable {
    public let lemma: String
    /// Lexique's part-of-speech code: NOM, VER, ADJ, ADV, PRE, ART:def, PRO:per, …
    public let pos: String
    /// "m", "f" or "" when it does not apply or is both.
    public let gender: String
    /// "s", "p" or "".
    public let number: String
    /// Verb forms: "ind:pre:1p", "inf", "par:pas", …
    public let tags: [String]
    /// Index into the pronunciations of the entry.
    public let pronunciation: Int

    public var wordClass: WordClass? {
        switch pos {
        case "VER": .verb
        case "NOM": .noun
        case "ADJ": .adjective
        default: nil
        }
    }
}

public struct LexiconEntry: Equatable, Sendable {
    /// The most frequent first.
    public let pronunciations: [Pronunciation]
    public let analyses: [Analysis]
}

public struct LemmaForm: Equatable, Sendable {
    public let text: String
    public let gender: String
    public let number: String
    public let tags: [String]
}

/// The bundled dictionary of French word forms, built from Lexique 3.83 by `tools/build-lexicon.mjs`.
public struct Lexicon: Sendable {
    private let forms: SortedLines
    private let lemmas: SortedLines

    /// - Parameters:
    ///   - forms: contents of `lexicon.tsv`
    ///   - lemmas: contents of `lemmas.tsv`
    public init(forms: Data, lemmas: Data) {
        self.forms = SortedLines(bytes: forms)
        self.lemmas = SortedLines(bytes: lemmas)
    }

    /// Lookup key: case, the œ ligature and the apostrophe style do not matter.
    public static func key(_ word: String) -> String {
        word.precomposedStringWithCanonicalMapping.lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespaces)
    }

    public func entry(for word: String) -> LexiconEntry? {
        guard let line = forms.line(key: Lexicon.key(word)) else { return nil }
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count == 3 else { return nil }
        let pronunciations = fields[1].split(separator: "|").map(String.init).compactMap { (pair: String) -> Pronunciation? in
            guard let equals = pair.lastIndex(of: "=") else { return nil }
            return Pronunciation(marked: String(pair[..<equals]), ipa: String(pair[pair.index(after: equals)...]))
        }
        let analyses = fields[2].split(separator: "|").compactMap { item -> Analysis? in
            let cell = item.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
            guard cell.count == 6 else { return nil }
            return Analysis(lemma: cell[0], pos: cell[1], gender: cell[2], number: cell[3], tags: tags(cell[4]), pronunciation: Int(cell[5]) ?? 0)
        }
        return pronunciations.isEmpty ? nil : LexiconEntry(pronunciations: pronunciations, analyses: analyses)
    }

    /// Every form of a lemma, with the lemma as Lexique spells it.
    public func forms(of lemma: String, as wordClass: WordClass) -> (lemma: String, forms: [LemmaForm])? {
        guard let line = lemmas.line(key: "\(Lexicon.key(lemma))\t\(wordClass.rawValue)") else { return nil }
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count == 4 else { return nil }
        let forms = fields[3].split(separator: "|").compactMap { item -> LemmaForm? in
            let cell = item.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
            guard cell.count == 4 else { return nil }
            return LemmaForm(text: cell[0], gender: cell[1], number: cell[2], tags: tags(cell[3]))
        }
        return (String(fields[2]), forms)
    }

    /// How a form is said as a form of this lemma: `fils` of `fil` is [fil], not the more common [fis].
    public func pronunciation(of form: String, lemma: String, as wordClass: WordClass) -> Pronunciation? {
        guard let entry = entry(for: form) else { return nil }
        let match = entry.analyses.first { $0.wordClass == wordClass && Lexicon.key($0.lemma) == Lexicon.key(lemma) }
        let index = match?.pronunciation ?? 0
        return entry.pronunciations.indices.contains(index) ? entry.pronunciations[index] : entry.pronunciations[0]
    }

    private func tags(_ field: String) -> [String] {
        field.split(separator: ",").map(String.init)
    }
}

/// A text file sorted by its leading key (UTF-8 byte order), searched without parsing it.
struct SortedLines: Sendable {
    let bytes: Data

    /// The line whose first field, or first fields when the key contains a tab, equals `key`.
    func line(key: String) -> String? {
        let target = Array("\(key)\t".utf8)
        return bytes.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> String? in
            var low = 0
            var high = buffer.count
            while low < high {
                let middle = (low + high) / 2
                var start = middle
                while start > low, buffer[start - 1] != 0x0A { start -= 1 }
                var end = middle
                while end < high, buffer[end] != 0x0A { end += 1 }

                var order = 0
                var offset = 0
                while order == 0, offset < target.count {
                    let byte = start + offset < end ? Int(buffer[start + offset]) : -1
                    order = byte - Int(target[offset])
                    offset += 1
                }
                if order == 0 { return String(decoding: UnsafeRawBufferPointer(rebasing: buffer[start..<end]), as: UTF8.self) }
                if order < 0 { low = min(end + 1, high) } else { high = start }
            }
            return nil
        }
    }
}
