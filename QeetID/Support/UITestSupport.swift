#if DEBUG
    import Foundation

    /// Launch arguments for the UI tests (Debug builds only; Release builds don't contain this file's code).
    ///
    /// - `-ui-testing`: start from empty storage and preferences, with Face ID answered by a stub.
    /// - `-ui-auth success|failed|cancelled|no-passcode`: the stub's answer (success by default).
    /// - `-ui-onboarded`: skip the welcome steps.
    /// - `-ui-lock-on`: start with the app lock on.
    /// - `-ui-scan <text>`: the QR scanner reads `<text>` (the simulator has no camera).
    enum UITestSupport {
        static var arguments: [String] { ProcessInfo.processInfo.arguments }

        static var isActive: Bool { arguments.contains("-ui-testing") }

        static func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }

        static var simulatedScan: String? { value(after: "-ui-scan") }

        static var authenticationOutcome: AuthenticationOutcome {
            switch value(after: "-ui-auth") {
            case "failed": .failed
            case "cancelled": .cancelled
            case "no-passcode": .passcodeNotSet
            default: .success
            }
        }

        @MainActor
        static func makeModel() -> AppModel {
            let defaults = UserDefaults.standard
            let preferences = Preferences(defaults: defaults)
            preferences.reset()
            try? KeychainAccountStore().deleteAll()
            try? DeviceLinkStore().clear()
            preferences.hasCompletedOnboarding = arguments.contains("-ui-onboarded")
            preferences.isLockEnabled = arguments.contains("-ui-lock-on")
            return AppModel(
                preferences: preferences, authenticator: StubDeviceOwnerAuthenticator(outcome: authenticationOutcome),
                accountStore: KeychainAccountStore())
        }
    }
#endif
