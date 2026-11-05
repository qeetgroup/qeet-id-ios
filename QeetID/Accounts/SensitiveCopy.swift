import UIKit

/// Copies a code the way `QeetrixOTPCode` does when it's tapped, for the context menu's Copy Code: on this iPhone only
/// (never the Universal Clipboard) and removed by the system after 60 seconds. The code is never logged.
enum SensitiveCopy {
    static let lifetime: TimeInterval = 60

    @MainActor
    static func copy(_ code: String, now: Date = Date()) {
        UIPasteboard.general.setItems(
            [["public.utf8-plain-text": code]], options: [.localOnly: true, .expirationDate: now.addingTimeInterval(lifetime)])
    }
}
