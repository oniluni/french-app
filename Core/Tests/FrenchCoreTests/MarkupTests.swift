import XCTest
@testable import FrenchCore

final class MarkupTests: XCTestCase {
    func testParsesEveryKindOfMark() {
        XCTAssertEqual(Markup.parse("le{s}‿[en]f[an](ts)"), [
            MarkedPart("le"), MarkedPart("s", .link), MarkedPart("", .arc),
            MarkedPart("en", .nasal), MarkedPart("f"), MarkedPart("an", .nasal), MarkedPart("ts", .silent),
        ])
    }

    func testPlainDropsMarksAndTurnsLiaisonIntoGap() {
        XCTAssertEqual(Markup.plain("nou{s}‿(h)abit[on](s)"), "nous habitons")
        XCTAssertEqual(Markup.plain("gr[an](ds)-par[en](ts)"), "grands-parents")
    }

    func testLettersOfKind() {
        XCTAssertEqual(Markup.letters(of: .silent, in: "peti(t) déjeune(r)"), ["t", "r"])
        XCTAssertEqual(Markup.letters(of: .nasal, in: "[en]s[em]bl(e)"), ["en", "em"])
    }

    func testUnclosedBracketStaysPlainText() {
        XCTAssertEqual(Markup.parse("il me (te plaît"), [MarkedPart("il me (te plaît")])
    }
}
