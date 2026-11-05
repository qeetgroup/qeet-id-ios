import Qeetrix
import SwiftUI

/// The app's one window: the accounts list and everything reached from it, in the Qeetrix theme that
/// follows the iPhone's appearance.
struct RootView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            AccountsView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings: SettingsView()
                    }
                }
        }
        .qeetrixThemeMode(.system)
    }
}

/// The screens pushed onto the accounts list.
enum Route: Hashable {
    case settings
}
