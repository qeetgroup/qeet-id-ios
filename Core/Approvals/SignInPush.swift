import Foundation

/// A sign-in request's push, as the server sends it through APNs: `type`, `challenge_id` and `action` beside `aps`.
///
/// ```json
/// {"aps": {"alert": {...}, "interruption-level": "time-sensitive", "mutable-content": 1, "thread-id": "sign-in"},
///  "type": "sign_in_request", "challenge_id": "<uuid>", "action": "sign_in"}
/// ```
enum SignInPush {
    static let type = "sign_in_request"
    /// Groups every sign-in request in Notification Center.
    static let threadIdentifier = "sign-in"
    /// The category the app registers for its requests.
    static let categoryIdentifier = "SIGN_IN_REQUEST"

    /// The request a notification is about, or `nil` when it isn't a sign-in request.
    static func challengeID(in userInfo: [AnyHashable: Any]) -> UUID? {
        if let type = userInfo["type"] as? String, type != Self.type { return nil }
        guard let text = userInfo["challenge_id"] as? String else { return nil }
        return UUID(uuidString: text)
    }
}
