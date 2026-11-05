import Foundation
import Observation

/// The person's choices, in the app's own defaults: nothing secret, nothing an extension reads.
@MainActor
@Observable
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    /// Face ID (or the passcode) each time the app opens.
    var isLockEnabled: Bool {
        didSet { defaults.set(isLockEnabled, forKey: Keys.lock) }
    }

    /// Codes show as dots until tapped.
    var hidesCodes: Bool {
        didSet { defaults.set(hidesCodes, forKey: Keys.hideCodes) }
    }

    /// The welcome, lock and notification steps are done.
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isLockEnabled = defaults.bool(forKey: Keys.lock)
        hidesCodes = defaults.bool(forKey: Keys.hideCodes)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    }

    /// Forgets every choice, as after the app was reinstalled.
    func reset() {
        for key in [Keys.lock, Keys.hideCodes, Keys.onboarding] { defaults.removeObject(forKey: key) }
        isLockEnabled = false
        hidesCodes = false
        hasCompletedOnboarding = false
    }

    private enum Keys {
        static let lock = "lock.enabled"
        static let hideCodes = "codes.hidden"
        static let onboarding = "onboarding.completed"
    }
}
