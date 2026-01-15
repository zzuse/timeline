//
//  timelineUITests.swift
//  timelineUITests
//
//  Created by zhen zhang on 2026-01-14.
//

import XCTest

final class timelineUITests: XCTestCase {

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
    private func createNote(app: XCUIApplication, text: String) {
        app.navigationBars["Timeline"].buttons["New Note"].tap()
        let textEditor = app.textViews.firstMatch
        textEditor.tap()
        textEditor.typeText(text)
        app.navigationBars["New Note"].buttons["Save"].tap()
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    func testTimelineShowsNavTitle() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Timeline"].exists)
    }

    @MainActor
    func testComposeOpensSheet() throws {
        let app = XCUIApplication()
        app.launch()

        app.navigationBars["Timeline"].buttons["New Note"].tap()
        XCTAssertTrue(app.navigationBars["New Note"].exists)
    }

    @MainActor
    func testComposeSaveFailureShowsAlert() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-simulateSaveFailure")
        app.launch()

        app.navigationBars["Timeline"].buttons["New Note"].tap()

        let textEditor = app.textViews.firstMatch
        textEditor.tap()
        textEditor.typeText("Draft")

        app.navigationBars["New Note"].buttons["Save"].tap()

        let alert = app.alerts["Unable to Save"]
        XCTAssertTrue(alert.exists)
        alert.buttons["OK"].tap()

        XCTAssertTrue(app.navigationBars["New Note"].exists)
        let value = textEditor.value as? String ?? ""
        XCTAssertTrue(value.contains("Draft"))
    }

    @MainActor
    func testDetailViewPinToggle() throws {
        let app = XCUIApplication()
        app.launch()

        createNote(app: app, text: "Detail Note")
        app.staticTexts["Detail Note"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Note"].exists)
        let pinButton = app.navigationBars["Note"].buttons["Pin"]
        XCTAssertTrue(pinButton.exists)
        pinButton.tap()
        XCTAssertTrue(app.navigationBars["Note"].buttons["Unpin"].exists)
    }
}
