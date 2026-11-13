import Foundation

/// One question of the rules practice: a sentence and four rules, one of which works in it.
public struct RuleQuestion: Equatable, Sendable {
    /// The phrase as the reader split it, punctuation included.
    public let words: [String]
    public let ru: String
    /// The answer and three rules that do not apply to the phrase, all with different titles.
    public let options: [Rule]
    public let answer: Int
    /// Indexes into `words` the answer applies to.
    public let highlighted: [Int]

    public var phrase: String { words.joined(separator: " ") }
}

extension Content {
    /// Up to `count` questions on `rules`, on example sentences of the words of the lessons those
    /// rules come from: the lessons have no texts of their own.
    ///
    /// Rules without a trigger (notes) are never asked. The answer is the rule of `rules` asked
    /// least so far, so a rule found in almost every sentence («Звук [e]») does not crowd out the
    /// rest. Distractors come from `rules` first, then from the other lessons.
    /// Throws when the bundled examples are broken.
    public func ruleQuestions<Generator: RandomNumberGenerator>(
        on rules: [Rule], reader: Reader, examples: Examples, count: Int, using generator: inout Generator
    ) throws -> [RuleQuestion] {
        let pool = rules.filter { $0.trigger != nil }
        let poolIDs = Set(pool.map(\.id))
        let ruleLessons = Set(pool.map(\.lesson))
        let others = lessons.flatMap(\.rules).filter { $0.trigger != nil && !poolIDs.contains($0.id) }
        let grammar = Grammar(lexicon: reader.lexicon)
        // "les élèves" → "élève": examples are kept by lemma.
        let lemmas = Set(lessons.filter { ruleLessons.contains($0.id) }.flatMap(\.words).map { word in
            let bare = Content.bare(word.fr)
            return grammar.analyses(of: bare).first?.analysis.lemma ?? bare
        })
        var seen = Set<String>()
        let sentences = try lemmas.sorted().flatMap { try examples.of(lemma: $0) }.filter { seen.insert($0.fr).inserted }

        var asked: [String: Int] = [:]
        var questions: [RuleQuestion] = []
        for sentence in sentences.shuffled(using: &generator) where questions.count < count {
            let words = reader.read(sentence.fr)
            let found = rulesTriggered(by: words, lexicon: reader.lexicon)
            let candidates = found.filter { poolIDs.contains($0.rule.id) }.shuffled(using: &generator)
            guard let hit = candidates.min(by: { asked[$0.rule.id, default: 0] < asked[$1.rule.id, default: 0] }) else { continue }
            // A distractor must not apply, nor share a title with a rule that does: two lessons
            // both have «Определённый артикль».
            var titles = Set(found.map(\.rule.title))
            let wrong = (pool.shuffled(using: &generator) + others.shuffled(using: &generator))
                .filter { titles.insert($0.title).inserted }
                .prefix(3)
            guard wrong.count == 3 else { continue }
            let options = ([hit.rule] + wrong).shuffled(using: &generator)
            asked[hit.rule.id, default: 0] += 1
            questions.append(RuleQuestion(
                words: words.map(\.text), ru: sentence.ru, options: options,
                answer: options.firstIndex(of: hit.rule) ?? 0, highlighted: hit.words))
        }
        return questions
    }
}
