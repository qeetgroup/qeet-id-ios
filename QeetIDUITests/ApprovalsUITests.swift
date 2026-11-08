import XCTest

/// Screens 11 to 20 and 22 to 23 against a stub of Qeet ID's API: linking, a request found by the pending check, the
/// number, Face ID (stubbed), every outcome, and unlinking.
final class ApprovalsUITests: QeetIDUITestCase {
    var server: StubServer!
    var baseURL = ""

    override func setUp() async throws {
        try await super.setUp()
        server = try StubServer()
        baseURL = try server.start()
        server.route("POST", "/v1/mfa/push/pairing/claim") { _ in StubAPI.claim }
        server.route("POST", "/v1/mfa/push/devices/\(StubAPI.deviceID)/pending") { _ in StubAPI.noPending }
        server.route("POST", "/v1/mfa/push/devices/\(StubAPI.deviceID)/push-token") { _ in .init(status: 204) }
    }

    override func tearDown() async throws {
        server.stop()
        try await super.tearDown()
    }

    @MainActor
    func launchAgainstStub(_ arguments: [String] = []) {
        launch(arguments: ["-api-url", baseURL] + arguments)
    }

    /// Links by typing the code, as from the empty state's "Link this iPhone".
    @MainActor
    func linkByTyping(_ code: String = "km7qx 4trwp") {
        app.buttons["accounts.link"].tap()
        XCTAssertTrue(element("Approve sign-ins here").exists)
        app.buttons["Type the code"].tap()
        type(code, into: app.textFields["Pairing code"])
        app.otherElements["link.name-screen"].buttons["Link this iPhone"].tap()
        allowSystemAlertIfShown(timeout: 3)
    }

    @MainActor
    func linkAndOpenARequest(expiresIn seconds: TimeInterval = 120) {
        launchAgainstStub()
        linkByTyping()
        XCTAssertTrue(waitAllowingAlerts(for: "This iPhone is linked", timeout: Self.linkTimeout))
        app.buttons["Done"].tap()
        server.route("POST", "/v1/mfa/push/devices/\(StubAPI.deviceID)/pending") { _ in StubAPI.pending(expiresIn: seconds) }
        XCTAssertTrue(openWaitingRequest(), "The waiting request didn't open")
    }

    @MainActor
    func typeNumber(_ number: String) {
        let field =
            app.textFields["Number on your sign-in screen"].exists
            ? app.textFields["Number on your sign-in screen"] : app.textFields.firstMatch
        type(number, into: field)
    }

    @MainActor
    func testLinkingShowsTheAccountAndThisIPhone() throws {
        launchAgainstStub()
        linkByTyping()
        XCTAssertTrue(waitAllowingAlerts(for: "This iPhone is linked", timeout: Self.linkTimeout))
        XCTAssertTrue(element("meera@brightleaffoods.in").exists)
        XCTAssertTrue(textContaining("a request comes to this iPhone").exists)
        let claim = try XCTUnwrap(server.requests("POST", pathSuffix: "/pairing/claim").first)
        XCTAssertEqual(claim.json["code"] as? String, "KM7QX-4TRWP")
        XCTAssertEqual(claim.json["platform"] as? String, "ios")
        XCTAssertFalse((claim.json["push_token"] as? String ?? "").isEmpty)
        app.buttons["Done"].tap()
        XCTAssertTrue(textContaining("For meera@brightleaffoods.in").exists)
        XCTAssertTrue(element("On").exists)
    }

    @MainActor
    func testAWrongPairingCodeIsExplained() {
        server.route("POST", "/v1/mfa/push/pairing/claim") { _ in
            .init(status: 401, json: #"{"error":{"code":"mfa.pairing_code_invalid"}}"#)
        }
        launchAgainstStub()
        linkByTyping()
        XCTAssertTrue(textContaining("That code is wrong, already used or expired", timeout: Self.linkTimeout).exists)
    }

    @MainActor
    func testATypedCodeMustHaveTenCharacters() {
        launchAgainstStub()
        linkByTyping("KM7QX")
        XCTAssertTrue(textContaining("Enter the 10-character code").exists)
        XCTAssertTrue(server.requests("POST", pathSuffix: "/pairing/claim").isEmpty)
    }

    @MainActor
    func testScanningThePairingCodeFillsItIn() {
        launchAgainstStub(["-ui-scan", "qeetidauth://pair?code=KM7QX-4TRWP"])
        app.buttons["accounts.link"].tap()
        app.buttons["Scan the code"].tap()
        XCTAssertTrue(element("Name this iPhone", timeout: 8).exists)
        XCTAssertFalse(app.textFields["Pairing code"].exists, "A scanned code isn't typed again")
        XCTAssertTrue(server.requests("POST", pathSuffix: "/pairing/claim").isEmpty, "Linking waits for the tap")
    }

    @MainActor
    func testTheScannerRefusesOtherCodes() {
        launchAgainstStub(["-ui-scan", "otpauth://totp/A:b?secret=JBSWY3DPEHPK3PXP"])
        app.buttons["accounts.link"].tap()
        app.buttons["Scan the code"].tap()
        XCTAssertTrue(textContaining("sign-in code", timeout: 8).exists)
        XCTAssertTrue(app.buttons["Add to Accounts"].exists)
    }

    @MainActor
    func testApprovingWithTheNumber() throws {
        server.route("POST", "/v1/mfa/push/challenges/\(StubAPI.challengeID)/respond") { _ in
            .init(status: 200, json: #"{"status":"approved"}"#)
        }
        linkAndOpenARequest()
        XCTAssertTrue(element("Chrome on macOS").exists)
        XCTAssertTrue(element("Near Hyderabad, India").exists)
        XCTAssertTrue(element("IP address 49.205.143.27").exists)
        XCTAssertTrue(textContaining("To meera@brightleaffoods.in").exists)

        XCTAssertFalse(app.buttons["Approve"].isEnabled, "Approve waits for the number")
        typeNumber("47")
        app.buttons["Approve"].tap()
        XCTAssertTrue(element("Sign-in approved", timeout: 10).exists)
        XCTAssertTrue(textContaining("Go back to the computer").exists)
        XCTAssertTrue(element("Chrome on macOS").exists)
        let respond = try XCTUnwrap(server.requests("POST", pathSuffix: "/respond").first)
        XCTAssertEqual(respond.json["approved"] as? Bool, true)
        XCTAssertEqual(respond.json["number"] as? Int, 47)
        XCTAssertEqual(respond.json["device_token"] as? String, "stub-device-credential")
        app.buttons["Done"].tap()
        XCTAssertTrue(element("Sign-in approvals").exists)
    }

    @MainActor
    func testAWrongNumberEndsTheRequest() {
        server.route("POST", "/v1/mfa/push/challenges/\(StubAPI.challengeID)/respond") { _ in
            .init(status: 403, json: #"{"error":{"code":"mfa.push_number_mismatch"}}"#)
        }
        linkAndOpenARequest()
        typeNumber("12")
        app.buttons["Approve"].tap()
        XCTAssertTrue(textContaining("So the sign-in was stopped", timeout: 10).exists)
        XCTAssertTrue(element("Chrome on macOS").exists, "The request stays on screen")
    }

    @MainActor
    func testDenyingBlocksTheSignIn() throws {
        server.route("POST", "/v1/mfa/push/challenges/\(StubAPI.challengeID)/respond") { _ in
            .init(status: 200, json: #"{"status":"denied"}"#)
        }
        linkAndOpenARequest()
        app.buttons["Deny"].tap()
        XCTAssertTrue(element("Sign-in denied", timeout: 10).exists)
        XCTAssertTrue(app.buttons["Change password"].exists)
        let respond = try XCTUnwrap(server.requests("POST", pathSuffix: "/respond").first)
        XCTAssertEqual(respond.json["approved"] as? Bool, false)
    }

    @MainActor
    func testARequestExpiresOnScreen() {
        linkAndOpenARequest(expiresIn: 6)
        XCTAssertTrue(element("This request ended", timeout: 15).exists)
        XCTAssertTrue(textContaining("within 2 minutes").exists)
    }

    @MainActor
    func testUnlinkingFromSettings() throws {
        server.route("POST", "/v1/mfa/push/devices/\(StubAPI.deviceID)/unlink") { _ in .init(status: 204) }
        launchAgainstStub()
        linkByTyping()
        XCTAssertTrue(waitAllowingAlerts(for: "This iPhone is linked", timeout: Self.linkTimeout))
        app.buttons["Done"].tap()
        app.buttons["accounts.settings"].tap()
        XCTAssertTrue(element("meera@brightleaffoods.in").exists)
        app.buttons["settings.unlink"].tap()
        let alert = app.alerts["Unlink this iPhone?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "meera@brightleaffoods.in")).firstMatch.exists)
        alert.buttons["Unlink"].tap()
        XCTAssertTrue(element("This iPhone is unlinked", timeout: 10).exists)
        XCTAssertTrue(app.buttons["settings.link"].waitForExistence(timeout: 5))
        let unlink = try XCTUnwrap(server.requests("POST", pathSuffix: "/unlink").first)
        XCTAssertEqual(unlink.json["user_id"] as? String, StubAPI.userID)
    }
}

/// Screens 22 and 25.
final class SettingsUITests: QeetIDUITestCase {
    @MainActor
    func testSettingsCards() {
        launch()
        app.buttons["accounts.settings"].tap()
        XCTAssertTrue(element("Sign-in approvals").exists)
        XCTAssertTrue(element("Security").exists)
        XCTAssertTrue(element("Hide codes until tapped").exists)
        XCTAssertTrue(element("About and help").exists)
        XCTAssertTrue(element("Administration").exists)
        XCTAssertTrue(app.buttons["settings.link"].exists)
    }

    @MainActor
    func testAutoFillCodesPage() {
        launch()
        app.buttons["accounts.settings"].tap()
        element("AutoFill codes").tap()
        XCTAssertTrue(element("Fill in codes with a tap").exists)
        XCTAssertTrue(app.buttons["Turn on AutoFill"].exists)
        XCTAssertTrue(textContaining("No copying.").exists)
    }
}
