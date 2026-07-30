import XCTest

final class TaliUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-tali-ui-test"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Tali"].waitForExistence(timeout: 8))
    }

    @MainActor
    override func tearDown() async throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Tali failure"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app.terminate()
    }

    @MainActor
    func testEmptyStateExplainsProductWithoutSuggestedHabits() {
        XCTAssertTrue(app.staticTexts["Track something"].exists)
        XCTAssertTrue(app.staticTexts["Add a habit, then log it whenever it happens."].exists)
        XCTAssertTrue(app.staticTexts["Activity"].exists)
        XCTAssertTrue(app.staticTexts["Activity will appear here."].exists)
        XCTAssertFalse(app.buttons["Activity filter"].exists)
        XCTAssertFalse(app.buttons["Log an entry"].isEnabled)
    }

    @MainActor
    func testCriticalLocalJourney() {
        addHabit(named: "Yoga", aliases: "stretch")

        XCTAssertTrue(app.staticTexts["No entries yet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Log an entry"].isEnabled)
        app.buttons["Log an entry"].tap()

        XCTAssertTrue(app.navigationBars["Add Entry"].waitForExistence(timeout: 3))
        let note = app.textFields["entry.note"]
        note.tap()
        note.typeText("Hips felt better")
        app.buttons["entry.confirm"].tap()

        XCTAssertTrue(app.staticTexts["MOST RECENT"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Yoga"].exists)

        app.buttons["dashboard.habit.yoga"].tap()
        XCTAssertTrue(app.navigationBars["Yoga"].waitForExistence(timeout: 3))
        let heatmap = app.descendants(matching: .any)
            .matching(identifier: "activity.heatmap")
            .firstMatch
        XCTAssertTrue(heatmap.exists)
        let savedNote = app.descendants(matching: .any)
            .matching(identifier: "habit.event.note")
            .firstMatch
        XCTAssertTrue(
            scrollToExistence(savedNote),
            "The saved history note should remain discoverable below the activity chart."
        )
        XCTAssertEqual(savedNote.label, "Hips felt better")

        app.buttons["habit.actions"].tap()
        let timeSinceToggle = app.descendants(matching: .any)
            .matching(identifier: "habit.timeSinceToggle")
            .firstMatch
        XCTAssertTrue(timeSinceToggle.waitForExistence(timeout: 2))
        timeSinceToggle.tap()
        XCTAssertFalse(app.staticTexts["TIME SINCE"].exists)
    }

    @MainActor
    func testExportChoicesAreDiscoverable() {
        app.buttons["dashboard.more"].tap()
        XCTAssertTrue(app.buttons["All data as CSV"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Complete archive as JSON"].exists)
    }

    @MainActor
    private func addHabit(named name: String, aliases: String) {
        app.buttons["dashboard.empty.addHabit"].tap()
        XCTAssertTrue(app.navigationBars["New Habit"].waitForExistence(timeout: 3))

        let nameField = app.textFields["habit.add.name"]
        nameField.tap()
        nameField.typeText(name)

        let aliasesField = app.textFields["habit.add.aliases"]
        aliasesField.tap()
        aliasesField.typeText(aliases)

        app.buttons["habit.add.confirm"].tap()
        XCTAssertTrue(app.navigationBars["Tali"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["dashboard.habit.yoga"].exists)
    }

    @MainActor
    private func scrollToExistence(
        _ element: XCUIElement,
        maximumSwipes: Int = 3
    ) -> Bool {
        if element.waitForExistence(timeout: 1) {
            return true
        }

        let scrollContainer = app.descendants(matching: .any)
            .matching(identifier: "habit.detail.list")
            .firstMatch

        for _ in 0..<maximumSwipes {
            if scrollContainer.exists {
                scrollContainer.swipeUp()
            } else {
                app.swipeUp()
            }
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }
}
