import UserNotifications

/// Opens a sign-in request from its notification: a tap on the Lock Screen or in Notification Center, or one that
/// arrives while the app is open (the request opens at once instead of a banner).
@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard let id = SignInPush.challengeID(in: notification.request.content.userInfo) else { return [.banner, .sound] }
        await open(id)
        return [.sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = SignInPush.challengeID(in: response.notification.request.content.userInfo) else { return }
        await open(id)
    }

    private func open(_ id: UUID) {
        model?.openSignInRequest(id)
    }
}
