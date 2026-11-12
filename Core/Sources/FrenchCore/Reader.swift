import Foundation

/// Spelling facts the reader and the paradigms share.
enum Spelling {
    static let vowels = Set("aàâæeéèêëiîïoôœuùûüyÿ")

    /// Words that begin with a vowel letter or an h and still block elision and liaison.
    static let blocking: Set<String> = [
        "hache", "haie", "haine", "haïr", "hall", "halte", "hamac", "hameau", "hamster", "hanche", "handicap", "hangar",
        "hanter", "harceler", "hardi", "hareng", "haricot", "harnais", "harpe", "hasard", "hâte", "hausse", "hausser",
        "haut", "haute", "hauts", "hautes", "hauteur", "héros", "hérisson", "héron", "hêtre", "heurter", "hibou", "hiérarchie",
        "hisser", "hocher", "hockey", "hollande", "homard", "hongrie", "hongrois", "honte", "hors", "housse", "hublot",
        "huer", "huit", "huitième", "hurler", "hutte",
        "onze", "onzième", "oui", "yaourt", "yacht", "yoga",
    ]

    /// Whether elision and liaison apply before the word: a vowel letter, or a mute h.
    static func opensWithVowel(_ word: String) -> Bool {
        let lowered = word.lowercased()
        // Plurals of the listed words block too: les haricots.
        let singular = lowered.hasSuffix("s") || lowered.hasSuffix("x") ? String(lowered.dropLast()) : lowered
        guard let first = lowered.first, !blocking.contains(lowered), !blocking.contains(singular) else { return false }
        if first == "y" { return lowered == "y" || lowered == "yeux" }
        if first == "h" { return lowered.dropFirst().first.map(vowels.contains) ?? false }
        return vowels.contains(first)
    }
}

/// One word of a phrase the reader has transcribed.
public struct ReadWord: Equatable, Sendable {
    /// As typed, with its punctuation.
    public let text: String
    /// With pronunciation marks. Nil when the dictionary does not know the word.
    public let marked: String?
    public let ipa: String
    /// Liaison consonant heard before the word.
    public let link: String

    public var isKnown: Bool { marked != nil }
}

/// Transcribes any French phrase with the bundled dictionary.
///
/// shortcut: a spelling with several readings takes the most frequent one, and only liaisons
/// after a closed list of words are made. Upgrade to tagging by context if wrong readings matter.
public struct Reader: Sendable {
    public let lexicon: Lexicon

    public init(lexicon: Lexicon) {
        self.lexicon = lexicon
    }

    /// Words after which a liaison is made.
    static let linkers: Set<String> = [
        "les", "des", "ces", "mes", "tes", "ses", "nos", "vos", "leurs", "aux", "un", "mon", "ton", "son", "aucun",
        "quelques", "plusieurs", "deux", "trois", "six", "dix", "quels", "quelles", "tout",
        "nous", "vous", "ils", "elles", "on", "en",
        "est", "sont", "ont",
        "dans", "chez", "sans", "sous", "très", "plus", "moins", "bien", "rien", "trop", "quand", "dont",
        "petit", "petits", "petites", "grand", "grands", "grandes", "bon", "bons", "bonnes", "mauvais", "gros",
        "premier", "dernier", "beaux", "belles", "nouveaux", "nouvelles", "vieux", "jeunes", "autres", "mêmes",
    ]
    /// Pronouns that take a liaison from the verb before them: ont-ils, allez-y.
    static let inverted: Set<String> = ["il", "elle", "on", "ils", "elles", "y", "en"]
    /// Words that lose their vowel before a vowel, with what is left of their sound: l'ami, qu'il.
    static let elided = [
        "l": "l", "j": "ʒ", "c": "s", "ç": "s", "d": "d", "n": "n", "s": "s", "m": "m", "t": "t", "qu": "k",
        "jusqu": "ʒysk", "lorsqu": "lɔʁsk", "puisqu": "pɥisk", "quelqu": "kɛlk", "presqu": "pʁɛsk",
    ]
    /// Words whose vowel stays nasal in a liaison; in "bon ami" it does not.
    static let nasalKeepers: Set<String> = ["un", "mon", "ton", "son", "on", "en", "aucun", "bien", "rien"]

    private struct Piece {
        let text: String
        var parts: [MarkedPart]?
        var ipa: String
        var link = ""
        /// What follows the piece inside its word: "'", "-" or nothing.
        let joiner: String
        let word: Int
    }

    public func read(_ phrase: String) -> [ReadWord] {
        let words = Reader.words(of: phrase)
        var pieces: [Piece] = []
        var frames: [(lead: String, tail: String)] = []
        for (index, word) in words.enumerated() {
            let (lead, core, tail) = Reader.frame(word)
            frames.append((lead, tail))
            // Brackets typed by the learner would read as pronunciation marks: leave such words unmarked.
            let hasMarkCharacters = (lead + tail).contains { "()[]{}‿".contains($0) }
            pieces += self.pieces(of: core, word: index).map { piece in
                var piece = piece
                if hasMarkCharacters { piece.parts = nil }
                return piece
            }
        }

        for index in pieces.indices.dropLast() {
            let next = pieces[index + 1]
            let sameWord = pieces[index].word == next.word
            if sameWord ? pieces[index].joiner != "-" : (!frames[pieces[index].word].tail.isEmpty || !frames[next.word].lead.isEmpty) { continue }
            guard let sound = Reader.liaison(&pieces[index], before: next, inverted: sameWord) else { continue }
            pieces[index + 1].link = sound
        }

        return words.indices.map { index in
            let mine = pieces.filter { $0.word == index }
            let isKnown = !mine.isEmpty && mine.allSatisfy { $0.parts != nil }
            var marked = frames[index].lead
            var ipa = ""
            for (offset, piece) in mine.enumerated() {
                marked += Markup.string(from: piece.parts ?? []) + piece.joiner
                ipa += (offset > 0 ? piece.link : "") + piece.ipa
            }
            marked += frames[index].tail
            return ReadWord(text: words[index], marked: isKnown ? marked : nil, ipa: isKnown ? ipa : "", link: isKnown ? mine[0].link : "")
        }
    }

    /// "Je lis ce livre ." → words with their punctuation attached.
    static func words(of phrase: String) -> [String] {
        var words: [String] = []
        var opening = ""
        for chunk in phrase.split(whereSeparator: \.isWhitespace).map(String.init) {
            if chunk.contains(where: { $0.isLetter || $0.isNumber }) {
                words.append(opening + chunk)
                opening = ""
            } else if words.isEmpty || chunk.allSatisfy({ "—–«(".contains($0) }) {
                opening += chunk + "\u{00A0}"
            } else {
                words[words.count - 1] += "\u{00A0}" + chunk
            }
        }
        if !opening.isEmpty, !words.isEmpty { words[words.count - 1] += "\u{00A0}" + opening.trimmingCharacters(in: .whitespaces) }
        return words
    }

    /// Punctuation before the first letter, the letters, punctuation after the last one.
    private static func frame(_ word: String) -> (lead: String, core: String, tail: String) {
        let isCore: (Character) -> Bool = { $0.isLetter || $0.isNumber }
        guard let first = word.firstIndex(where: isCore), let last = word.lastIndex(where: isCore) else { return (word, "", "") }
        return (String(word[..<first]), String(word[first...last]), String(word[word.index(after: last)...]))
    }

    /// "l'ami" → l' + ami, "dit-elle" → dit + elle; "aujourd'hui" stays whole because the dictionary has it.
    private func pieces(of core: String, word: Int) -> [Piece] {
        if let whole = lookUp(core) { return [Piece(text: core, parts: whole.parts, ipa: whole.ipa, joiner: "", word: word)] }
        var found: [Piece] = []
        var current = ""
        func close(_ joiner: String) {
            guard !current.isEmpty else { return }
            defer { current = "" }
            if joiner == "'" {
                let sound = Reader.elided[current.lowercased()]
                found.append(Piece(text: current, parts: sound.map { _ in [MarkedPart(current)] }, ipa: sound ?? "", joiner: joiner, word: word))
            } else if current.lowercased() == "t", found.last?.joiner == "-" {
                // The t of "a-t-il" is only a sound between two vowels, not the letter's name.
                found.append(Piece(text: current, parts: [MarkedPart(current)], ipa: "t", joiner: joiner, word: word))
            } else {
                let known = lookUp(current)
                found.append(Piece(text: current, parts: known?.parts, ipa: known?.ipa ?? "", joiner: joiner, word: word))
            }
        }
        for character in core {
            if character == "'" || character == "’" { close("'") } else if character == "-" { close("-") } else { current.append(character) }
        }
        close("")
        return found
    }

    /// Dictionary marks carried onto the letters as typed, so "Les" keeps its capital.
    private func lookUp(_ text: String) -> (parts: [MarkedPart], ipa: String)? {
        guard let reading = lexicon.entry(for: text)?.pronunciations.first else { return nil }
        var parts = Markup.parse(reading.marked)
        var typed = Array(text)
        guard parts.reduce(0, { $0 + $1.text.count }) == typed.count else { return (parts, reading.ipa) }
        parts = parts.map { part in
            let own = String(typed.prefix(part.text.count))
            typed.removeFirst(part.text.count)
            return MarkedPart(own, part.kind)
        }
        return (parts, reading.ipa)
    }

    /// Wakes the silent final consonant of `first` if a liaison is made before `second`.
    /// Returns the consonant heard, and rewrites the marks and the sound of `first`.
    private static func liaison(_ first: inout Piece, before second: Piece, inverted isInverted: Bool) -> String? {
        let word = first.text.lowercased()
        guard var parts = first.parts, second.parts != nil, let last = parts.last, let letter = word.last else { return nil }
        guard isInverted ? inverted.contains(second.text.lowercased()) : linkers.contains(word) else { return nil }
        guard Spelling.opensWithVowel(second.text) else { return nil }
        let sounds: [Character: String] = ["s": "z", "x": "z", "z": "z", "t": "t", "d": "t", "n": "n", "r": "ʁ", "p": "p"]
        guard let sound = sounds[letter] else { return nil }

        parts.removeLast()
        let head = String(last.text.dropLast())
        let final = String(last.text.suffix(1))
        switch last.kind {
        case .silent:
            if !head.isEmpty { parts.append(MarkedPart(head, .silent)) }
        case .nasal where letter == "n":
            if nasalKeepers.contains(word) {
                parts.append(MarkedPart(head, .nasal))
            } else {
                // bon ami [bɔ n‿ami]: the vowel loses its nasal quality.
                parts.append(MarkedPart(head))
                first.ipa = first.ipa.replacingOccurrences(of: "\u{0303}", with: "")
            }
        case .plain where letter == "x" && first.ipa.hasSuffix("s"):
            // six, dix: [sis] alone, [siz] in a liaison.
            if !head.isEmpty { parts.append(MarkedPart(head)) }
            first.ipa.removeLast()
        default:
            return nil
        }
        parts.append(MarkedPart(final, .link))
        first.parts = parts
        return sound
    }
}

extension Array where Element == ReadWord {
    /// "le{s}‿[en]f[an](ts) (h)abit(ent)": the phrase with a tie where a liaison is made.
    public var marked: String {
        enumerated().map { index, word in (index == 0 ? "" : word.link.isEmpty ? " " : "‿") + (word.marked ?? word.text) }.joined()
    }

    /// "le z‿ɑ̃fɑ̃ abit". An unknown word leaves a gap written as "…".
    public var ipa: String {
        map { $0.isKnown ? ($0.link.isEmpty ? "" : "\($0.link)‿") + $0.ipa : "…" }.joined(separator: " ")
    }

    public var silentLetters: Int {
        compactMap(\.marked).flatMap { Markup.letters(of: .silent, in: $0) }.reduce(0) { $0 + $1.count }
    }

    public var nasalVowels: Int {
        compactMap(\.marked).reduce(0) { $0 + Markup.letters(of: .nasal, in: $1).count }
    }

    public var liaisons: Int {
        compactMap(\.marked).reduce(0) { $0 + Markup.letters(of: .link, in: $1).count }
    }
}
