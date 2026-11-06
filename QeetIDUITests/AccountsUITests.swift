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
        type("Razorpay", into: app.textFields["Service"])
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
        type("GitHub", into: app.textFields["Service"])
        type("JBSW1", into: app.textFields["Setup key"])
        app.textFields["Service"].tap()
        XCTAssertTrue(textContaining("a setup key can't have").exists)
        XCTAssertFalse(app.buttons["setup.add"].isEnabled)
    }

    @MainActor
    func testAdvancedSettingsShowTodaysChoice() {
        launch()
        app.buttons["empty.type"].tap()
        XCTAssertTrue(textContaining("6 digits · every 30 seconds · SHA-1").exists)
    }

    @MainActor
    func testTapToCopyShowsTheToast() {
        launch()
        addAccountByTyping(service: "GitHub", account: "brightleaf-foods")
        textContaining("GitHub, brightleaf-foods,").tap()
        XCTAssertTrue(element("Copied").waitForExistence(timeout: 5))
    }

    @MainActor
    func testRenameAndDeleteFromTheContextMenu() {
        launch()
        addAccountByTyping(service: "GitHub", account: "brightleaf-foods")
        element("GitHub").press(forDuration: 1.2)
        app.buttons["Rename"].tap()

        let alert = app.alerts["Rename account"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let service = alert.textFields.element(boundBy: 0)
        service.tap()
        service.typeText(" (work)")
        alert.buttons["Save"].tap()
        XCTAssertTrue(element("GitHub (work)").exists)

        element("GitHub (work)").press(forDuration: 1.2)
        app.buttons["Delete Account"].tap()
        XCTAssertTrue(textContaining("Turn off 2-step verification on GitHub (work) first").waitForExistence(timeout: 5))
        app.sheets.buttons["Delete Account"].firstMatch.tap()
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
        XCTAssertTrue(element("No results").exists)
    }

    @MainActor
    func testTheSameKeyTwiceIsRefused() {
        launch()
        addAccountByTyping(service: "GitHub")
        app.buttons["accounts.add"].tap()
        app.buttons["Type the key instead"].tap()
        type("GitHub copy", into: app.textFields["Service"])
        type("JBSW Y3DP EHPK 3PXP", into: app.textFields["Setup key"])
        app.buttons["setup.add"].tap()
        XCTAssertTrue(element("This account is already on this iPhone.").exists)
    }

    @MainActor
    func testHiddenCodesShowDotsUntilTapped() {
        launch()
        addAccountByTyping(service: "GitHub")
        app.buttons["accounts.settings"].tap()
        element("Hide codes until tapped").tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(textContaining("Code hidden").exists)
        textContaining("Code hidden").tap()
        XCTAssertFalse(textContaining("Code hidden").waitForExistence(timeout: 1))
    }
}

/// Screens 6 and 7: scanning (the simulator has no camera, so the app is handed what the camera would read).
final class ScanUITests: QeetIDUITestCase {
    @MainActor
    func testScanningASitesQRCodeAddsTheAccount() {
        launch(arguments: ["-ui-scan", "otpauth://totp/AWS:billing@brightleaffoods.in?secret=JBSWY3DPEHPK3PXP&issuer=AWS"])
        app.buttons["accounts.add"].tap()
        // The toast first: it dismisses itself, and a busy machine can spend its lifetime on the checks below.
        XCTAssertTrue(textContaining("AWS added", timeout: 10).exists)
        XCTAssertTrue(element("AWS").waitForExistence(timeout: 5))
        XCTAssertTrue(element("billing@brightleaffoods.in").exists)
    }

    @MainActor
    func testAQRCodeThatIsNotForCodesIsRefused() {
        launch(arguments: ["-ui-scan", "https://brightleaffoods.in"])
        app.buttons["accounts.add"].tap()
        XCTAssertTrue(element("Can't add this account").exists)
        XCTAssertTrue(element("Point the camera at the QR code").exists)
        app.buttons["scanner.cancel"].tap()
        XCTAssertTrue(element("No accounts yet").exists)
    }

    @MainActor
    func testTypingTheKeyFromTheScanner() {
        // No camera on the simulator: the scanner's way to type the key is there in every state.
        launch()
        app.buttons["accounts.add"].tap()
        app.buttons["Type the key instead"].tap()
        XCTAssertTrue(element("Setup key").exists)
        app.buttons["setup.cancel"].tap()
        XCTAssertTrue(element("Add account").exists)
    }
}
