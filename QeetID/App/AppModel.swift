import Observation
import Qeetrix
import SwiftUI

/// What covers the app: nothing, the Locked screen, or the privacy cover the app switcher shows.
enum Shield: Equatable {
    case none
    case locked
    case privacy
}

/// The app's state across screens: the person's choices, the lock, what covers the app, and the toast.
@MainActor
@Observable
final class AppModel {
    let preferences: Preferences
    let lock: AppLock
    /// The toast hosted at the root, over every screen.
    var toast: QeetrixToast?

    private(set) var scenePhase: ScenePhase = .active
    /// The last time the app went to the background, so returning from it — not from a Face ID prompt or Control
    /// Center — is what asks to unlock.
    @ObservationIgnored private var wasInBackground = true

    init(preferences: Preferences, authenticator: any DeviceOwnerAuthenticating) {
        self.preferences = preferences
        lock = AppLock(preferences: preferences, authenticator: authenticator)
    }

    /// The app as it runs on an iPhone: the Keychain, the system's Face ID, the production API.
    static func live() -> AppModel {
        #if DEBUG
            APIEnvironment.applyLaunchArguments()
            if UITestSupport.isActive { return UITestSupport.makeModel() }
        #endif
        return AppModel(preferences: Preferences(), authenticator: LocalDeviceOwnerAuthenticator())
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
            endEditing()
        case .active:
            if wasInBackground {
                wasInBackground = false
                if lock.isLocked { Task { await lock.unlock() } }
            }
        default:
            break
        }
    }

    func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
    }

    /// Hides the keyboard, so it doesn't stay up over the Locked screen.
    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
