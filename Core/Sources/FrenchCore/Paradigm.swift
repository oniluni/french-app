import Foundation

/// All forms of a word, laid out for the word analysis screen and the form drills.
public struct Paradigm: Equatable, Sendable {
    public struct Form: Equatable, Sendable {
        /// Index into `WordClass.cellLabels`.
        public let cell: Int
        /// Pronoun or article with what joins it to the word: "nou(s) ", "j'", "le{s}‿". Empty for adjectives.
        public let lead: String
        /// The form itself, with pronunciation marks.
        public let body: String
        /// Sound of lead and body together: "nu z‿avɔ̃".
        public let ipa: String

        public var marked: String { lead + body }
        public var plain: String { Markup.plain(marked) }
        public var bodyPlain: String { Markup.plain(body) }
        public var leadPlain: String { Markup.plain(lead) }
    }

    public struct FormSet: Equatable, Sendable {
        /// A tense, «Артикль и число» or «Род и число».
        public let name: String
        public let forms: [Form]
    }

    public let lemma: String
    public let wordClass: WordClass
    /// The dictionary form with its marks and sound.
    public let base: Pronunciation
    public let sets: [FormSet]
    /// Part of speech, group, participle, gender: label and value, the value possibly marked French.
    public let facts: [Fact]

    public struct Fact: Equatable, Sendable {
        public let label: String
        public let value: String
        public let isFrench: Bool
    }
}

/// Builds paradigms and analyses word forms from the bundled dictionary.
public struct Grammar: Sendable {
    public let lexicon: Lexicon

    public init(lexicon: Lexicon) {
        self.lexicon = lexicon
    }

    static let tenses = [("Présent", "ind:pre"), ("Imparfait", "ind:imp"), ("Futur", "ind:fut")]
    public static let tenseNames = tenses.map(\.0)
    static let persons = ["1s", "2s", "3s", "1p", "2p", "3p"]
    /// Verbs conjugated with être in compound tenses.
    static let withEtre: Set<String> = [
        "aller", "venir", "arriver", "partir", "entrer", "sortir", "monter", "descendre", "naître", "mourir",
        "rester", "tomber", "retourner", "devenir", "revenir", "rentrer",
    ]

    /// What a typed form can be, the most likely first. Accepts "buvons", "l'enfant", "nous buvons".
    public func analyses(of input: String) -> [(form: String, analysis: Analysis)] {
        let words = input.split(whereSeparator: { $0.isWhitespace || $0 == "'" || $0 == "’" }).map(String.init)
        for candidate in [input.trimmingCharacters(in: .whitespaces)] + words.reversed() {
            let form = candidate.trimmingCharacters(in: .punctuationCharacters)
            if let entry = lexicon.entry(for: form), !entry.analyses.isEmpty {
                // Words that have forms to show come first.
                let ranked = entry.analyses.filter { $0.wordClass != nil } + entry.analyses.filter { $0.wordClass == nil }
                return ranked.map { (form, $0) }
            }
        }
        return []
    }

    public func paradigm(lemma: String, as wordClass: WordClass) -> Paradigm? {
        guard let (spelling, forms) = lexicon.forms(of: lemma, as: wordClass) else { return nil }
        let sound: (String) -> Pronunciation? = { lexicon.pronunciation(of: $0, lemma: spelling, as: wordClass) }
        guard let base = sound(spelling) ?? forms.first.flatMap({ sound($0.text) }) else { return nil }

        let sets: [Paradigm.FormSet]
        var facts: [Paradigm.Fact]
        switch wordClass {
        case .verb:
            sets = Grammar.tenses.compactMap { name, tag in
                let rows = Grammar.persons.enumerated().compactMap { cell, person -> Paradigm.Form? in
                    guard let form = forms.first(where: { $0.tags.contains("\(tag):\(person)") }), let said = sound(form.text) else { return nil }
                    return Grammar.verbForm(cell: cell, form: form.text, said: said)
                }
                return rows.isEmpty ? nil : Paradigm.FormSet(name: name, forms: rows)
            }
            facts = [.init(label: "Часть речи", value: "глагол, \(Grammar.group(of: spelling, forms: forms))", isFrench: false)]
            let participle = forms.first { $0.tags.contains("par:pas") && $0.gender != "f" && $0.number != "p" }
            if let participle, let said = sound(participle.text) {
                facts.append(.init(label: "Participe passé", value: said.marked, isFrench: true))
            }
            facts.append(.init(label: "Вспом. глагол", value: Grammar.withEtre.contains(spelling) ? "être" : "avoir", isFrench: true))
        case .noun:
            /// Articles by number for the forms of one gender.
            func articles(_ name: String, from candidates: [LemmaForm], isFeminine: Bool) -> Paradigm.FormSet? {
                let singular = candidates.first { $0.number != "p" && $0.text == spelling } ?? candidates.first { $0.number != "p" }
                let matchesGender: (LemmaForm) -> Bool = { $0.gender == singular?.gender || $0.gender.isEmpty || singular?.gender.isEmpty == true }
                let plural = candidates.first { $0.number == "p" && matchesGender($0) } ?? (singular?.number.isEmpty == true ? singular : nil)
                let cells: [(LemmaForm?, Bool, Bool)] = [(singular, true, false), (plural, true, true), (singular, false, false), (plural, false, true)]
                let rows = cells.enumerated().compactMap { cell, item -> Paradigm.Form? in
                    guard let form = item.0, let said = sound(form.text) else { return nil }
                    return Grammar.nounForm(cell: cell, form: form.text, said: said, isFeminine: isFeminine, isDefinite: item.1, isPlural: item.2)
                }
                return rows.isEmpty ? nil : Paradigm.FormSet(name: name, forms: rows)
            }
            // "ami" also lists "amie", "acteur" lists "actrice": one set per gender. A word whose two
            // genders are spelled alike ("élève") has one set.
            let masculine = forms.filter { $0.gender == "m" }.map(\.text)
            let feminine = forms.filter { $0.gender == "f" }.map(\.text)
            if !masculine.isEmpty, !feminine.isEmpty, Set(masculine).isDisjoint(with: feminine) {
                sets = [
                    articles("Мужской род", from: forms.filter { $0.gender != "f" }, isFeminine: false),
                    articles("Женский род", from: forms.filter { $0.gender != "m" }, isFeminine: true),
                ].compactMap { $0 }
                facts = [
                    .init(label: "Часть речи", value: "существительное", isFrench: false),
                    .init(label: "Род", value: "мужской и женский", isFrench: false),
                ]
            } else {
                let gender = forms.map(\.gender).first { !$0.isEmpty } ?? "m"
                sets = [articles("Артикль и число", from: forms, isFeminine: gender == "f")].compactMap { $0 }
                facts = [
                    .init(label: "Часть речи", value: "существительное", isFrench: false),
                    .init(label: "Род", value: gender == "f" ? "женский" : "мужской", isFrench: false),
                ]
            }
        case .adjective:
            let cells = [("m", "s"), ("f", "s"), ("m", "p"), ("f", "p")]
            let rows = cells.enumerated().compactMap { cell, wanted -> Paradigm.Form? in
                let fits: (LemmaForm) -> Bool = { ($0.gender == wanted.0 || $0.gender.isEmpty) && ($0.number == wanted.1 || $0.number.isEmpty) }
                guard let form = forms.first(where: fits), let said = sound(form.text) else { return nil }
                return Paradigm.Form(cell: cell, lead: "", body: said.marked, ipa: said.ipa)
            }
            sets = rows.isEmpty ? [] : [Paradigm.FormSet(name: "Род и число", forms: rows)]
            facts = [.init(label: "Часть речи", value: "прилагательное", isFrench: false)]
        }
        return Paradigm(lemma: spelling, wordClass: wordClass, base: base, sets: sets, facts: facts)
    }

    static func group(of infinitive: String, forms: [LemmaForm]) -> String {
        if ["être", "avoir", "aller"].contains(infinitive) { return "неправильный" }
        if infinitive.hasSuffix("er") { return "1-я группа" }
        let we = forms.first { $0.tags.contains("ind:pre:1p") }?.text ?? ""
        return infinitive.hasSuffix("ir") && we.hasSuffix("issons") ? "2-я группа" : "3-я группа"
    }

    static func verbForm(cell: Int, form: String, said: Pronunciation) -> Paradigm.Form {
        let opensWithVowel = Spelling.opensWithVowel(form)
        let (lead, sound): (String, String)
        switch (cell, opensWithVowel) {
        case (0, true): (lead, sound) = ("j'", "ʒ")
        case (0, false): (lead, sound) = ("je ", "ʒə ")
        case (1, _): (lead, sound) = ("tu ", "ty ")
        case (2, _): (lead, sound) = ("il ", "il ")
        case (3, true): (lead, sound) = ("nou{s}‿", "nu z‿")
        case (3, false): (lead, sound) = ("nou(s) ", "nu ")
        case (4, true): (lead, sound) = ("vou{s}‿", "vu z‿")
        case (4, false): (lead, sound) = ("vou(s) ", "vu ")
        case (_, true): (lead, sound) = ("il{s}‿", "il z‿")
        case (_, false): (lead, sound) = ("il(s) ", "il ")
        }
        return Paradigm.Form(cell: cell, lead: lead, body: said.marked, ipa: sound + said.ipa)
    }

    static func nounForm(cell: Int, form: String, said: Pronunciation, isFeminine: Bool, isDefinite: Bool, isPlural: Bool) -> Paradigm.Form {
        let opensWithVowel = Spelling.opensWithVowel(form)
        let (lead, sound): (String, String)
        switch (isDefinite, isPlural, opensWithVowel) {
        case (true, false, true): (lead, sound) = ("l'", "l")
        case (true, false, false): (lead, sound) = isFeminine ? ("la ", "la ") : ("le ", "lə ")
        case (true, true, true): (lead, sound) = ("le{s}‿", "le z‿")
        case (true, true, false): (lead, sound) = ("le(s) ", "le ")
        case (false, false, _) where isFeminine: (lead, sound) = ("un(e) ", "yn ")
        case (false, false, true): (lead, sound) = ("[u]{n}‿", "œ̃ n‿")
        case (false, false, false): (lead, sound) = ("[un] ", "œ̃ ")
        case (false, true, true): (lead, sound) = ("de{s}‿", "de z‿")
        case (false, true, false): (lead, sound) = ("de(s) ", "de ")
        }
        return Paradigm.Form(cell: cell, lead: lead, body: said.marked, ipa: sound + said.ipa)
    }
}

/// One question of a form drill.
public struct DrillQuestion: Equatable, Sendable {
    public let lemma: String
    public let wordClass: WordClass
    /// What the learner has to do, in Russian: «Выберите форму глагола».
    public let instruction: String
    /// Verb: the pronoun before the blank, marked. Noun or adjective: the base word, plain.
    public let prompt: String
    /// What is asked, in Russian: «мы · Présent», «женский, мн. ч.».
    public let task: String
    /// Plain spellings; a verb's options come without the pronoun, which would give the answer away.
    public let options: [String]
    public let answer: Int
    /// The full form, shown after the answer.
    public let solution: Paradigm.Form
}

public enum Drill {
    /// - Parameter tense: limits verb questions to one tense, e.g. "Imparfait".
    public static func questions<Generator: RandomNumberGenerator>(
        from paradigms: [Paradigm], tense: String? = nil, count: Int, using generator: inout Generator
    ) -> [DrillQuestion] {
        var candidates: [DrillQuestion] = []
        for paradigm in paradigms {
            let isVerb = paradigm.wordClass == .verb
            let everyVerbForm = paradigm.sets.flatMap(\.forms).map(\.bodyPlain)
            for set in paradigm.sets where !isVerb || tense == nil || set.name == tense {
                for form in set.forms {
                    let right = isVerb ? form.bodyPlain : form.plain
                    // A form identical to the word itself is no question.
                    if !isVerb, right == paradigm.lemma { continue }
                    let sameSet = set.forms.map { isVerb ? $0.bodyPlain : $0.plain }
                    var wrong = unique((sameSet + (isVerb ? everyVerbForm : [])).filter { $0 != right })
                    guard !wrong.isEmpty else { continue }
                    // Forms of the same tense are the closest distractors: keep them, fill up with the rest.
                    let near = unique(sameSet.filter { $0 != right }).shuffled(using: &generator)
                    wrong = near + wrong.filter { !near.contains($0) }.shuffled(using: &generator)
                    let options = ([right] + wrong.prefix(3)).shuffled(using: &generator)
                    let label = paradigm.wordClass.cellLabels[form.cell]
                    candidates.append(DrillQuestion(
                        lemma: paradigm.lemma, wordClass: paradigm.wordClass,
                        instruction: Drill.instruction(for: paradigm.wordClass),
                        prompt: isVerb ? form.lead : paradigm.lemma,
                        // A noun of two genders says which one is asked: «женский род, определённый, ед. ч.».
                        task: isVerb ? "\(label) · \(set.name)" : paradigm.sets.count > 1 ? "\(set.name.lowercased()), \(label)" : label,
                        options: options, answer: options.firstIndex(of: right) ?? 0, solution: form))
                }
            }
        }
        candidates.shuffle(using: &generator)
        return Array(candidates.prefix(count))
    }

    static func instruction(for wordClass: WordClass) -> String {
        switch wordClass {
        case .verb: "Выберите форму глагола для этого лица и времени"
        case .noun: "Выберите форму слова с нужным артиклем"
        case .adjective: "Выберите форму прилагательного для этого рода и числа"
        }
    }

    private static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }
}

extension Grammar {
    /// «un или une?»: up to `count` nouns of `nouns` asked for their gender.
    public func genderQuestions<Generator: RandomNumberGenerator>(
        nouns: [String], count: Int, using generator: inout Generator
    ) -> [DrillQuestion] {
        var questions: [DrillQuestion] = []
        for lemma in nouns.shuffled(using: &generator) where questions.count < count {
            if let question = genderQuestion(lemma) { questions.append(question) }
        }
        return questions
    }

    /// Nil for a noun of both genders («élève», «enfant»): it takes either article.
    func genderQuestion(_ lemma: String) -> DrillQuestion? {
        guard let (spelling, forms) = lexicon.forms(of: lemma, as: .noun) else { return nil }
        let singular = Set(forms.filter { $0.text == spelling && $0.number != "p" }.map(\.gender))
        let plural = Set(forms.filter { $0.number == "p" }.map(\.gender))
        // Lexique leaves the singular of some feminine nouns ungendered («maison», plural f); an
        // ungendered singular with any other plural is a noun of both genders.
        let gender: String? = singular == ["m"] ? "m" : singular == ["f"] || (singular == [""] && plural == ["f"]) ? "f" : nil
        guard let gender,
              let paradigm = paradigm(lemma: spelling, as: .noun),
              // The indefinite singular: «une famille» is what is shown once answered.
              let solution = paradigm.sets.flatMap(\.forms).first(where: { $0.cell == 2 && $0.bodyPlain == spelling })
        else { return nil }
        return DrillQuestion(
            lemma: spelling, wordClass: .noun, instruction: "Какого рода это слово? Выберите артикль",
            prompt: spelling, task: "мужской или женский род", options: ["un \(spelling)", "une \(spelling)"],
            answer: gender == "f" ? 1 : 0, solution: solution)
    }
}
