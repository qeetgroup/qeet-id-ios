import UIKit

/// The UIKit side of the app: the callbacks SwiftUI has no scene-level equivalent for. It owns the app's model so
/// those callbacks can reach it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let model = AppModel.live()

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }
}
