import XCTest

/// Screens 1 to 3.
final class OnboardingUITests: QeetIDUITestCase {
    @MainActor
    func testWelcomeLockAndNotificationsLeadToAccounts() {
        launch(onboarded: false)
        XCTAssertTrue(element("Sign in safely, with this iPhone").exists)
        XCTAssertTrue(element("Sign-in codes").exists)
        app.buttons["Get started"].tap()

        XCTAssertTrue(element("Lock Qeet ID").exists)
        XCTAssertTrue(element("Step 1 of 2").exists)
        XCTAssertTrue(textContaining("always asks for Face ID").exists)
        app.buttons["Continue"].tap()

        XCTAssertTrue(element("Get sign-in requests on this iPhone").exists)
        XCTAssertTrue(element("Only sign-in requests. Nothing else, no marketing.").exists)
        app.buttons["Not now"].tap()

        XCTAssertTrue(element("No accounts yet").exists)
    }

    @MainActor
    func testTheLockCanWait() {
        launch(onboarded: false)
        app.buttons["Get started"].tap()
        XCTAssertTrue(element("Lock Qeet ID").exists)
        app.buttons["Not now"].tap()
        XCTAssertTrue(element("Step 2 of 2").exists)
    }
}
