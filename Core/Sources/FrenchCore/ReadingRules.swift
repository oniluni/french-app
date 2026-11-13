import Foundation

/// A word as reading rules see it: its marks, its sound and how it joins the word before.
public struct RuleSubject: Sendable {
    public let marked: String
    public let ipa: String
    /// Liaison consonant heard before the word.
    public let link: String
    /// Said together with the previous word.
    public let isTied: Bool
    /// The previous word, marked; nil at the start of a phrase.
    public let previous: String?

    public init(marked: String, ipa: String, link: String = "", isTied: Bool = false, previous: String? = nil) {
        self.marked = marked
        self.ipa = ipa
        self.link = link
        self.isTied = isTied
        self.previous = previous
    }
}

extension ReadingPattern {
    /// Whether the rule explains something in the word.
    ///
    /// The importer decides this on letters aligned with their sounds; here only the marks and
    /// the sound of the whole word are known.
    /// shortcut: `.sound` checks that the letters and the sound both occur in the word, not that
    /// one gives the other; port tools/align.mjs if the reader links wrong rules.
    public func applies(to subject: RuleSubject) -> Bool {
        let parts = Markup.parse(subject.marked).filter { $0.kind == .arc || $0.text.contains(where: \.isLetter) }
        switch self {
        case .nasalLink:
            return subject.previous.map(Self.endsInNasalLink) ?? false
        case .liaison:
            return !subject.link.isEmpty && !(subject.previous.map(Self.endsInNasalLink) ?? false)
        case .nasal:
            return parts.contains { $0.kind == .nasal }
        case .sound(let letters, let sound):
            let spelled = Markup.plain(subject.marked).lowercased()
            return spelled.contains(letters) && subject.ipa.decomposedStringWithCanonicalMapping.contains(sound.decomposedStringWithCanonicalMapping)
        case .h:
            return parts.contains { $0.kind == .silent && $0.text.lowercased().contains("h") }
        case .silentFinal(let letter):
            // The silent letters after the last pronounced one.
            let tail = parts.reversed().prefix { $0.kind == .silent || $0.kind == .link }
            return tail.contains { $0.kind == .silent && $0.text.lowercased().contains(letter) }
        case .heardFinal(let letter):
            guard let last = parts.last, last.kind == .plain || last.kind == .nasal else { return false }
            return last.text.lowercased().filter(\.isLetter).hasSuffix(letter)
        case .tie:
            return subject.isTied && subject.link.isEmpty
        }
    }

    /// "u{n}" or "bo{n}": the n of a nasal vowel heard before the next word.
    private static func endsInNasalLink(_ marked: String) -> Bool {
        Markup.parse(marked).last { $0.kind != .arc && $0.text.contains(where: \.isLetter) }.map { $0.kind == .link && $0.text.lowercased() == "n" } ?? false
    }
}

extension Content {
    /// Index into `readingRules` of the rule that best explains the word.
    public func readingRule(for subject: RuleSubject) -> Int? {
        readingRules.indices
            .filter { readingRules[$0].pattern.applies(to: subject) }
            .min { readingRules[$0].pattern.rank < readingRules[$1].pattern.rank }
    }

    /// Every reading rule that applies somewhere in a phrase, with the words it applies to,
    /// in the order of the rules.
    public func rulesApplying(to words: [RuleSubject]) -> [(rule: ReadingRule, words: [Int])] {
        readingRules.compactMap { rule in
            let matching = words.indices.filter { rule.pattern.applies(to: words[$0]) }
            return matching.isEmpty ? nil : (rule, matching)
        }
    }
}

extension Array where Element == ReadWord {
    /// The words as reading rules see them; words without marks are left out.
    public var ruleSubjects: [(index: Int, subject: RuleSubject)] {
        indices.compactMap { index in
            guard let marked = self[index].marked else { return nil }
            let previous = index > 0 ? self[index - 1].marked : nil
            return (index, RuleSubject(marked: marked, ipa: self[index].ipa, link: self[index].link, isTied: !self[index].link.isEmpty, previous: previous))
        }
    }
}
