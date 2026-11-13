import XCTest
@testable import FrenchCore

final class GlossaryTests: XCTestCase {
    private let glossary = Glossary(data: Data("ami\tA1\tдруг, приятель\nnéanmoins\tB1\t\nzèbre\t\tзебра\n".utf8))

    func testLevelAndTranslation() {
        XCTAssertEqual(glossary.info(of: "Ami"), Glossary.Info(level: "A1", translation: "друг, приятель"))
        XCTAssertEqual(glossary.info(of: "néanmoins"), Glossary.Info(level: "B1", translation: nil))
        XCTAssertEqual(glossary.info(of: "zèbre"), Glossary.Info(level: nil, translation: "зебра"))
        XCTAssertNil(glossary.info(of: "zzz"))
    }
}

final class GapFillTests: XCTestCase {
    private func category(gaps: [Gap]) throws -> ReferenceCategory {
        let words = ["à", "de", "chez", "dans", "sur"].map { #"{"fr":"\#($0)","ipa":"","ru":"…"}"# }.joined(separator: ",")
        let objects = gaps.map { #"{"before":"\#($0.before)","answer":"\#($0.answer)","after":"\#($0.after)","ru":"\#($0.ru)","src":"\#($0.src)"}"# }.joined(separator: ",")
        return try JSONDecoder().decode(ReferenceCategory.self, from: Data(#"{"id":"prepositions","title":"Предлоги","words":[\#(words)],"gaps":[\#(objects)]}"#.utf8))
    }

    func testEveryQuestionHasItsAnswerAndThreeOtherWordsOfTheKind() throws {
        let gaps = [
            Gap(before: "Je vais ", answer: "à", after: " Paris.", ru: "Я еду в Париж.", src: "T1"),
            Gap(before: "Il dort ", answer: "chez", after: " lui.", ru: "Он спит дома.", src: "T2"),
        ]
        var generator = SeededGenerator(state: 11)
        let questions = GapFill.questions(from: try category(gaps: gaps), count: 5, using: &generator)
        XCTAssertEqual(questions.count, 2)
        for question in questions {
            XCTAssertEqual(question.options.count, 4)
            XCTAssertEqual(Set(question.options).count, 4)
            XCTAssertEqual(question.options[question.answer], question.gap.answer.lowercased())
        }
        var again = SeededGenerator(state: 11)
        XCTAssertEqual(GapFill.questions(from: try category(gaps: gaps), count: 5, using: &again), questions)
    }

    func testCountLimitsTheQuestions() throws {
        let gaps = (0..<6).map { Gap(before: "x ", answer: "de", after: " y \($0)", ru: "", src: "T\($0)") }
        var generator = SeededGenerator(state: 1)
        XCTAssertEqual(GapFill.questions(from: try category(gaps: gaps), count: 4, using: &generator).count, 4)
    }
}

final class FavoritesTests: XCTestCase {
    func testALessonWordKeepsItsLessonCardAnyOtherWordGetsItsOwn() throws {
        let content = try Content.decode(Data("""
        {"lessons": [{"id": 5, "topic": "t", "rules": [], "words": [
          {"fr": "la famille", "ipa": "la famij", "ru": "семья", "pos": "Существительное"}
        ]}], "readingRules": [], "verbNotes": {}}
        """.utf8))
        let entries = content.entries(forWords: [
            Word(fr: "famille", ipa: "famij", ru: "семья"),
            Word(fr: "matin", ipa: "matɛ̃", ru: "утро"),
        ])
        XCTAssertEqual(entries.map(\.id), ["5:la famille", "0:matin"])
    }

    func testOlderBackupsKeepTheirAddedWordsAsFavorites() throws {
        let old = #"{"version":1,"addedWords":[{"fr":"matin","ipa":"matɛ̃","ru":"утро","pos":""}]}"#
        XCTAssertEqual(try UserData.decode(Data(old.utf8)).favorites.map(\.fr), ["matin"])
    }
}
