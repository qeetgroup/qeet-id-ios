import XCTest

/// Screens 4 to 10 and 26: adding, copying, renaming, deleting and searching accounts.
final class AccountsUITests: QeetIDUITestCase {
    @MainActor
    func testEmptyStateOffersBothWaysIn() {
        launch()
        XCTAssertTrue(element("No accounts yet").exists)
        XCTAssertTrue(app.buttons["empty.scan"].exists)
        XCTAssertTrue(app.buttons["empty.type"].exists)
        XCTAssertTrue(textContaining("Link this iPhone").exists)
    }

    @MainActor
    func testTypingTheKeyAddsAnAccountWithACode() {
        launch()
        app.buttons["empty.type"].tap()
        let add = app.buttons["setup.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(add.isEnabled, "Add waits for a valid key")
        type("Razorpay", into: app.textFields["Site or app"])
        type("accounts@brightleaffoods.in", into: app.textFields["Account"])
        type("JBSW Y3DP EHPK 3PXP", into: app.textFields["Setup key"])
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(element("Razorpay").exists)
        XCTAssertTrue(element("accounts@brightleaffoods.in").exists)
        XCTAssertTrue(textContaining("Razorpay, accounts@brightleaffoods.in,").exists, "The code reads with its account")
        XCTAssertTrue(element("Codes").exists)
    }

    @MainActor
    func testABadKeyIsExplained() {
        launch()
        app.buttons["empty.type"].tap()
        type("GitHub", into: app.textFields["Site or app"])
        type("JBSW1", into: app.textFields["Setup key"])
        XCTAssertTrue(textContaining("Keys use only A–Z and 2–7").exists, "A wrong character is said at once")
        XCTAssertFalse(app.buttons["setup.add"].isEnabled)
    }

    @MainActor
    func testAdvancedSettingsShowTodaysChoice() {
        launch()
        app.buttons["empty.type"].tap()
        XCTAssertTrue(textContaining("6 digits · every 30 s · SHA-1").exists)
    }

    @MainActor
    func testTapToCopyShowsTheToast() {
        launch()
        addAccountByTyping(service: "GitHub", account: "brightleaf-foods")
        tapCode(inRowContaining: "GitHub, brightleaf-foods,")
        XCTAssertTrue(element("Copied").waitForExistence(timeout: 5))
    }

    @MainActor
    func testRenameAndRemoveFromTheContextMenu() {
        launch()
        addAccountByTyping(service: "GitHub", account: "brightleaf-foods")
        element("GitHub").press(forDuration: 1.2)
        app.buttons["Rename"].tap()

        let alert = app.alerts["Rename"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let service = alert.textFields.element(boundBy: 0)
        service.tap()
        service.typeText(" (work)")
        alert.buttons["Save"].tap()
        XCTAssertTrue(element("GitHub (work)").exists)

        element("GitHub (work)").press(forDuration: 1.2)
        app.buttons["Remove from this iPhone"].tap()
        let remove = app.alerts["Remove GitHub (work)?"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        XCTAssertTrue(
            remove.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Turn off 2-step verification there first")).firstMatch
                .exists)
        remove.buttons["Remove"].tap()
        XCTAssertTrue(element("No accounts yet").exists)
    }

    @MainActor
    func testSearchFiltersAccounts() {
        launch()
        addAccountByTyping(service: "GitHub")
        addAccountByTyping(service: "AWS", key: "GEZD GNBV GY3T QOJQ")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        focus(search)
        search.typeText("aws")
        XCTAssertTrue(element("AWS").exists)
        XCTAssertFalse(app.staticTexts["GitHub"].waitForExistence(timeout: 1))
        search.typeText("zzz")
        XCTAssertTrue(textContaining("No accounts match").exists)
    }

    @MainActor
    func testTheSameKeyTwiceIsRefused() {
        launch()
        addAccountByTyping(service: "GitHub")
        app.buttons["accounts.add"].tap()
        app.buttons["add.type"].tap()
        type("GitHub copy", into: app.textFields["Site or app"])
        type("JBSW Y3DP EHPK 3PXP", into: app.textFields["Setup key"])
        app.buttons["setup.add"].tap()
        XCTAssertTrue(element("This account is already on this iPhone.").exists)
    }

    @MainActor
    func testHiddenCodesShowDotsUntilTapped() {
        launch()
        addAccountByTyping(service: "GitHub")
        app.buttons["accounts.settings"].tap()
        app.switches["settings.hide-codes"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(textContaining("Code hidden").exists)
        // The next code starts hidden again, so tap with time left in this one: a tap in its last seconds would be
        // followed by the next, hidden code before the check.
        let secondsLeft = 30 - Int(Date().timeIntervalSince1970) % 30
        if secondsLeft < 6 { sleep(UInt32(secondsLeft + 1)) }
        tapCode(inRowContaining: "Code hidden")
        XCTAssertTrue(textContaining("Code hidden", timeout: 0).waitForNonExistence(timeout: 2), "The tap shows the code")
    }
}

/// Screens 6 and 7: scanning (the simulator has no camera, so the app is handed what the camera would read).
final class ScanUITests: QeetIDUITestCase {
    @MainActor
    func testScanningASitesQRCodeAsksBeforeAdding() {
        launch(arguments: ["-ui-scan", "otpauth://totp/AWS:billing@brightleaffoods.in?secret=JBSWY3DPEHPK3PXP&issuer=AWS"])
        app.buttons["accounts.add"].tap()
        app.buttons["add.scan"].tap()
        XCTAssertTrue(element("Add this account?", timeout: 10).exists, "What was found is shown before adding")
        XCTAssertTrue(textContaining("AWS · billing@brightleaffoods.in").exists)
        app.buttons["scan.add"].tap()
        // The toast first: it dismisses itself, and a busy machine can spend its lifetime on the checks below.
        XCTAssertTrue(textContaining("AWS added", timeout: 10).exists)
        XCTAssertTrue(element("AWS").waitForExistence(timeout: 5))
        XCTAssertTrue(element("billing@brightleaffoods.in").exists)
    }

    @MainActor
    func testAQRCodeThatIsNotForCodesIsRefused() {
        launch(arguments: ["-ui-scan", "https://brightleaffoods.in/settings"])
        app.buttons["accounts.add"].tap()
        app.buttons["add.scan"].tap()
        XCTAssertTrue(textContaining("a sign-in code", timeout: 10).exists)
        XCTAssertTrue(textContaining("It opens a web page, brightleaffoods.in/settings").exists)
        app.buttons["scanner.cancel"].tap()
        XCTAssertTrue(element("No accounts yet").exists)
    }

    @MainActor
    func testTypingTheKeyFromTheScanner() {
        // No camera on the simulator: the scanner's way to type the key is there in every state.
        launch()
        app.buttons["accounts.add"].tap()
        app.buttons["add.scan"].tap()
        // The scanner's own button: the empty Accounts screen under it has one with the same words.
        let typeInstead = app.otherElements["add-account"].buttons["Type the key instead"]
        XCTAssertTrue(typeInstead.waitForExistence(timeout: 8))
        typeInstead.tap()
        XCTAssertTrue(element("Setup key").exists)
        app.buttons["setup.cancel"].tap()
        XCTAssertTrue(element("Scan a QR code").exists)
    }
}
