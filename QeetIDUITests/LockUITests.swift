import XCTest

/// Screen 21 and the lock in Settings.
final class LockUITests: QeetIDUITestCase {
    @MainActor
    func testTheLockedScreenAsksAgainAfterAFailedCheck() {
        launch(arguments: ["-ui-lock-on", "-ui-auth", "failed"])
        XCTAssertTrue(element("Qeet ID is locked").exists)
        XCTAssertTrue(element("Unlock to see your codes and sign-in requests.").exists)
        XCTAssertTrue(app.otherElements["locked"].buttons["Unlock with Face ID"].exists)
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
        XCTAssertTrue(element("Lock with Face ID").exists)
        let lock = app.switches["settings.lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 5))
        lock.tap()
        XCTAssertTrue(NSPredicate(format: "value == '1'").evaluate(with: lock) || lock.value as? String == "1")
    }
}
