import UIKit
import UserNotifications

/// The UIKit side of the app: APNs registration and notification taps, which SwiftUI has no scene-level equivalent
/// for. It owns the app's model so those callbacks can reach it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let model = AppModel.live()
    private lazy var router = NotificationRouter(model: model)

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Before returning, so a tap that launched the app is delivered.
        UNUserNotificationCenter.current().delegate = router
        model.start()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        model.link.push.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        model.link.push.didFailToRegister()
    }
}
