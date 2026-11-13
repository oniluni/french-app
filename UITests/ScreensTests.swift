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
    func testLessonRulesAndNotes() {
        app.launch()
        XCTAssertTrue(app.navigationBars["Уроки"].waitForExistence(timeout: 15))
        shot("01-lessons")

        app.buttons["lesson-5"].firstMatch.tap()
        // By title: the lesson list's cells stay in the tree under the pushed lesson.
        let rule = app.staticTexts["Правила чтения"].firstMatch
        XCTAssertTrue(rule.waitForExistence(timeout: 10), "a lesson opens on its rules")
        shot("02-lesson-rules")
        rule.tap()
        XCTAssertTrue(app.navigationBars["Урок 5"].waitForExistence(timeout: 5))
        shot("03-rule")

        app.buttons["notes-button"].tap()
        // A multi-line TextField is a text view to accessibility.
        let field = app.descendants(matching: .any)["note-field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardTip()
        field.typeText("Проверить произношение")
        shot("04-note-sheet")
        app.buttons["Сохранить"].tap()
        app.buttons["Закрыть"].tap()
        let counted = NSPredicate(format: "label == 'Заметки: 1'")
        expectation(for: counted, evaluatedWith: app.buttons["notes-button"])
        waitForExpectations(timeout: 5)
        app.navigationBars.buttons["BackButton"].tap()

        let words = app.buttons["Слова"]
        XCTAssertTrue(words.waitForExistence(timeout: 5), "back from the rule lands on the lesson")
        words.tap()
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
        XCTAssertTrue(app.staticTexts["drill-translation"].exists, "every lesson word has a translation under the question")
        XCTAssertTrue(app.staticTexts["instruction"].exists, "the question says what to do")
        shot("16-drill-question")
        app.buttons["option-0"].tap()
        XCTAssertTrue(app.staticTexts["Верно"].exists || app.staticTexts["Правильный ответ"].exists, "the verdict is written out")
        shot("17-drill-answered")
        app.buttons["Закрыть"].tap()

        app.buttons["Правила"].tap()
        let grammar = app.buttons["topic-Грамматика"]
        XCTAssertTrue(grammar.waitForExistence(timeout: 5))
        shot("17a-practice-rules")
        grammar.tap()
        XCTAssertTrue(app.buttons["option-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["instruction"].exists, "the question says what to do")
        shot("17b-rule-question")
        app.buttons["option-0"].tap()
        XCTAssertTrue(app.staticTexts["Верно"].exists || app.staticTexts["Правильный ответ"].exists, "the verdict is written out")
        shot("17c-rule-answered")
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

        // Return analyses the phrase and puts the keyboard away.
        let phrase = app.textViews["reader-field"].exists ? app.textViews["reader-field"] : app.textFields["reader-field"]
        phrase.tap()
        dismissKeyboardTip()
        phrase.typeText(" Un ami arrive à six heures.\n")
        let keyboardGone = NSPredicate(format: "count == 0")
        expectation(for: keyboardGone, evaluatedWith: app.keyboards)
        waitForExpectations(timeout: 5)
        // Grammar of the phrase: «à» is a preposition the lessons explain.
        XCTAssertTrue(scroll(to: app.staticTexts["Предлог à"]), "the reader lists the grammar rules of the phrase")
        shot("20b-reader-rules")
        // "Un ami": only a rule found in this very phrase can name the n of a nasal vowel.
        XCTAssertTrue(scroll(to: app.staticTexts["носовой гласный при связывании — носовой сохраняется, добавляется [n]"]))
        shot("20c-reader-reading-rules")

        app.buttons["Слово"].tap()
        let field = app.textFields["word-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardTip()
        field.typeText("buvons\n")
        XCTAssertTrue(app.staticTexts["Présent"].waitForExistence(timeout: 5) || app.buttons["Présent"].exists)
        shot("21-word-analysis")

        // A function word says what it is for.
        field.tap()
        field.clearAndType("au\n")
        XCTAssertTrue(labelled("слитный артикль").waitForExistence(timeout: 5), "«au» says it is à + le")
        shot("21a-word-use")

        // A noun of two genders opens on the gender that was typed, and has examples.
        field.tap()
        field.clearAndType("amie\n")
        let feminine = app.buttons["Женский род"]
        XCTAssertTrue(feminine.waitForExistence(timeout: 5))
        XCTAssertTrue(feminine.isSelected, "the typed form is feminine")
        shot("21b-word-two-genders")
        app.swipeUp()
        XCTAssertTrue(app.buttons["example"].firstMatch.waitForExistence(timeout: 5), "the word has example sentences")
        shot("21c-word-examples")

        // Star the word; it shows in «Избранное» with its translation and level, and leads back here.
        app.swipeDown()
        app.swipeDown()
        let star = app.buttons["favorite-toggle"]
        XCTAssertTrue(star.waitForExistence(timeout: 5))
        star.tap()
        XCTAssertEqual(star.label, "Убрать из избранного")

        app.tabBars.buttons["Поиск"].tap()
        XCTAssertTrue(app.navigationBars["Словарь"].waitForExistence(timeout: 10))
        shot("22-dictionary")
        app.buttons["Избранное"].tap()
        XCTAssertTrue(app.staticTexts["Уровень A1"].waitForExistence(timeout: 5), "the starred word shows its level")
        XCTAssertTrue(app.staticTexts["друг"].exists, "and its translation")
        shot("22b-favorites")
        app.staticTexts["друг"].tap()
        XCTAssertTrue(app.navigationBars["Разбор слова"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["BackButton"].tap()
        app.buttons["Все слова"].tap()

        // While search is open the tab bar folds into the tab it came from: unfold it first.
        app.tabBars.buttons["Разбор"].tap()
        XCTAssertTrue(app.tabBars.buttons["Практика"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Практика"].tap()
        XCTAssertTrue(app.staticTexts["Избранное"].waitForExistence(timeout: 5), "starred words are a practice set")
        shot("22c-favorites-set")

        app.tabBars.buttons["Поиск"].tap()
        let search = app.searchFields.firstMatch
        search.tap()
        dismissKeyboardTip()
        search.typeText("семья")
        shot("23-dictionary-search")
    }

    @MainActor
    func testReference() {
        app.launch()
        app.tabBars.buttons["Справочник"].tap()
        XCTAssertTrue(app.navigationBars["Справочник"].waitForExistence(timeout: 10))
        shot("40-reference")

        app.staticTexts["Предлоги"].tap()
        let gaps = app.buttons["Вставь слово"]
        XCTAssertTrue(gaps.waitForExistence(timeout: 5))
        shot("41-prepositions")
        gaps.tap()
        XCTAssertTrue(app.buttons["option-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["gap-sentence"].exists)
        shot("42-gap-question")
        app.buttons["option-0"].tap()
        let verdict = app.staticTexts.matching(NSPredicate(format: "label == 'Верно' OR label BEGINSWITH 'Правильный ответ'")).firstMatch
        XCTAssertTrue(verdict.waitForExistence(timeout: 5))
        shot("43-gap-answered")
        app.buttons["Закрыть"].tap()

        // Every word says what it is for.
        XCTAssertTrue(labelled("принадлежность").waitForExistence(timeout: 5), "«de» says what it is for")
        app.navigationBars.buttons["BackButton"].tap()

        app.staticTexts["Артикли"].tap()
        XCTAssertTrue(labelled("слитный артикль").waitForExistence(timeout: 5), "«au» says it is à + le")
        shot("41b-articles")
        app.navigationBars.buttons["BackButton"].tap()

        XCTAssertTrue(scroll(to: app.staticTexts["Идиомы"]), "the reference has a part on expressions")
        shot("40b-reference-phrases")
        app.staticTexts["Идиомы"].tap()
        XCTAssertTrue(app.navigationBars["Идиомы"].waitForExistence(timeout: 5))
        shot("45-idioms")
        app.navigationBars.buttons["BackButton"].tap()

        XCTAssertTrue(scroll(to: app.staticTexts["Глаголы с предлогами"]))
        app.staticTexts["Глаголы с предлогами"].tap()
        XCTAssertTrue(app.navigationBars["Глаголы с предлогами"].waitForExistence(timeout: 5))
        shot("46-verbs-with-prepositions")
        app.navigationBars.buttons["BackButton"].tap()

        app.swipeDown()
        app.swipeDown()
        app.staticTexts["Грамматика"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Грамматика"].waitForExistence(timeout: 5))
        shot("44-all-rules")
    }

    @MainActor
    func testDarkAppearance() {
        app.launchArguments.append("-uitest-dark")
        app.launch()
        XCTAssertTrue(app.navigationBars["Уроки"].waitForExistence(timeout: 15))
        shot("30-dark-lessons")
        app.buttons["lesson-2"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Правила чтения"].firstMatch.waitForExistence(timeout: 10))
        shot("31-dark-lesson-rules")
        app.tabBars.buttons["Практика"].tap()
        shot("32-dark-practice")
    }

    /// The first element whose label has this text: a list row reads all its texts as one label.
    @MainActor
    private func labelled(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Scrolls the screen up until the element is there; lists only build the rows they show.
    @MainActor
    private func scroll(to element: XCUIElement, swipes: Int = 8) -> Bool {
        for _ in 0..<swipes {
            if element.exists, element.isHittable { return true }
            app.swipeUp()
        }
        return element.waitForExistence(timeout: 2)
    }

    /// A fresh simulator shows a one-time keyboard tip («Speed up your typing…») shortly after the
    /// keyboard first appears; it swallows whatever is typed meanwhile.
    @MainActor
    private func dismissKeyboardTip() {
        let tip = app.buttons["Continue"]
        if tip.waitForExistence(timeout: 2) { tip.tap() }
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    /// Replaces the field's text: deletes what it holds, then types.
    func clearAndType(_ text: String) {
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
