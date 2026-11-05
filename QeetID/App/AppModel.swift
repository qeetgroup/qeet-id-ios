import Observation
import Qeetrix
import SwiftUI

/// What covers the app: nothing, the Locked screen, or the privacy cover the app switcher shows.
enum Shield: Equatable {
    case none
    case locked
    case privacy
}

/// A screen that covers the whole app.
enum AppModal: Identifiable, Equatable {
    /// Screens 6 to 8: scan a QR code or type a setup key.
    case addAccount

    var id: String {
        switch self {
        case .addAccount: "add-account"
        }
    }
}

/// The app's state across screens: the person's choices, the lock, the accounts, what covers the app, navigation and
/// the toast.
@MainActor
@Observable
final class AppModel {
    let preferences: Preferences
    let lock: AppLock
    let accounts: AccountsModel
    /// The toast hosted at the root, over every screen.
    var toast: QeetrixToast?
    /// The screens pushed onto Accounts.
    var path: [Route] = []
    /// The full-screen cover, if any.
    var modal: AppModal?

    private(set) var scenePhase: ScenePhase = .active
    /// The last time the app went to the background, so returning from it — not from a Face ID prompt or Control
    /// Center — is what asks to unlock.
    @ObservationIgnored private var wasInBackground = true

    init(preferences: Preferences, authenticator: any DeviceOwnerAuthenticating, accountStore: any AccountStore) {
        self.preferences = preferences
        lock = AppLock(preferences: preferences, authenticator: authenticator)
        accounts = AccountsModel(store: accountStore)
    }

    /// The app as it runs on an iPhone: the Keychain, the system's Face ID, the production API.
    static func live() -> AppModel {
        #if DEBUG
            APIEnvironment.applyLaunchArguments()
            if UITestSupport.isActive { return UITestSupport.makeModel() }
        #endif
        return AppModel(
            preferences: Preferences(), authenticator: LocalDeviceOwnerAuthenticator(), accountStore: KeychainAccountStore())
    }

    /// What covers the app now. The privacy cover shows whenever the app isn't active — the app switcher, Notification
    /// Center — except while the app's own Face ID or permission prompt is up.
    var shield: Shield {
        if lock.isLocked { return .locked }
        if scenePhase != .active && !lock.isAuthenticating { return .privacy }
        return .none
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        scenePhase = phase
        switch phase {
        case .background:
            wasInBackground = true
            lock.lock()
            accounts.forgetSecrets()
            endEditing()
        case .active:
            if wasInBackground {
                wasInBackground = false
                accounts.load()
                if lock.isLocked { Task { await lock.unlock() } }
            }
        default:
            break
        }
    }

    func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
    }

    /// An account was added: say so.
    func accountAdded(_ account: OTPAccount) {
        toast = QeetrixToast(.success, title: String(localized: "\(account.issuer) added"))
    }

    /// A pairing code was scanned or opened: linking this iPhone is the next step, on the person's tap.
    func startLinking(code: String) {
        modal = nil
        toast = QeetrixToast(
            .info, title: String(localized: "This is a Qeet ID pairing code"),
            description: String(localized: "Link this iPhone from Settings to approve sign-ins."))
    }

    /// Hides the keyboard, so it doesn't stay up over the Locked screen.
    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
