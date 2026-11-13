import XCTest
@testable import FrenchCore

/// Reading rules for any phrase, nouns of two genders, translations in drills, usage examples.
final class ReadingPatternTests: XCTestCase {
    private func applies(_ pattern: ReadingPattern, _ marked: String, ipa: String = "", link: String = "", previous: String? = nil) -> Bool {
        pattern.applies(to: RuleSubject(marked: marked, ipa: ipa, link: link, isTied: !link.isEmpty, previous: previous))
    }

    func testSilentAndHeardFinalLetters() {
        XCTAssertTrue(applies(.silentFinal("s"), "ami(s)."))
        XCTAssertTrue(applies(.silentFinal("t"), "[en]f[an](ts)"))
        XCTAssertFalse(applies(.silentFinal("s"), "(h)abit(ent)"))
        // A silent letter inside the word is not a final one.
        XCTAssertFalse(applies(.silentFinal("e"), "p(e)tit"))
        XCTAssertTrue(applies(.heardFinal("f"), "neuf"))
        XCTAssertFalse(applies(.heardFinal("r"), "parle(r)"))
    }

    func testNasalHAndSound() {
        XCTAssertTrue(applies(.nasal, "[en]f[an](ts)"))
        XCTAssertFalse(applies(.nasal, "ami"))
        XCTAssertTrue(applies(.h, "(h)abit(ent)"))
        XCTAssertTrue(applies(.sound(letters: "ch", sound: "ʃ"), "che(z)", ipa: "ʃe"))
        XCTAssertFalse(applies(.sound(letters: "ch", sound: "ʃ"), "chaos", ipa: "kao"))
    }

    func testLiaisonAndLiaisonAfterANasal() {
        XCTAssertTrue(applies(.liaison, "ami(s)", link: "z", previous: "le{s}"))
        XCTAssertFalse(applies(.liaison, "ami", link: "n", previous: "[u]{n}"))
        XCTAssertTrue(applies(.nasalLink, "ami", link: "n", previous: "[u]{n}"))
        XCTAssertFalse(applies(.nasalLink, "ami", previous: "[un]"))
    }

    func testTheMostSpecificRuleWins() throws {
        let content = try Content.decode(Data("""
        {"lessons": [], "verbNotes": {}, "readingRules": [
          {"rule": "3-2", "label": "s на конце не читается", "pattern": {"kind": "silent-final", "letter": "s"}},
          {"rule": "3-2", "label": "Связывание", "pattern": {"kind": "liaison"}},
          {"rule": "11-2", "label": "Носовые гласные", "pattern": {"kind": "nasal"}}
        ]}
        """.utf8))
        let words = [RuleSubject(marked: "Le{s}", ipa: "le"), RuleSubject(marked: "[en]f[an](ts)", ipa: "ɑ̃fɑ̃", link: "z", isTied: true, previous: "Le{s}")]
        XCTAssertEqual(content.readingRule(for: words[1]), 1, "liaison outranks the nasal vowel and the silent s")
        let found = content.rulesApplying(to: words)
        XCTAssertEqual(found.map(\.rule.label), ["s на конце не читается", "Связывание", "Носовые гласные"])
        XCTAssertEqual(found.map(\.words), [[1], [1], [1]])
    }
}

final class TranslationTests: XCTestCase {
    private let content = Content(lessons: [])

    private func lesson(_ words: [Word]) throws -> Content {
        let json = try JSONEncoder().encode(words)
        return try Content.decode(Data("""
        {"lessons": [{"id": 5, "topic": "t", "rules": [], "words": \(String(decoding: json, as: UTF8.self))}], "readingRules": [], "verbNotes": {}}
        """.utf8))
    }

    func testTheExactFormBeatsTheLemma() throws {
        let content = try lesson([
            Word(fr: "aller", ipa: "ale", ru: "идти, ехать"),
            Word(fr: "je vais", ipa: "ʒə vɛ", ru: "я иду"),
            Word(fr: "petit, petite", ipa: "pəti", ru: "маленький, -ая"),
        ])
        XCTAssertEqual(content.translation(ofForm: "je vais", lemma: "aller"), .form("я иду"))
        XCTAssertEqual(content.translation(ofForm: "vous allez", lemma: "aller"), .lemma("идти, ехать"))
        XCTAssertEqual(content.translation(ofForm: "petite", lemma: "petit"), .form("маленький, -ая"))
        XCTAssertNil(content.translation(ofForm: "nous buvons", lemma: "boire"))
    }

    func testBareIgnoresCaseArticleAndPunctuation() {
        XCTAssertEqual(Content.bare("La famille."), "famille")
        XCTAssertEqual(Content.bare("L’ami"), "ami")
    }
}

final class TwoGendersTests: XCTestCase {
    private let lexicon = Lexicon(
        forms: Data("""
        ami\tami=ami\tami;NOM;m;s;;0
        amie\tamie=ami\tami;NOM;f;s;;0
        amies\tami(es)=ami\tami;NOM;f;p;;0
        amis\tami(s)=ami\tami;NOM;m;p;;0
        élève\télèv(e)=elɛv\télève;NOM;;s;;0
        élèves\télèv(es)=elɛv\télève;NOM;;p;;0

        """.utf8),
        lemmas: Data("""
        ami\tN\tami\tami;m;s;|amie;f;s;|amies;f;p;|amis;m;p;
        élève\tN\télève\télève;;s;|élèves;;p;

        """.utf8))

    func testANounWithBothGendersHasASetPerGender() throws {
        let noun = try XCTUnwrap(Grammar(lexicon: lexicon).paradigm(lemma: "ami", as: .noun))
        XCTAssertEqual(noun.sets.map(\.name), ["Мужской род", "Женский род"])
        XCTAssertEqual(noun.sets[0].forms.map(\.marked), ["l'ami", "le{s}‿ami(s)", "[u]{n}‿ami", "de{s}‿ami(s)"])
        XCTAssertEqual(noun.sets[1].forms.map(\.marked), ["l'amie", "le{s}‿ami(es)", "un(e) amie", "de{s}‿ami(es)"])
        XCTAssertEqual(noun.facts.last?.value, "мужской и женский")
    }

    func testAWordSpelledAlikeInBothGendersHasOneSet() throws {
        let noun = try XCTUnwrap(Grammar(lexicon: lexicon).paradigm(lemma: "élève", as: .noun))
        XCTAssertEqual(noun.sets.map(\.name), ["Артикль и число"])
    }

    func testDrillNamesTheGenderItAsksFor() throws {
        let noun = try XCTUnwrap(Grammar(lexicon: lexicon).paradigm(lemma: "ami", as: .noun))
        var generator = SeededGenerator(state: 3)
        let tasks = Drill.questions(from: [noun], count: 20, using: &generator).map(\.task)
        XCTAssertTrue(tasks.contains("женский род, определённый, ед. ч."), "\(tasks)")
    }
}

final class ExamplesTests: XCTestCase {
    private let examples = Examples(data: Data("""
    ami\t[{"fr":"Mon amie va bien.","ru":"У подруги всё хорошо.","src":"T5"},{"fr":"C'est mon ami.","ru":"Это мой друг.","src":"T3"}]
    broken\t[{"fr":
    lire\t[]

    """.utf8))

    func testTheTypedFormMovesUp() throws {
        XCTAssertEqual(try examples.of(lemma: "ami").map(\.src), ["T5", "T3"])
        XCTAssertEqual(try examples.of(lemma: "ami", preferring: "ami").map(\.src), ["T3", "T5"])
        XCTAssertEqual(try examples.of(lemma: "Ami").first?.src, "T5")
    }

    func testMissingAndBrokenLines() {
        XCTAssertEqual(try examples.of(lemma: "zzz"), [])
        XCTAssertThrowsError(try examples.of(lemma: "broken"))
    }
}
