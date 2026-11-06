import XCTest

/// Screen 21 and the lock in Settings.
final class LockUITests: QeetIDUITestCase {
    @MainActor
    func testTheLockedScreenAsksAgainAfterAFailedCheck() {
        launch(arguments: ["-ui-lock-on", "-ui-auth", "failed"])
        XCTAssertTrue(element("Qeet ID is locked").exists)
        XCTAssertTrue(element("Unlock to see your codes and sign-in requests.").exists)
        XCTAssertTrue(app.buttons["locked.unlock"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["locked.failed"].waitForExistence(timeout: 5))
        XCTAssertFalse(element("Accounts", timeout: 1).isHittable)
    }

    @MainActor
    func testUnlockingOpensTheAccounts() {
        launch(arguments: ["-ui-lock-on"])
        XCTAssertTrue(element("No accounts yet", timeout: 8).exists)
        XCTAssertFalse(element("Qeet ID is locked", timeout: 1).exists)
    }

    @MainActor
    func testTurningTheLockOnInSettings() {
        launch()
        app.buttons["accounts.settings"].tap()
        let lock = element("Face ID lock")
        XCTAssertTrue(lock.exists)
        lock.tap()
        XCTAssertTrue(app.switches["Face ID lock"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["Face ID lock"].value as? String, "1")
    }
}
