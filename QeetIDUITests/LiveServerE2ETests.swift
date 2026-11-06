import Foundation
import XCTest

/// The whole journey against a real, local Qeet ID server: this test plays the browser (sign-up, the console's pairing
/// code, a password sign-in that asks for push) and drives the app (link, pick up the request, type the number, Face ID
/// stubbed, approve or deny). Skipped unless the runner is given the server:
///
///     TEST_RUNNER_QEETID_E2E_URL=http://localhost:4001 xcodebuild test … -only-testing:QeetIDUITests/LiveServerE2ETests
final class LiveServerE2ETests: QeetIDUITestCase {
    var server: LiveServer!

    override func setUp() async throws {
        try await super.setUp()
        guard let url = ProcessInfo.processInfo.environment["QEETID_E2E_URL"], !url.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_QEETID_E2E_URL to run against a local Qeet ID server.")
        }
        server = LiveServer(baseURL: url)
    }

    /// Link with a real pairing code, then approve, deny, refuse a wrong number and let one expire; finally unlink.
    @MainActor
    func testLinkApproveDenyWrongNumberExpireAndUnlink() async throws {
        let email = "rohan.das.\(Int(Date().timeIntervalSince1970))@brightleaffoods.in"
        let account = try await server.signUp(email: email)
        let code = try await server.pairingCode(token: account.token)
        print("E2E account \(email), pairing code \(code)")

        // Link this iPhone by typing the code, as from the console's text.
        launch(arguments: ["-api-url", server.baseURL])
        app.buttons["empty.link"].tap()
        app.buttons["Type the code instead"].tap()
        type(code, into: app.textFields["Pairing code"])
        app.buttons["Link iPhone"].tap()
        allowSystemAlertIfShown(timeout: 3)
        XCTAssertTrue(waitAllowingAlerts(for: "iPhone linked", timeout: Self.linkTimeout))
        XCTAssertTrue(element(email).exists, "The server's account email is shown")
        app.buttons["Done"].tap()
        XCTAssertTrue(textContaining("Linked ·").exists)

        // 1. Approve with the right number: the browser is signed in.
        var signIn = try await server.startSignIn(email: email)
        print("E2E approve: number \(signIn.number)")
        openRequest()
        XCTAssertTrue(textContaining("Chrome on macOS").exists, "The browser from the sign-in's user agent")
        typeNumber(signIn.number)
        app.buttons["Approve"].tap()
        XCTAssertTrue(element("Sign-in approved", timeout: 15).exists)
        var result = try await server.poll(signIn)
        XCTAssertEqual(result, "approved")
        app.buttons["Done"].tap()

        // 2. Deny: the browser is refused.
        signIn = try await server.startSignIn(email: email)
        openRequest()
        app.buttons["Deny"].tap()
        XCTAssertTrue(element("Sign-in blocked", timeout: 15).exists)
        result = try await server.poll(signIn)
        XCTAssertEqual(result, "mfa.code_invalid")
        app.buttons["Done"].tap()

        // 3. A wrong number: the server refuses the sign-in, and the app says the request ended.
        signIn = try await server.startSignIn(email: email)
        openRequest()
        typeNumber(signIn.number == "99" ? "98" : "99")
        app.buttons["Approve"].tap()
        XCTAssertTrue(element("This request has ended", timeout: 15).exists)
        XCTAssertTrue(textContaining("The number didn't match").exists)
        result = try await server.poll(signIn)
        XCTAssertEqual(result, "mfa.code_invalid")
        app.buttons["Done"].tap()

        // 4. No answer for two minutes: the request expires on screen.
        signIn = try await server.startSignIn(email: email)
        openRequest()
        XCTAssertTrue(element("This request has ended", timeout: 150).exists)
        XCTAssertTrue(textContaining("Two minutes passed").exists)
        app.buttons["Done"].tap()

        // 5. Unlink: the server forgets this iPhone, and the codes stay.
        app.buttons["accounts.settings"].tap()
        app.buttons["settings.unlink"].tap()
        app.alerts["Unlink this iPhone?"].buttons["Unlink"].tap()
        XCTAssertTrue(element("This iPhone is unlinked", timeout: 15).exists)
        XCTAssertTrue(app.buttons["settings.link"].waitForExistence(timeout: 5))
    }

    /// A sign-in request's notification: the shell sends it with `xcrun simctl push` once this test prints the request's
    /// id (read from the app, Debug builds only); the notification service extension names the browser; tapping it opens
    /// the request, which is approved with the number.
    @MainActor
    func testANotificationOpensTheRequest() async throws {
        let email = "rohan.das.push.\(Int(Date().timeIntervalSince1970))@brightleaffoods.in"
        let account = try await server.signUp(email: email)
        let code = try await server.pairingCode(token: account.token)

        launch(arguments: ["-api-url", server.baseURL])
        app.buttons["empty.link"].tap()
        app.buttons["Type the code instead"].tap()
        type(code, into: app.textFields["Pairing code"])
        app.buttons["Link iPhone"].tap()
        allowSystemAlertIfShown(timeout: 3)
        XCTAssertTrue(waitAllowingAlerts(for: "iPhone linked", timeout: Self.linkTimeout))
        app.buttons["Done"].tap()

        // Start a sign-in, and read its request's id from the app (the browser never learns it), then leave the app.
        let signIn = try await server.startSignIn(email: email)
        openRequest()
        let challenge = app.staticTexts["request.id"].label
        XCTAssertNotNil(UUID(uuidString: challenge))
        app.buttons["request.close"].tap()
        XCUIDevice.shared.press(.home)
        print("E2E-PUSH-CHALLENGE \(challenge)")

        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Someone is signing in to your Qeet ID account")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 120), "No notification arrived")
        XCTAssertTrue(banner.label.contains("Sign-in request"), banner.label)
        // A device runs the notification service extension, which names the browser; the simulator doesn't run it for
        // `simctl push`, so the server's own text is what shows there.
        print("E2E-BANNER \(banner.label)")
        banner.tap()

        XCTAssertTrue(element("Are you signing in to Qeet ID?", timeout: 15).exists)
        let field =
            app.textFields["Number on your sign-in screen"].exists
            ? app.textFields["Number on your sign-in screen"] : app.textFields.firstMatch
        type(signIn.number, into: field)
        app.buttons["Approve"].tap()
        XCTAssertTrue(element("Sign-in approved", timeout: 15).exists)
        let result = try await server.poll(signIn)
        XCTAssertEqual(result, "approved")
    }

    /// The pending check finds the request on pull to refresh, or when the app comes back to the foreground.
    @MainActor
    private func openRequest() {
        XCTAssertTrue(openWaitingRequest(timeout: 15), "The waiting request didn't open")
    }

    @MainActor
    private func typeNumber(_ number: String) {
        let field =
            app.textFields["Number on your sign-in screen"].exists
            ? app.textFields["Number on your sign-in screen"] : app.textFields.firstMatch
        type(number, into: field)
    }
}

/// The browser's side of a sign-in, against the local server.
struct LiveServer {
    struct Account {
        let token: String
    }

    struct SignIn {
        let mfaToken: String
        let number: String
    }

    let baseURL: String
    private static let password = "Brightleaf-Ledger-2026!"
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/537.36 Chrome/131 Safari/537.36"

    func signUp(email: String) async throws -> Account {
        let (status, json) = try await post(
            "/v1/auth/signup", ["email": email, "password": Self.password, "display_name": "Rohan Das"])
        guard (200..<300).contains(status), let token = json["access_token"] as? String else {
            throw XCTSkip("Sign-up refused (\(status)): \(json)")
        }
        return Account(token: token)
    }

    func pairingCode(token: String) async throws -> String {
        let (status, json) = try await post("/v1/mfa/push/pairing", [:], bearer: token)
        guard (200..<300).contains(status), let code = json["code"] as? String else { throw URLError(.badServerResponse) }
        return code
    }

    /// Signs in with the password and starts push: the number the sign-in screen shows.
    func startSignIn(email: String) async throws -> SignIn {
        let (_, login) = try await post("/v1/auth/login", ["email": email, "password": Self.password])
        guard let mfaToken = login["mfa_token"] as? String else { throw URLError(.userAuthenticationRequired) }
        let (_, start) = try await post("/v1/auth/mfa/push", ["mfa_token": mfaToken])
        guard let number = (start["number"] as? Int).map(String.init) ?? start["number"] as? String else {
            throw URLError(.badServerResponse)
        }
        return SignIn(mfaToken: mfaToken, number: String(format: "%02d", Int(number) ?? 0))
    }

    /// What the browser's poll ends with: "approved", or the error code.
    func poll(_ signIn: SignIn) async throws -> String {
        for _ in 0..<30 {
            let (status, json) = try await post("/v1/auth/mfa", ["mfa_token": signIn.mfaToken, "push": true])
            if status == 200, json["access_token"] != nil { return "approved" }
            let code = (json["error"] as? [String: Any])?["code"] as? String ?? "status \(status)"
            if code != "mfa.push_pending" { return code }
            try await Task.sleep(for: .seconds(1))
        }
        return "timeout"
    }

    private func post(_ path: String, _ body: [String: Any], bearer: String? = nil) async throws -> (Int, [String: Any]) {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, json)
    }
}
