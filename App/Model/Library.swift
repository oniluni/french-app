import Foundation
import FrenchCore
import Observation

/// Everything bundled with the app: the lessons and the dictionary.
@MainActor
@Observable
final class Library {
    let content: Content
    let lexicon: Lexicon
    let reader: Reader
    let grammar: Grammar
    let examples: Examples
    let glossary: Glossary
    let reference: ReferenceBook

    /// A bundled file that is missing or does not match the model: a build mistake, shown by the
    /// launch error screen instead of crashing, so that the learner can still save their progress.
    struct Failure: LocalizedError {
        let file: String
        let reason: String

        var errorDescription: String? { "\(file): \(reason)" }
    }

    init(bundle: Bundle = .main) throws {
        func resource(_ name: String, _ type: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: type) else {
                throw Failure(file: "\(name).\(type)", reason: "missing from the app bundle; run the scripts in tools/ and rebuild")
            }
            do {
                return try Data(contentsOf: url, options: .mappedIfSafe)
            } catch {
                throw Failure(file: "\(name).\(type)", reason: "cannot be read: \(error)")
            }
        }
        let contentData = try resource("content", "json")
        do {
            content = try Content.decode(contentData)
        } catch {
            throw Failure(file: "content.json", reason: "does not match the app's content model: \(error)")
        }
        lexicon = Lexicon(forms: try resource("lexicon", "tsv"), lemmas: try resource("lemmas", "tsv"))
        reader = Reader(lexicon: lexicon)
        grammar = Grammar(lexicon: lexicon)
        examples = Examples(data: try resource("examples", "tsv"))
        glossary = Glossary(data: try resource("dictionary", "tsv"))
        let referenceData = try resource("reference", "json")
        do {
            reference = try ReferenceBook.decode(referenceData)
        } catch {
            throw Failure(file: "reference.json", reason: "does not match the app's model: \(error)")
        }
    }

    /// The dictionary form of a word as typed or tapped: "amies" → "ami".
    func lemma(of word: String) -> String {
        grammar.analyses(of: word).first?.analysis.lemma ?? Content.bare(word)
    }

    /// The lessons' translation, else the dictionary's for the word, else for its lemma.
    func translation(of word: String) -> String? {
        content.entry(for: word)?.word.ru
            ?? glossary.info(of: Content.bare(word))?.translation
            ?? glossary.info(of: lemma(of: word))?.translation
    }

    /// CEFR level of the word's lemma: "A1" … "C2".
    func level(of word: String) -> String? {
        glossary.info(of: lemma(of: word))?.level ?? glossary.info(of: Content.bare(word))?.level
    }

    /// What kind of word it is, briefly: «сущ., ж. р.», «глагол, от aller».
    func shortForm(of word: String) -> String? {
        guard let found = grammar.analyses(of: word).first else { return nil }
        let analysis = found.analysis
        var parts: [String]
        switch analysis.pos {
        case "NOM": parts = ["сущ."] + (analysis.gender == "m" ? ["м. р."] : analysis.gender == "f" ? ["ж. р."] : [])
        case "VER": parts = ["глагол"]
        case "ADJ": parts = ["прил."]
        case "ADV": parts = ["нареч."]
        case "PRE": parts = ["предлог"]
        case "CON": parts = ["союз"]
        case "ADJ:num": parts = ["числит."]
        case let pos where pos.hasPrefix("PRO"): parts = ["местоим."]
        case let pos where pos.hasPrefix("ART"): parts = ["артикль"]
        default: return nil
        }
        if analysis.number == "p" { parts.append("мн. ч.") }
        if Lexicon.key(found.form) != Lexicon.key(analysis.lemma) { parts.append("от \(analysis.lemma)") }
        return parts.joined(separator: ", ")
    }

    /// The word as it is starred: the lesson's entry when there is one, so it keeps its marks and translation.
    func favorite(_ word: Word) -> Word {
        if let entry = content.entry(for: word.fr) { return entry.word }
        return Word(fr: word.fr, m: word.m, ipa: word.ipa, ru: word.ru.isEmpty ? translation(of: word.fr) ?? "" : word.ru, pos: word.pos)
    }

    func lesson(_ id: Int) -> Lesson? {
        content.lessons.first { $0.id == id }
    }

    /// The vocabulary entry for a word of a text, ignoring case, punctuation and its article.
    func entry(for text: String) -> Entry? {
        content.entry(for: text)
    }

    /// Words of the lessons that have forms to drill, one per lemma and word class.
    @ObservationIgnored private(set) lazy var formWords: [FormWord] = {
        var seen = Set<String>()
        var found: [FormWord] = []
        for entry in content.entries {
            let word = Content.bare(entry.word.fr)
            guard !word.contains(" "), let analysis = grammar.analyses(of: word).first?.analysis, let wordClass = analysis.wordClass else { continue }
            // Only the dictionary form itself: "je lis" is listed under "lire".
            guard Lexicon.key(analysis.lemma) == Lexicon.key(word), seen.insert("\(analysis.lemma)|\(wordClass.rawValue)").inserted else { continue }
            found.append(FormWord(lemma: analysis.lemma, wordClass: wordClass, entry: entry))
        }
        return found
    }()
}

struct FormWord: Identifiable, Hashable {
    let lemma: String
    let wordClass: WordClass
    let entry: Entry

    var id: String { "\(lemma)|\(wordClass.rawValue)" }
}
