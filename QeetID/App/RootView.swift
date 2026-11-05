import Qeetrix
import SwiftUI

/// The app's window: onboarding the first time, then the accounts list and everything reached from it, under the
/// shield (the Locked screen and the privacy cover), which also has a window of its own above sheets and alerts.
struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var shieldWindow = ShieldWindowController()

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
            .task { model.accounts.load() }
    }

    @ViewBuilder private var content: some View {
        if model.preferences.hasCompletedOnboarding {
            NavigationStack(path: Binding(get: { model.path }, set: { model.path = $0 })) {
                AccountsView(model: model)
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .settings: SettingsView()
                        case .autoFill: AutoFillSetupView()
                        }
                    }
            }
            .fullScreenCover(item: Binding(get: { model.modal }, set: { model.modal = $0 })) { modal in
                switch modal {
                case .addAccount: AddAccountView(model: model).qeetrixRootTheme()
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
    /// Screen 25, AutoFill codes (iOS 18 and later).
    case autoFill
}
