import XCTest

/// Walks the app and attaches a screenshot of every screen.
/// Nobody on this project has a simulator, so these attachments are how the UI gets reviewed.
/// Each test starts from an empty profile (`-uitest`), so one failure does not hide the others.
final class ScreensTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
    }

    @MainActor
    func testLessonsTextPopoverAndNotes() {
        app.launch()
        XCTAssertTrue(app.navigationBars["Уроки"].waitForExistence(timeout: 15))
        shot("01-lessons")

        app.buttons["lesson-5"].firstMatch.tap()
        let word = app.buttons["Denise"].firstMatch
        XCTAssertTrue(word.waitForExistence(timeout: 10), "lesson 5 text did not show the word Denise")
        shot("02-lesson-text")

        word.tap()
        XCTAssertTrue(app.staticTexts["Дениза"].waitForExistence(timeout: 5), "the popover shows the translation")
        shot("03-word-popover")
        XCTAssertTrue(app.buttons["Заметка"].exists)
        app.buttons["Заметка"].tap()

        // A multi-line TextField is a text view to accessibility.
        let field = app.descendants(matching: .any)["note-field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Проверить произношение")
        shot("04-note-sheet")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.buttons["notes-button"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["notes-button"].label, "Заметки: 1")

        app.switches["pronunciation-toggle"].tap()
        shot("05-lesson-text-plain")
        app.switches["pronunciation-toggle"].tap()

        app.buttons["Правила"].tap()
        shot("06-lesson-rules")
        app.cells.firstMatch.tap()
        shot("07-rule")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Слова"].tap()
        shot("08-lesson-words")
    }

    @MainActor
    func testCardSessionAndDrill() {
        app.launch()
        app.tabBars.buttons["Практика"].tap()
        XCTAssertTrue(app.buttons["Урок 5"].waitForExistence(timeout: 10))
        shot("10-practice-words")

        app.buttons["Урок 5"].tap()
        app.buttons["Урок 6"].tap()
        shot("11-range-picked")
        app.buttons["Начать"].tap()

        let card = app.buttons["card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        shot("12-card-front")
        card.tap()
        // A grade button reads its interval too: «Хорошо, 1 дн».
        let good = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Хорошо'")).firstMatch
        XCTAssertTrue(good.waitForExistence(timeout: 5))
        shot("13-card-back")
        good.tap()
        XCTAssertTrue(app.staticTexts["1 / 10"].waitForExistence(timeout: 5), "one of ten cards is done")
        app.buttons["Закрыть"].tap()

        XCTAssertTrue(app.staticTexts["Уроки 5–6"].waitForExistence(timeout: 5), "the range is saved as a set")
        shot("14-my-sets")

        app.buttons["Формы"].tap()
        let mixed = app.buttons["Смешанная тренировка"]
        XCTAssertTrue(mixed.waitForExistence(timeout: 10))
        shot("15-practice-forms")
        mixed.tap()
        XCTAssertTrue(app.buttons["option-0"].waitForExistence(timeout: 5))
        shot("16-drill-question")
        app.buttons["option-0"].tap()
        XCTAssertTrue(app.staticTexts["Верно"].exists || app.staticTexts["Правильный ответ"].exists, "the verdict is written out")
        shot("17-drill-answered")
    }

    @MainActor
    func testReaderWordAnalysisAndDictionary() {
        app.launch()
        app.tabBars.buttons["Разбор"].tap()
        let sample = app.buttons["Les enfants habitent à Paris."]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()
        XCTAssertTrue(app.staticTexts["немых букв"].waitForExistence(timeout: 5))
        shot("20-reader")

        app.buttons["Слово"].tap()
        let field = app.textFields["word-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("buvons\n")
        XCTAssertTrue(app.staticTexts["Présent"].waitForExistence(timeout: 5) || app.buttons["Présent"].exists)
        shot("21-word-analysis")

        app.tabBars.buttons["Поиск"].tap()
        XCTAssertTrue(app.navigationBars["Словарь"].waitForExistence(timeout: 10))
        shot("22-dictionary")
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("семья")
        shot("23-dictionary-search")
    }

    @MainActor
    func testDarkAppearance() {
        app.launchArguments.append("-uitest-dark")
        app.launch()
        XCTAssertTrue(app.navigationBars["Уроки"].waitForExistence(timeout: 15))
        shot("30-dark-lessons")
        app.buttons["lesson-2"].firstMatch.tap()
        XCTAssertTrue(app.switches["pronunciation-toggle"].waitForExistence(timeout: 10))
        shot("31-dark-lesson-text")
        app.tabBars.buttons["Практика"].tap()
        shot("32-dark-practice")
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
