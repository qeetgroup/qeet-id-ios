import SwiftUI

/// Qeet ID for iPhone: sign-in codes that work offline, and approving Qeet ID sign-ins.
@main
struct QeetIDApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(model: appDelegate.model)
        }
    }
}
