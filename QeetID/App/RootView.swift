import Qeetrix
import SwiftUI

/// The app's window: onboarding the first time, then the accounts list and everything reached from it, under the
/// shield (the Locked screen and the privacy cover), which also has a window of its own above sheets and alerts.
struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var shieldWindow = ShieldWindowController()
    @State private var path: [Route] = []

    var body: some View {
        content
            .overlay {
                // The same cover in this window, so nothing shows before the shield window is up at launch.
                if model.shield != .none { ShieldView(model: model) }
            }
            .background { WindowReader { window in shieldWindow.install(over: window, model: model) } }
            .qeetrixToast(Binding(get: { model.toast }, set: { model.toast = $0 }))
            .qeetrixRootTheme()
            .onChange(of: scenePhase, initial: true) { _, phase in model.scenePhaseChanged(to: phase) }
            .onChange(of: model.shield) { _, shield in shieldWindow.update(shield) }
    }

    @ViewBuilder private var content: some View {
        if model.preferences.hasCompletedOnboarding {
            NavigationStack(path: $path) {
                AccountsView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .settings: SettingsView()
                        }
                    }
            }
        } else {
            OnboardingFlow(model: model)
        }
    }
}

/// The screens pushed onto the accounts list.
enum Route: Hashable {
    case settings
}
