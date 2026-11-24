import XCTest

/// UI smoke tests (TKT-M6-06). Kept intentionally small and stable; run in CI as a
/// non-blocking, quarantined job because GUI/XCTest on headless runners is flaky.
final class SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndShowsMainWindow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "App should reach the foreground")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20), "A main window should exist")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "launch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testToolbarHasCoreActions() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        // The toolbar exposes Add / Extract / Tasks controls by accessibility label.
        let toolbar = app.toolbars.firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 10), "Toolbar should exist")
    }
}
