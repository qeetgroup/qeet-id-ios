import UserNotifications

/// Opens a sign-in request from its notification: a tap on the Lock Screen or in Notification Center, or one that
/// arrives while the app is open (the request opens at once instead of a banner).
///
/// The completion-handler forms, called back on the main thread: the `async` forms' generated thunks call UIKit's
/// completion handler off the main thread, which UIKit stops the app for.
@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard let id = SignInPush.challengeID(in: notification.request.content.userInfo) else {
            completionHandler([.banner, .sound])
            return
        }
        open(id)
        completionHandler([.sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let id = SignInPush.challengeID(in: response.notification.request.content.userInfo) {
            open(id)
        }
        completionHandler()
    }

    /// The notification centre calls its delegate on the main thread.
    private nonisolated func open(_ id: UUID) {
        MainActor.assumeIsolated {
            model?.openSignInRequest(id)
        }
    }
}
