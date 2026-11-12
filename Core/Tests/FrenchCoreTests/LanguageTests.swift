import XCTest
@testable import FrenchCore

/// A generator that always returns the same sequence, so drills are the same on every run.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

/// Sorted the way `tools/build-lexicon.mjs` writes them: by key, in UTF-8 byte order.
private let forms = """
a\ta=a\tavoir;VER;;;ind:pre:3s;0
ami\tami=ami\tami;NOM;m;s;;0
amis\tami(s)=ami\tami;NOM;m;p;;0
bon\tb[on]=bɔ̃\tbon;ADJ;m;s;;0
enfant\t[en]f[an](t)=ɑ̃fɑ̃\tenfant;NOM;;s;;0
enfants\t[en]f[an](ts)=ɑ̃fɑ̃\tenfant;NOM;m;p;;0
est\te(st)=ɛ|est=ɛst\têtre;VER;;;ind:pre:3s;0|est;NOM;m;s;;1
et\te(t)=e\tet;CON;;;;0
fil\tfil=fil\tfil;NOM;m;s;;0
fils\tfi(l)s=fis|fil(s)=fil\tfils;NOM;m;;;0|fil;NOM;m;p;;1
haricots\t(h)arico(ts)=aʁiko\tharicot;NOM;m;p;;0
heures\t(h)eur(es)=œʁ\theure;NOM;f;p;;0
il\til=il\til;PRO:per;m;s;;0
ils\til(s)=il\til;PRO:per;m;p;;0
les\tle(s)=le\tles;ART:def;;p;;0
ont\t[on](t)=ɔ̃\tavoir;VER;;;ind:pre:3p;0
parle\tparl(e)=paʁl\tparler;VER;;;ind:pre:1s,ind:pre:3s;0
parlent\tparl(ent)=paʁl\tparler;VER;;;ind:pre:3p;0
parler\tparle(r)=paʁle\tparler;VER;;;inf;0
parles\tparl(es)=paʁl\tparler;VER;;;ind:pre:2s;0
parlez\tparle(z)=paʁle\tparler;VER;;;ind:pre:2p;0
parlons\tparl[on](s)=paʁlɔ̃\tparler;VER;;;ind:pre:1p;0
parlé\tparlé=paʁle\tparler;VER;m;s;par:pas;0
petit\tpeti(t)=pəti\tpetit;ADJ;m;s;;0
petite\tpetit(e)=pətit\tpetit;ADJ;f;s;;0
petites\tpetit(es)=pətit\tpetit;ADJ;f;p;;0
petits\tpeti(ts)=pəti\tpetit;ADJ;m;p;;0
six\tsix=sis\tsix;ADJ:num;;;;0
soeur\tsœur=sœʁ\tsœur;NOM;f;s;;0
un\t[un]=œ̃\tun;ART:ind;m;s;;0

"""

private let lemmas = """
enfant\tN\tenfant\tenfant;;s;|enfants;m;p;
fil\tN\tfil\tfil;m;s;|fils;m;p;
parler\tV\tparler\tparle;;;ind:pre:1s,ind:pre:3s|parlent;;;ind:pre:3p|parler;;;inf|parles;;;ind:pre:2s|parlez;;;ind:pre:2p|parlons;;;ind:pre:1p|parlé;m;s;par:pas
petit\tA\tpetit\tpetit;m;s;|petite;f;s;|petites;f;p;|petits;m;p;

"""

private let lexicon = Lexicon(forms: Data(forms.utf8), lemmas: Data(lemmas.utf8))

final class LexiconTests: XCTestCase {
    func testFindsFirstMiddleAndLastLine() {
        XCTAssertEqual(lexicon.entry(for: "a")?.pronunciations, [Pronunciation(marked: "a", ipa: "a")])
        XCTAssertEqual(lexicon.entry(for: "il")?.analyses.first?.pos, "PRO:per")
        XCTAssertEqual(lexicon.entry(for: "un")?.pronunciations.first?.ipa, "œ̃")
    }

    func testMissesWhatIsNotThere() {
        XCTAssertNil(lexicon.entry(for: "am"))
        XCTAssertNil(lexicon.entry(for: "amie"))
        XCTAssertNil(lexicon.entry(for: "zzz"))
        XCTAssertNil(lexicon.entry(for: ""))
    }

    func testKeyIgnoresCaseLigatureAndApostropheStyle() {
        XCTAssertEqual(Lexicon.key("SŒUR"), "soeur")
        XCTAssertEqual(lexicon.entry(for: "Sœur")?.pronunciations.first?.marked, "sœur")
        XCTAssertEqual(Lexicon.key("L’ami"), "l'ami")
    }

    func testAnalysesKeepTheirOwnPronunciation() {
        let entry = lexicon.entry(for: "fils")
        XCTAssertEqual(entry?.analyses.map(\.lemma), ["fils", "fil"])
        XCTAssertEqual(lexicon.pronunciation(of: "fils", lemma: "fil", as: .noun)?.ipa, "fil")
        XCTAssertEqual(lexicon.entry(for: "parle")?.analyses.first?.tags, ["ind:pre:1s", "ind:pre:3s"])
    }

    func testFormsOfALemma() {
        XCTAssertEqual(lexicon.forms(of: "Petit", as: .adjective)?.forms.map(\.text), ["petit", "petite", "petites", "petits"])
        XCTAssertNil(lexicon.forms(of: "petit", as: .verb))
    }
}

final class ReaderTests: XCTestCase {
    private let reader = Reader(lexicon: lexicon)

    func testLiaisonAfterDeterminerAndPronoun() {
        let words = reader.read("Les enfants ont six amis.")
        XCTAssertEqual(words.marked, "Le{s}‿[en]f[an](ts) [on](t) si{x}‿ami(s).")
        XCTAssertEqual(words.ipa, "le z‿ɑ̃fɑ̃ ɔ̃ si z‿ami")
        XCTAssertEqual([words.silentLetters, words.liaisons, words.nasalVowels], [4, 2, 3])
    }

    func testNasalVowelStaysInUnButNotInBon() {
        XCTAssertEqual(reader.read("un ami").marked, "[u]{n}‿ami")
        XCTAssertEqual(reader.read("un ami").ipa, "œ̃ n‿ami")
        XCTAssertEqual(reader.read("un bon ami").marked, "[un] bo{n}‿ami")
        XCTAssertEqual(reader.read("un bon ami").ipa, "œ̃ bɔ n‿ami")
    }

    func testNoLiaisonAfterEtBeforeAspiratedHOrAcrossPunctuation() {
        XCTAssertEqual(reader.read("et il").marked, "e(t) il")
        XCTAssertEqual(reader.read("les haricots").marked, "le(s) (h)arico(ts)")
        XCTAssertEqual(reader.read("les heures").marked, "le{s}‿(h)eur(es)")
        XCTAssertEqual(reader.read("les, enfants").marked, "le(s), [en]f[an](ts)")
    }

    func testElisionAndInversionInsideOneWord() {
        XCTAssertEqual(reader.read("l'ami").map(\.marked), ["l'ami"])
        XCTAssertEqual(reader.read("l'ami").ipa, "lami")
        let inverted = reader.read("Ont-ils parlé ? — A-t-il parlé ?")
        XCTAssertEqual(inverted.map(\.marked), ["[On]{t}-il(s)", "parlé\u{00A0}?", "—\u{00A0}A-t-il", "parlé\u{00A0}?"])
        XCTAssertEqual(inverted.map(\.ipa), ["ɔ̃til", "paʁle", "atil", "paʁle"])
    }

    func testBracketsTypedByTheLearnerAreNotMarks() {
        let words = reader.read("il me (te) plaît")
        XCTAssertNil(words[2].marked)
        XCTAssertEqual(words.map(\.isKnown), [true, true, false, true])
    }

    func testUnknownWordIsLeftAlone() {
        let words = reader.read("Les zzz parlent")
        XCTAssertEqual(words.map(\.isKnown), [true, false, true])
        XCTAssertEqual(words.marked, "Le(s) zzz parl(ent)")
        XCTAssertEqual(words.ipa, "le … paʁl")
    }
}

final class GrammarTests: XCTestCase {
    private let grammar = Grammar(lexicon: lexicon)

    func testAnalysesOfATypedForm() {
        XCTAssertEqual(grammar.analyses(of: "parlons").map(\.analysis.lemma), ["parler"])
        XCTAssertEqual(grammar.analyses(of: "l'enfant").first?.form, "enfant")
        XCTAssertEqual(grammar.analyses(of: "ils parlent").first?.analysis.tags, ["ind:pre:3p"])
        XCTAssertTrue(grammar.analyses(of: "zzz").isEmpty)
    }

    func testVerbParadigm() throws {
        let verb = try XCTUnwrap(grammar.paradigm(lemma: "parler", as: .verb))
        XCTAssertEqual(verb.base, Pronunciation(marked: "parle(r)", ipa: "paʁle"))
        XCTAssertEqual(verb.sets.map(\.name), ["Présent"])
        XCTAssertEqual(verb.sets[0].forms.map(\.marked), ["je parl(e)", "tu parl(es)", "il parl(e)", "nou(s) parl[on](s)", "vou(s) parle(z)", "il(s) parl(ent)"])
        XCTAssertEqual(verb.sets[0].forms[3].ipa, "nu paʁlɔ̃")
        XCTAssertEqual(verb.facts.map(\.value), ["глагол, 1-я группа", "parlé", "avoir"])
    }

    func testVowelInitialFormsTakeElisionAndLiaison() {
        XCTAssertEqual(Grammar.verbForm(cell: 0, form: "aime", said: .init(marked: "aim(e)", ipa: "ɛm")).marked, "j'aim(e)")
        let we = Grammar.verbForm(cell: 3, form: "avons", said: .init(marked: "av[on](s)", ipa: "avɔ̃"))
        XCTAssertEqual([we.marked, we.ipa, we.plain, we.bodyPlain], ["nou{s}‿av[on](s)", "nu z‿avɔ̃", "nous avons", "avons"])
    }

    func testNounParadigm() throws {
        let noun = try XCTUnwrap(grammar.paradigm(lemma: "enfant", as: .noun))
        XCTAssertEqual(noun.sets[0].forms.map(\.marked), ["l'[en]f[an](t)", "le{s}‿[en]f[an](ts)", "[u]{n}‿[en]f[an](t)", "de{s}‿[en]f[an](ts)"])
        XCTAssertEqual(noun.sets[0].forms[2].ipa, "œ̃ n‿ɑ̃fɑ̃")
        // "fils" as the plural of "fil" is said [fil], not like the more frequent "fils" (son).
        let thread = try XCTUnwrap(grammar.paradigm(lemma: "fil", as: .noun))
        XCTAssertEqual(thread.sets[0].forms[1].ipa, "le fil")
    }

    func testAdjectiveParadigm() throws {
        let adjective = try XCTUnwrap(grammar.paradigm(lemma: "petit", as: .adjective))
        XCTAssertEqual(adjective.sets[0].forms.map(\.marked), ["peti(t)", "petit(e)", "peti(ts)", "petit(es)"])
    }

    func testDrillQuestions() throws {
        let paradigms = try [("parler", WordClass.verb), ("petit", .adjective), ("enfant", .noun)].map { try XCTUnwrap(grammar.paradigm(lemma: $0.0, as: $0.1)) }
        var generator = SeededGenerator(state: 7)
        let questions = Drill.questions(from: paradigms, count: 50, using: &generator)
        // 6 verb forms, 3 adjective forms (the masculine singular is the word itself), 4 noun forms.
        XCTAssertEqual(questions.count, 13)
        for question in questions {
            XCTAssertEqual(Set(question.options).count, question.options.count, "options repeat in \(question)")
            XCTAssertLessThanOrEqual(question.options.count, 4)
            let right = question.options[question.answer]
            if question.wordClass == .verb {
                XCTAssertEqual(right, question.solution.bodyPlain)
                XCTAssertFalse(question.options.contains { $0.contains(" ") }, "a verb option must not show the pronoun")
            } else {
                XCTAssertEqual(right, question.solution.plain)
                XCTAssertNotEqual(right, question.lemma)
            }
        }
        var again = SeededGenerator(state: 7)
        XCTAssertEqual(Drill.questions(from: paradigms, count: 50, using: &again), questions)
        var limited = SeededGenerator(state: 7)
        XCTAssertEqual(Drill.questions(from: paradigms, tense: "Imparfait", count: 50, using: &limited).filter { $0.wordClass == .verb }.count, 0)
    }
}
