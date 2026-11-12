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

    init(bundle: Bundle = .main) {
        // A missing or broken bundled file is a build mistake; no screen can work without it.
        func resource(_ name: String, _ type: String) -> Data {
            guard let url = bundle.url(forResource: name, withExtension: type) else {
                fatalError("\(name).\(type) is missing from the app bundle. Run the scripts in tools/ and rebuild.")
            }
            do {
                return try Data(contentsOf: url, options: .mappedIfSafe)
            } catch {
                fatalError("Cannot read \(name).\(type): \(error)")
            }
        }
        do {
            content = try Content.decode(resource("content", "json"))
        } catch {
            fatalError("content.json does not match the app's content model: \(error)")
        }
        lexicon = Lexicon(forms: resource("lexicon", "tsv"), lemmas: resource("lemmas", "tsv"))
        reader = Reader(lexicon: lexicon)
        grammar = Grammar(lexicon: lexicon)
    }

    func lesson(_ id: Int) -> Lesson? {
        content.lessons.first { $0.id == id }
    }

    /// The vocabulary entry for a word of a text, ignoring case, punctuation and its article.
    func entry(for text: String) -> Entry? {
        let wanted = Library.bare(text)
        guard !wanted.isEmpty else { return nil }
        return content.entries.first { Library.bare($0.word.fr) == wanted }
    }

    private static let articles = ["le ", "la ", "les ", "un ", "une ", "l'", "l’"]

    static func bare(_ text: String) -> String {
        var word = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        if let article = articles.first(where: { word.hasPrefix($0) }) { word.removeFirst(article.count) }
        return word
    }

    /// Words of the lessons that have forms to drill, one per lemma and word class.
    @ObservationIgnored private(set) lazy var formWords: [FormWord] = {
        var seen = Set<String>()
        var found: [FormWord] = []
        for entry in content.entries {
            let word = Library.bare(entry.word.fr)
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
