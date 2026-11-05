import Foundation
import UserNotifications
import os

/// Writes a sign-in request's notification in the app's words and adds where the sign-in comes from ("from Chrome on
/// macOS"), from the request itself. Whatever goes wrong — no network, a slow server, the time running out — the
/// server's text is shown as it came.
final class NotificationService: UNNotificationServiceExtension {
    private var delivery: Delivery?

    override func didReceive(
        _ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let id = SignInPush.challengeID(in: request.content.userInfo),
            let content = request.content.mutableCopy() as? UNMutableNotificationContent
        else {
            contentHandler(request.content)
            return
        }
        content.threadIdentifier = SignInPush.threadIdentifier
        let delivery = Delivery(content: content, handler: contentHandler)
        self.delivery = delivery
        Task {
            if let enriched = await Self.enrichedText(for: id) {
                delivery.update(title: enriched.title, body: enriched.body)
            }
            delivery.deliver()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        delivery?.deliver()
    }

    /// The app's title and body for the request, or `nil` to keep the server's.
    static func enrichedText(for id: UUID) async -> (title: String, body: String)? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10
        let client = APIClient(baseURL: APIEnvironment.baseURL, session: URLSession(configuration: configuration))
        guard let fetched = try? await client.challenge(id), fetched.challenge.status == .pending else { return nil }
        return (
            String(localized: "Sign-in request"),
            NotificationText.body(browser: UserAgentDescription.describe(fetched.challenge.context.userAgent))
        )
    }
}

/// The notification's words.
enum NotificationText {
    static func body(browser: String?) -> String {
        guard let browser else { return String(localized: "Someone is signing in to your Qeet ID account. Tap to review.") }
        return String(localized: "Someone is signing in to your Qeet ID account from \(browser). Tap to review.")
    }
}

/// The content and its handler, delivered once: by the enrichment or by the time running out, whichever comes first.
private final class Delivery: Sendable {
    private struct State {
        var content: UNMutableNotificationContent
        var handler: ((UNNotificationContent) -> Void)?
    }

    private let state: OSAllocatedUnfairLock<State>

    init(content: UNMutableNotificationContent, handler: @escaping (UNNotificationContent) -> Void) {
        state = OSAllocatedUnfairLock(uncheckedState: State(content: content, handler: handler))
    }

    func update(title: String, body: String) {
        state.withLockUnchecked { state in
            state.content.title = title
            state.content.body = body
        }
    }

    func deliver() {
        let pending = state.withLockUnchecked { state -> (UNNotificationContent, ((UNNotificationContent) -> Void)?) in
            defer { state.handler = nil }
            return (state.content, state.handler)
        }
        pending.1?(pending.0)
    }
}
