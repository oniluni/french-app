import Foundation

/// When a rule of the lessons applies to a phrase. Written by `tools/rule-triggers.mjs`, where the
/// language is described with each rule's trigger.
public indirect enum RuleTrigger: Decodable, Hashable, Sendable {
    case any([RuleTrigger])
    case all([RuleTrigger])
    case ipa([String])
    case finalSound([String])
    case doubled
    case droppedSchwa
    case spelling(letters: String, sound: String)
    case letters([String])
    case text([String])
    case question
    case minWords(Int)
    case properName
    case elision
    case inversion
    case token(WordPredicate)
    case sequence([WordPredicate])

    private enum CodingKeys: String, CodingKey {
        case any, all, ipa, finalSound, doubled, droppedSchwa, spelling, letters, text, question, minWords
        case properName, elision, inversion, token, sequence
    }

    private struct Spelling: Decodable { let letters: String; let sound: String }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try c.decodeIfPresent([RuleTrigger].self, forKey: .any) { self = .any(value) }
        else if let value = try c.decodeIfPresent([RuleTrigger].self, forKey: .all) { self = .all(value) }
        else if let value = try c.decodeIfPresent([String].self, forKey: .ipa) { self = .ipa(value) }
        else if let value = try c.decodeIfPresent([String].self, forKey: .finalSound) { self = .finalSound(value) }
        else if c.contains(.doubled) { self = .doubled }
        else if c.contains(.droppedSchwa) { self = .droppedSchwa }
        else if let value = try c.decodeIfPresent(Spelling.self, forKey: .spelling) { self = .spelling(letters: value.letters, sound: value.sound) }
        else if let value = try c.decodeIfPresent([String].self, forKey: .letters) { self = .letters(value) }
        else if let value = try c.decodeIfPresent([String].self, forKey: .text) { self = .text(value) }
        else if c.contains(.question) { self = .question }
        else if let value = try c.decodeIfPresent(Int.self, forKey: .minWords) { self = .minWords(value) }
        else if c.contains(.properName) { self = .properName }
        else if c.contains(.elision) { self = .elision }
        else if c.contains(.inversion) { self = .inversion }
        else if let value = try c.decodeIfPresent(WordPredicate.self, forKey: .token) { self = .token(value) }
        else if let value = try c.decodeIfPresent([WordPredicate].self, forKey: .sequence) { self = .sequence(value) }
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown rule trigger"))
        }
    }
}

/// What one word must be. Fields about the word's analysis (lemma, pos, tags, number, group)
/// must hold for one and the same reading of it.
public struct WordPredicate: Decodable, Hashable, Sendable {
    public let words: [String]?
    public let lemma: [String]?
    public let pos: [String]?
    /// Prefixes of verb tags: "ind:pre:2s", "imp:pre".
    public let tags: [String]?
    public let number: String?
    /// 1 or 3; aller counts as III group, as the textbook has it.
    public let group: Int?
    /// The first word of the phrase, a leading ne/n' aside.
    public let first: Bool?
    /// Right after a comma, a dash or a quotation mark: "— …, dit le professeur".
    public let afterPunctuation: Bool?
}

/// A phrase as the triggers see it: words split at apostrophes and hyphens, each with its readings.
public struct PhraseFacts {
    struct Token {
        let text: String
        let word: Int
        let isHyphenated: Bool
        let isCapitalized: Bool
        let afterPunctuation: Bool
        /// Every reading the dictionary has, the most frequent first.
        let analyses: [Analysis]
        /// The reading chosen from the words around it; nil for a word the dictionary does not know.
        var reading: Analysis?
    }

    let words: [ReadWord]
    let tokens: [Token]
    /// Sounds of each word, one Character per phoneme ("ɑ̃" is one).
    let sounds: [[Character]]
    /// Lowercased words joined by spaces, and where each word starts in it.
    let text: String
    let starts: [Int]
    private let lexicon: Lexicon
    private var groups: [String: String] = [:]

    public init(words: [ReadWord], lexicon: Lexicon) {
        self.words = words
        self.lexicon = lexicon
        sounds = words.map { word in Array(word.ipa.filter { $0 != "(" && $0 != ")" }) }
        var tokens: [Token] = []
        for (index, word) in words.enumerated() {
            let core = word.text.trimmingCharacters(in: CharacterSet.letters.inverted)
            let previous = index > 0 ? words[index - 1].text : ""
            let punctuated = previous.last.map { ",;:—–«»\"".contains($0) } ?? false || word.text.hasPrefix("—") || word.text.hasPrefix("«")
            var piece = ""
            var isHyphenated = false
            func close() {
                guard !piece.isEmpty else { return }
                let text = piece.lowercased().replacingOccurrences(of: "’", with: "'")
                let analyses = lexicon.entry(for: text)?.analyses ?? lexicon.entry(for: text.replacingOccurrences(of: "'", with: ""))?.analyses ?? []
                tokens.append(Token(text: text, word: index, isHyphenated: isHyphenated, isCapitalized: piece.first?.isUppercase ?? false,
                                    afterPunctuation: punctuated && !tokens.contains { $0.word == index }, analyses: analyses, reading: nil))
                piece = ""
            }
            for character in core {
                if character == "'" || character == "’" {
                    piece.append("'")
                    close()
                    isHyphenated = false
                } else if character == "-" {
                    close()
                    isHyphenated = true
                } else {
                    piece.append(character)
                }
            }
            close()
        }
        PhraseFacts.chooseReadings(&tokens)
        self.tokens = tokens
        var text = ""
        var starts: [Int] = []
        for word in words {
            if !text.isEmpty { text += " " }
            starts.append(text.count)
            text += word.text.lowercased().replacingOccurrences(of: "’", with: "'")
        }
        self.text = text
        self.starts = starts
    }

    private static let subjects: Set<String> = ["je", "j'", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles", "ne", "n'"]
    private static let objectPronouns: Set<String> = ["le", "la", "les", "l'", "me", "m'", "te", "t'", "se", "s'", "lui", "leur", "y", "en", "nous", "vous"]

    /// One reading per word, from its neighbours: a verb after a subject or ne, an object pronoun
    /// only before a verb, a noun or adjective after a determiner, else the most frequent.
    /// shortcut: a two-word window instead of a tagger; replace with a trained tagger if rules misfire.
    private static func chooseReadings(_ tokens: inout [Token]) {
        let isVerb: (Analysis) -> Bool = { $0.pos == "VER" }
        for index in tokens.indices {
            let token = tokens[index]
            let previous = index > 0 ? tokens[index - 1] : nil
            let nextCanBeVerb = index + 1 < tokens.count && tokens[index + 1].analyses.contains(where: isVerb)
            let afterSubject = previous.map { subjects.contains($0.text) || ($0.reading?.pos == "PRO:per" && objectPronouns.contains($0.text)) } ?? false
            let afterDeterminer = previous?.reading.map { ["ART:def", "ART:ind", "ADJ:pos", "ADJ:dem", "ADJ:num", "ADJ:int", "ADJ:ind"].contains($0.pos) } ?? false
            var reading = token.analyses.first
            if objectPronouns.contains(token.text), nextCanBeVerb, afterSubject || previous == nil || token.text == "y" || token.text == "en",
               let pronoun = token.analyses.first(where: { $0.pos == "PRO:per" }) {
                reading = pronoun
            } else if afterSubject, let verb = token.analyses.first(where: isVerb) {
                reading = verb
            } else if afterDeterminer, let noun = token.analyses.first(where: { $0.pos == "NOM" }) ?? token.analyses.first(where: { $0.pos == "ADJ" }) {
                reading = noun
            } else if !objectPronouns.contains(token.text) || !nextCanBeVerb, let other = token.analyses.first(where: { $0.pos != "PRO:per" }),
                      token.analyses.first?.pos == "PRO:per", ["le", "la", "les", "l'"].contains(token.text) {
                // "la table": an article, the pronoun reading needs a verb after it.
                reading = other
            }
            tokens[index].reading = reading
        }
    }

    /// "1-я группа", "3-я группа", … as the word analysis screen names it.
    mutating func group(of lemma: String) -> String {
        if let known = groups[lemma] { return known }
        let found = Grammar.group(of: lemma, forms: lexicon.forms(of: lemma, as: .verb)?.forms ?? [])
        groups[lemma] = found
        return found
    }
}

private let vowels: Set<Character> = ["a", "ɑ", "e", "ɛ", "i", "o", "ɔ", "u", "y", "ø", "œ", "ə", "ɑ̃", "ɛ̃", "ɔ̃", "œ̃"]
private let pronouns: Set<String> = ["je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles", "ce", "t"]

extension RuleTrigger {
    /// The words of the phrase the rule is about, or nil when it does not apply.
    /// A rule about the phrase as a whole applies with no words of its own.
    public func matches(_ facts: inout PhraseFacts) -> [Int]? {
        switch self {
        case .any(let triggers):
            let found = triggers.compactMap { $0.matches(&facts) }
            return found.isEmpty ? nil : Array(Set(found.flatMap { $0 })).sorted()
        case .all(let triggers):
            var words: Set<Int> = []
            for trigger in triggers {
                guard let found = trigger.matches(&facts) else { return nil }
                words.formUnion(found)
            }
            return words.sorted()
        case .ipa(let wanted):
            let sounds = Set(wanted.map { Character($0) })
            return nonEmpty(facts.sounds.indices.filter { facts.sounds[$0].contains(where: sounds.contains) })
        case .finalSound(let wanted):
            let sounds = Set(wanted.map { Character($0) })
            return nonEmpty(facts.sounds.indices.filter { facts.sounds[$0].last.map(sounds.contains) ?? false })
        case .doubled:
            var found: Set<Int> = []
            for index in facts.sounds.indices.dropLast() {
                guard let last = facts.sounds[index].last, let first = facts.sounds[index + 1].first else { continue }
                if last == first, !vowels.contains(last) { found.formUnion([index, index + 1]) }
            }
            return nonEmpty(found.sorted())
        case .droppedSchwa:
            return nonEmpty(facts.words.indices.filter { index in
                let word = facts.words[index]
                if word.ipa.contains("(ə)") { return true }
                guard let marked = word.marked, let range = marked.range(of: "(e)") else { return false }
                return marked[range.upperBound...].first?.isLetter ?? false
            })
        case .spelling(let letters, let sound):
            return nonEmpty(facts.words.indices.filter { index in
                facts.words[index].text.lowercased().contains(letters) && String(facts.sounds[index]).contains(sound)
            })
        case .letters(let wanted):
            return nonEmpty(facts.words.indices.filter { index in wanted.contains { facts.words[index].text.lowercased().contains($0) } })
        case .text(let patterns):
            var found: Set<Int> = []
            for pattern in patterns {
                var searchStart = facts.text.startIndex
                while let range = facts.text.range(of: pattern, range: searchStart..<facts.text.endIndex) {
                    searchStart = range.upperBound
                    let before = range.lowerBound == facts.text.startIndex ? nil : facts.text[facts.text.index(before: range.lowerBound)]
                    let after = range.upperBound == facts.text.endIndex ? nil : facts.text[range.upperBound]
                    guard !(before?.isLetter ?? false), !(after?.isLetter ?? false) else { continue }
                    let start = facts.text.distance(from: facts.text.startIndex, to: range.lowerBound)
                    let end = facts.text.distance(from: facts.text.startIndex, to: range.upperBound)
                    for (index, wordStart) in facts.starts.enumerated() where wordStart < end && wordStart + facts.words[index].text.count > start {
                        found.insert(index)
                    }
                }
            }
            return nonEmpty(found.sorted())
        case .question:
            return facts.text.contains("?") ? [facts.words.count - 1] : nil
        case .minWords(let count):
            return facts.words.count >= count ? [] : nil
        case .properName:
            return nonEmpty(facts.tokens.indices.filter { index in
                let token = facts.tokens[index]
                guard token.isCapitalized, token.word > 0, !token.isHyphenated else { return false }
                // A capital after a full stop starts a sentence.
                return !(facts.words[token.word - 1].text.last.map { ".!?".contains($0) } ?? false)
            }.map { facts.tokens[$0].word })
        case .elision:
            return nonEmpty(facts.tokens.filter { $0.text.hasSuffix("'") }.map(\.word))
        case .inversion:
            return nonEmpty(facts.tokens.indices.filter { index in
                let token = facts.tokens[index]
                return token.isHyphenated && pronouns.contains(token.text) && index > 0 && facts.tokens[index - 1].word == token.word
            }.map { facts.tokens[$0].word })
        case .token(let predicate):
            return nonEmpty(facts.tokens.indices.filter { predicate.holds(at: $0, in: &facts) }.map { facts.tokens[$0].word })
        case .sequence(let predicates):
            var found: Set<Int> = []
            guard !predicates.isEmpty, facts.tokens.count >= predicates.count else { return nil }
            for start in 0...(facts.tokens.count - predicates.count) {
                let fits = predicates.indices.allSatisfy { predicates[$0].holds(at: start + $0, in: &facts) }
                if fits { found.formUnion((start..<start + predicates.count).map { facts.tokens[$0].word }) }
            }
            return nonEmpty(found.sorted())
        }
    }

    private func nonEmpty(_ words: [Int]) -> [Int]? {
        words.isEmpty ? nil : Array(Set(words)).sorted()
    }
}

extension WordPredicate {
    func holds(at index: Int, in facts: inout PhraseFacts) -> Bool {
        let token = facts.tokens[index]
        if let words, !words.contains(token.text) { return false }
        if first == true {
            let leading = facts.tokens.firstIndex { $0.text != "ne" && $0.text != "n'" }
            guard leading == index else { return false }
        }
        if afterPunctuation == true, !token.afterPunctuation { return false }
        guard lemma != nil || pos != nil || tags != nil || number != nil || group != nil else { return true }
        for analysis in [token.reading].compactMap({ $0 }) {
            if let lemma, !lemma.contains(analysis.lemma.lowercased()) { continue }
            if let pos, !pos.contains(analysis.pos) { continue }
            if let tags, !analysis.tags.contains(where: { tag in tags.contains { tag.hasPrefix($0) } }) { continue }
            if let number, analysis.number != number { continue }
            if let group {
                guard analysis.pos == "VER" else { continue }
                let lemma = analysis.lemma.lowercased()
                let named = facts.group(of: lemma)
                let isWanted = group == 1 ? named == "1-я группа" : named == "3-я группа" || lemma == "aller"
                if !isWanted { continue }
            }
            return true
        }
        return false
    }
}

extension Content {
    /// The rules of the lessons that apply to a phrase, in lesson order, each with its words.
    /// Reading rules listed item by item (`readingRules`) are found by `rulesApplying(to:)`.
    public func rulesTriggered(by words: [ReadWord], lexicon: Lexicon) -> [(rule: Rule, words: [Int])] {
        var facts = PhraseFacts(words: words, lexicon: lexicon)
        return lessons.flatMap(\.rules).compactMap { rule in
            guard let trigger = rule.trigger, let found = trigger.matches(&facts) else { return nil }
            return (rule, found)
        }
    }
}
