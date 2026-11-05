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
            .onChange(of: model.lock.isLocked) { wasLocked, isLocked in
                if wasLocked && !isLocked { model.didUnlock() }
            }
            .onOpenURL { model.open($0) }
    }

    @ViewBuilder private var content: some View {
        if model.preferences.hasCompletedOnboarding {
            NavigationStack(path: Binding(get: { model.path }, set: { model.path = $0 })) {
                AccountsView(model: model)
                    .navigationDestination(for: Route.self) { route in destination(route) }
            }
            .fullScreenCover(item: Binding(get: { model.modal }, set: { model.modal = $0 })) { modal in
                Group {
                    switch modal {
                    case .addAccount: AddAccountView(model: model)
                    case .scanPairing: PairingScannerView(model: model)
                    case .signInRequest(let id):
                        SignInRequestView(model: model.requestModel(for: id)) { model.closeSignInRequest() }
                    }
                }
                .qeetrixRootTheme()
            }
        } else {
            OnboardingFlow(model: model)
        }
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .settings: SettingsView()
        case .autoFill: AutoFillSetupView()
        case .linkIntro: LinkIntroView(model: model)
        case .linkName(let code): NameAndLinkView(model: model, scannedCode: code)
        case .linked: LinkedView(model: model)
        }
    }
}
