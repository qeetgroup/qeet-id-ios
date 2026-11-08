import Foundation

/// A sign-in request's notification in the app's words, as the notification service extension writes it.
enum NotificationText {
    static var title: String { String(localized: "Sign-in request") }

    /// "Chrome on macOS, near Bengaluru, is signing in to your Qeet ID account. Tap to review.", with what's known of
    /// the browser and the place, so a request nobody expected stands out before the app is open.
    static func body(browser: String?, place: String? = nil) -> String {
        let place = place.flatMap { $0.isEmpty ? nil : $0 }
        switch (browser, place) {
        case (let browser?, let place?):
            return String(localized: "\(browser), near \(place), is signing in to your Qeet ID account. Tap to review.")
        case (let browser?, nil):
            return String(localized: "\(browser) is signing in to your Qeet ID account. Tap to review.")
        default:
            return String(localized: "Someone is signing in to your Qeet ID account. Tap to review.")
        }
    }

    /// The text for a request, from its user agent and the place its address points to.
    static func body(userAgent: String?, location: String? = nil) -> String {
        body(browser: UserAgentDescription.describe(userAgent), place: location)
    }
}
