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
        dismissKeyboardTip()
        field.typeText("Проверить произношение")
        shot("04-note-sheet")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.buttons["notes-button"].waitForExistence(timeout: 5))
        let counted = NSPredicate(format: "label == 'Заметки: 1'")
        expectation(for: counted, evaluatedWith: app.buttons["notes-button"])
        waitForExpectations(timeout: 5)

        app.switches["pronunciation-toggle"].tap()
        shot("05-lesson-text-plain")
        app.switches["pronunciation-toggle"].tap()

        app.buttons["Правила"].tap()
        shot("06-lesson-rules")
        // By title: the lesson list's cells stay in the tree under the pushed lesson.
        let rule = app.staticTexts["Правила чтения"].firstMatch
        XCTAssertTrue(rule.waitForExistence(timeout: 5))
        rule.tap()
        XCTAssertTrue(app.navigationBars["Урок 5"].staticTexts["Урок 5"].waitForExistence(timeout: 5) || app.staticTexts["j читается [ʒ]:"].exists)
        shot("07-rule")
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
        XCTAssertTrue(scroll(to: app.staticTexts["Связывание после носового гласного"]))
        shot("20c-reader-reading-rules")

        app.buttons["Слово"].tap()
        let field = app.textFields["word-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardTip()
        field.typeText("buvons\n")
        XCTAssertTrue(app.staticTexts["Présent"].waitForExistence(timeout: 5) || app.buttons["Présent"].exists)
        shot("21-word-analysis")

        // A noun of two genders opens on the gender that was typed, and has examples.
        field.tap()
        field.clearAndType("amie\n")
        let feminine = app.buttons["Женский род"]
        XCTAssertTrue(feminine.waitForExistence(timeout: 5))
        XCTAssertTrue(feminine.isSelected, "the typed form is feminine")
        shot("21b-word-two-genders")
        app.swipeUp()
        // Each example names its source under the translation.
        let source = app.staticTexts.matching(NSPredicate(format: "label == 'Tatoeba' OR label BEGINSWITH 'Урок '")).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 5))
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

        app.navigationBars.buttons["BackButton"].tap()
        app.staticTexts["Правила уроков"].tap()
        XCTAssertTrue(app.navigationBars["Правила уроков"].waitForExistence(timeout: 5))
        shot("44-all-rules")
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
