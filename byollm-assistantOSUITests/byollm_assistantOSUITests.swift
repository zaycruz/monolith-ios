//
//  byollm_assistantOSUITests.swift
//  byollm-assistantOSUITests
//
//  Created by master on 11/16/25.
//

import XCTest

final class byollm_assistantOSUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

        let reasoningButton = app.buttons["Reasoning effort Medium"]
        XCTAssertTrue(reasoningButton.waitForExistence(timeout: 3))
        reasoningButton.tap()
        XCTAssertTrue(app.otherElements["Reasoning effort"].waitForExistence(timeout: 2))

        let reasoningScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        reasoningScreenshot.name = "reasoning-effort-expanded"
        reasoningScreenshot.lifetime = .keepAlways
        add(reasoningScreenshot)

        app.staticTexts["What should we work on?"].tap()
        XCTAssertFalse(app.otherElements["Reasoning effort"].exists)
    }

    @MainActor
    func testLeadingEdgeSwipeOpensNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertTrue(app.buttons["Close navigation"].waitForExistence(timeout: 2))
        Thread.sleep(forTimeInterval: 0.5)

        let drawerScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        drawerScreenshot.name = "drawer-opened-by-swipe"
        drawerScreenshot.lifetime = .keepAlways
        add(drawerScreenshot)
    }

    @MainActor
    func testDrawerDismissesComposerKeyboardAndSpeechButtonIsAvailable() throws {
        let app = XCUIApplication()
        app.launch()

        let composer = app.textFields["Ask anything"]
        XCTAssertTrue(composer.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Start speech to text"].exists)
        composer.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        app.buttons["Open navigation"].tap()

        XCTAssertTrue(app.buttons["Close navigation"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 1))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
