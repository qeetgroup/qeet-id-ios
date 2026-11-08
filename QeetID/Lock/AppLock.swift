import Foundation
import Observation

/// The app lock: Face ID, Touch ID or the passcode when the app opens and each time it returns from the background,
/// while the lock is on.
@MainActor
@Observable
final class AppLock {
    /// The Locked screen covers everything.
    private(set) var isLocked: Bool
    /// A device-owner check is on screen (ours), so the scene's going inactive isn't the person leaving.
    private(set) var isAuthenticating = false
    /// The last check failed: the Locked screen says so.
    private(set) var lastOutcome: AuthenticationOutcome?

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored let authenticator: any DeviceOwnerAuthenticating

    init(preferences: Preferences, authenticator: any DeviceOwnerAuthenticating) {
        self.preferences = preferences
        self.authenticator = authenticator
        isLocked = preferences.isLockEnabled
    }

    var biometry: Biometry { authenticator.biometry() }

    /// Whether the iPhone can check its owner at all: `false` with no passcode set.
    var canAuthenticate: Bool { authenticator.canAuthenticate() }

    /// Locks, if the lock is on: the app went to the background.
    func lock() {
        guard preferences.isLockEnabled else { return }
        isLocked = true
        lastOutcome = nil
    }

    /// Asks for Face ID or the passcode; unlocks on success.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        let outcome = await authenticator.authenticate(reason: String(localized: "Unlock Qeet ID to see your codes and sign-in requests."))
        isAuthenticating = false
        lastOutcome = outcome
        if outcome == .success || (outcome == .passcodeNotSet && !authenticator.canAuthenticate()) {
            // Without a passcode there is nothing to check against; the lock can't hold, so it doesn't trap the person.
            isLocked = false
        }
    }

    /// Turns the lock on, after a check that the person can pass it.
    func enable() async -> AuthenticationOutcome {
        isAuthenticating = true
        let outcome = await authenticator.authenticate(reason: String(localized: "Turn on the lock for Qeet ID."))
        isAuthenticating = false
        if outcome == .success { preferences.isLockEnabled = true }
        return outcome
    }

    /// Turns the lock off, after a check: someone holding an unlocked iPhone can't simply switch it off.
    func disable() async -> AuthenticationOutcome {
        isAuthenticating = true
        let outcome = await authenticator.authenticate(reason: String(localized: "Turn off the lock for Qeet ID."))
        isAuthenticating = false
        if outcome == .success {
            preferences.isLockEnabled = false
            isLocked = false
        }
        return outcome
    }

    /// Runs another device-owner check (approving a sign-in) without the scene's going inactive locking the app.
    func authenticate(reason: String) async -> AuthenticationOutcome {
        isAuthenticating = true
        defer { isAuthenticating = false }
        return await authenticator.authenticate(reason: reason)
    }

    /// While the app asks iOS for a permission: its alert makes the scene inactive too.
    func beginSystemPrompt() { isAuthenticating = true }
    func endSystemPrompt() { isAuthenticating = false }
}
