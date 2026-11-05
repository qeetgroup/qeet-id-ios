import Foundation
import LocalAuthentication

/// The biometry this iPhone has, for the words on the screens: "Face ID lock", "Unlock with Touch ID".
enum Biometry: Sendable, Equatable {
    case faceID, touchID, opticID
    /// No biometry enrolled or available: the passcode alone.
    case passcode

    var name: String {
        switch self {
        case .faceID: String(localized: "Face ID")
        case .touchID: String(localized: "Touch ID")
        case .opticID: String(localized: "Optic ID")
        case .passcode: String(localized: "passcode")
        }
    }
}

/// What a device-owner check came to.
enum AuthenticationOutcome: Sendable, Equatable {
    case success
    /// The person cancelled, or the system did (another app, a call).
    case cancelled
    /// Face ID and the passcode both failed.
    case failed
    /// The iPhone has no passcode, so it can't prove who is holding it.
    case passcodeNotSet
}

/// Proves the person holding the iPhone is its owner: Face ID or Touch ID, falling back to the passcode
/// (`LAPolicy.deviceOwnerAuthentication`).
protocol DeviceOwnerAuthenticating: Sendable {
    /// The biometry, for wording.
    func biometry() -> Biometry
    /// Whether a check can run at all: `false` when the iPhone has no passcode.
    func canAuthenticate() -> Bool
    /// Runs a check, with `reason` under the system's prompt where it shows one (the passcode, Touch ID).
    func authenticate(reason: String) async -> AuthenticationOutcome
}

/// The system's check. Each call uses a new `LAContext`, so an earlier success is never reused: approving a sign-in
/// right after unlocking still asks.
struct LocalDeviceOwnerAuthenticator: DeviceOwnerAuthenticating {
    func biometry() -> Biometry {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .passcode
        }
    }

    func canAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func authenticate(reason: String) async -> AuthenticationOutcome {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 0
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return Self.outcome(for: error)
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) ? .success : .failed
        } catch {
            return Self.outcome(for: error as NSError)
        }
    }

    private static func outcome(for error: NSError?) -> AuthenticationOutcome {
        guard let error, error.domain == LAError.errorDomain else { return .failed }
        switch LAError.Code(rawValue: error.code) {
        case .userCancel, .appCancel, .systemCancel, .userFallback: return .cancelled
        case .passcodeNotSet: return .passcodeNotSet
        default: return .failed
        }
    }
}

#if DEBUG
    /// A check with a fixed answer, for UI tests (Debug builds only: a simulator has no face to scan).
    struct StubDeviceOwnerAuthenticator: DeviceOwnerAuthenticating {
        let outcome: AuthenticationOutcome

        func biometry() -> Biometry { .faceID }
        func canAuthenticate() -> Bool { outcome != .passcodeNotSet }
        func authenticate(reason: String) async -> AuthenticationOutcome { outcome }
    }
#endif

extension Biometry {
    /// The lock's name in Settings and onboarding: "Face ID lock".
    var lockTitle: String {
        switch self {
        case .faceID: String(localized: "Face ID lock")
        case .touchID: String(localized: "Touch ID lock")
        case .opticID: String(localized: "Optic ID lock")
        case .passcode: String(localized: "Passcode lock")
        }
    }

    /// The Locked screen's button: "Unlock with Face ID".
    var unlockTitle: String {
        switch self {
        case .faceID: String(localized: "Unlock with Face ID")
        case .touchID: String(localized: "Unlock with Touch ID")
        case .opticID: String(localized: "Unlock with Optic ID")
        case .passcode: String(localized: "Unlock with passcode")
        }
    }
}
