import XCTest

/// Walks the app and attaches a screenshot of every screen.
/// Nobody on this project has a simulator, so these attachments are how the UI gets reviewed.
final class ScreensTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEveryTabOpens() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Уроки"].waitForExistence(timeout: 10))
        attachScreenshot("lessons")

        app.tabBars.buttons["Практика"].tap()
        XCTAssertTrue(app.navigationBars["Практика"].waitForExistence(timeout: 5))
        attachScreenshot("practice")

        app.tabBars.buttons["Разбор"].tap()
        XCTAssertTrue(app.staticTexts["les enfants"].waitForExistence(timeout: 5))
        attachScreenshot("analysis")

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    @MainActor
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
