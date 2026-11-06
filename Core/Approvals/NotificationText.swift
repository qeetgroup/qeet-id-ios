import Foundation

/// A sign-in request's notification in the app's words, as the notification service extension writes it.
enum NotificationText {
    static var title: String { String(localized: "Sign-in request") }

    /// "Someone is signing in to your Qeet ID account from Chrome on macOS. Tap to review.", or without the browser
    /// when it isn't known.
    static func body(browser: String?) -> String {
        guard let browser else { return String(localized: "Someone is signing in to your Qeet ID account. Tap to review.") }
        return String(localized: "Someone is signing in to your Qeet ID account from \(browser). Tap to review.")
    }

    /// The text for a request, from its user agent.
    static func body(userAgent: String?) -> String {
        body(browser: UserAgentDescription.describe(userAgent))
    }
}
