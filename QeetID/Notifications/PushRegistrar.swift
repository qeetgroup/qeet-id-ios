import Observation
import UIKit

/// This iPhone's APNs device token, as lowercase hex: what the server sends sign-in requests to.
@MainActor
@Observable
final class PushRegistrar {
    private(set) var token: String?
    @ObservationIgnored private var hasFailed = false
    /// Called when APNs gives a token different from the last one.
    @ObservationIgnored var onTokenChange: (@MainActor (String) -> Void)?

    /// Asks APNs for a token; the answer comes to the app delegate.
    func register() {
        hasFailed = false
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        let changed = hex != token
        token = hex
        Log.push.info("APNs token received")
        if changed { onTokenChange?(hex) }
    }

    func didFailToRegister() {
        hasFailed = true
        Log.push.notice("APNs registration failed")
    }

    /// The token, waiting up to `timeout` for APNs. `nil` when there is none: no APNs entitlement, or no network.
    func currentToken(timeout: Duration = .seconds(10)) async -> String? {
        if let token { return token }
        register()
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline, token == nil, !hasFailed {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return token ?? Self.simulatorToken
    }

    /// A simulator gets no APNs token without a team's push key. Debug simulator builds stand in a fixed one, so linking
    /// can be tried against a local server, whose requests are then found by the pending check, not by push.
    private static var simulatorToken: String? {
        #if DEBUG && targetEnvironment(simulator)
            let key = "debug.simulatorPushToken"
            if let token = UserDefaults.standard.string(forKey: key) { return token }
            let token = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
            UserDefaults.standard.set(token, forKey: key)
            return token
        #else
            return nil
        #endif
    }
}
