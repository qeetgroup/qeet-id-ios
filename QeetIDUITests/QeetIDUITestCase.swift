import XCTest

/// Launches the app for a UI test: empty storage, Face ID answered by a stub (Debug builds only), and system alerts
/// allowed when they appear.
class QeetIDUITestCase: XCTestCase {
    var app: XCUIApplication!
    @MainActor var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    /// How long a link may take on screen. Linking first asks iOS for the notification settings, and a heavily loaded
    /// simulator has taken over 30 s to answer that, before the app sends anything.
    static let linkTimeout: TimeInterval = 90

    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor
    func launch(onboarded: Bool = true, arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (onboarded ? ["-ui-onboarded"] : []) + arguments
        app.launch()
    }

    /// Taps Allow on a system permission prompt, if one is up (notifications, camera). The prompt may be SpringBoard's
    /// alert or hosted in the app, depending on the iOS version, so any "Allow" button in either counts.
    @MainActor
    func allowSystemAlertIfShown(timeout: TimeInterval = 2) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for root in [springboard, app!] {
                let allow = root.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == 'Allow Notifications'")).firstMatch
                if allow.exists {
                    allow.tap()
                    return
                }
            }
            if timeout > 0 { Thread.sleep(forTimeInterval: 0.25) }
        } while Date() < deadline
    }

    /// Waits for `text` while allowing any system permission alert that appears meanwhile (it can come late).
    @MainActor
    func waitAllowingAlerts(for text: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element(text, timeout: 1).exists { return true }
            allowSystemAlertIfShown(timeout: 0.5)
        }
        return element(text, timeout: 1).exists
    }

    /// Focuses a field: the search bar at the bottom of iOS 27 can take a second tap.
    @MainActor
    func focus(_ field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 {
            field.tap()
            if XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: focused, object: field)], timeout: 2) == .completed { return }
        }
    }

    @MainActor
    func element(_ text: String, timeout: TimeInterval = 5) -> XCUIElement {
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR identifier == %@", text, text)).firstMatch
        _ = match.waitForExistence(timeout: timeout)
        return match
    }

    @MainActor
    func textContaining(_ text: String, timeout: TimeInterval = 5) -> XCUIElement {
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        _ = match.waitForExistence(timeout: timeout)
        return match
    }

    /// Taps an account's code. The row reads as one element (Qeetrix's list row), so this taps where the code sits:
    /// under the title, towards the start.
    @MainActor
    func tapCode(inRowContaining text: String) {
        let row = textContaining(text)
        XCTAssertTrue(row.exists, "No account row reads \(text)")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75)).tap()
    }

    @MainActor
    func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No field \(field)")
        field.tap()
        field.typeText(text)
    }

    /// Opens a waiting request the way the app finds one without push: pull to refresh on Accounts, then — if that
    /// isn't enough — leaving the app and coming back to it, which checks too.
    @MainActor
    func openWaitingRequest(timeout: TimeInterval = 10) -> Bool {
        let title = "Is this you signing in?"
        let list = app.collectionViews.firstMatch
        if list.waitForExistence(timeout: 5) {
            for _ in 0..<2 {
                let top = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
                top.press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
                if element(title, timeout: 4).exists { return true }
            }
        }
        XCUIDevice.shared.press(.home)
        app.activate()
        return element(title, timeout: timeout).exists
    }

    /// Adds an account through the setup-key sheet, from the empty state or the + button.
    @MainActor
    func addAccountByTyping(service: String, account: String = "", key: String = "JBSW Y3DP EHPK 3PXP") {
        if app.buttons["empty.type"].waitForExistence(timeout: 2) {
            app.buttons["empty.type"].tap()
        } else {
            app.buttons["accounts.add"].tap()
            app.buttons["add.type"].tap()
        }
        type(service, into: app.textFields["Site or app"])
        if !account.isEmpty { type(account, into: app.textFields["Account"]) }
        type(key, into: app.textFields["Setup key"])
        app.buttons["setup.add"].tap()
        XCTAssertTrue(element(service).waitForExistence(timeout: 5), "\(service) wasn't added")
    }
}
