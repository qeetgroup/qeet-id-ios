import AuthenticationServices
import SwiftUI

/// How the iPhone's passkey prompt went.
enum PasskeyResult: Sendable, Equatable {
    /// The signed assertion, as WebAuthn JSON, for the server to check.
    case signed(Data)
    case cancelled
    /// The iPhone couldn't ask (no passkey here, no passcode, Qeet ID not trusted for the domain).
    case unavailable
}

/// The iPhone's own passkey prompt: the person picks their Qeet ID passkey and confirms with Face ID, Touch ID or the
/// passcode, as on the computer. Tests use a fake.
protocol PasskeyPrompting: Sendable {
    /// Asks for an assertion for `options` (WebAuthn's PublicKeyCredentialRequestOptions, as JSON).
    @MainActor func sign(_ options: Data) async -> PasskeyResult
}

private struct PasskeysKey: EnvironmentKey {
    static let defaultValue: any PasskeyPrompting = SystemPasskeys()
}

/// The system's passkey prompt: a coordinator per request, which the system sheet reports to.
struct SystemPasskeys: PasskeyPrompting {
    @MainActor func sign(_ options: Data) async -> PasskeyResult {
        await PasskeyRequest().sign(options)
    }
}

extension EnvironmentValues {
    /// The passkey prompt administration signs in and steps up with.
    var passkeys: any PasskeyPrompting {
        get { self[PasskeysKey.self] }
        set { self[PasskeysKey.self] = newValue }
    }
}

/// One request to AuthenticationServices' platform passkeys: the system sheet over the app's window.
@MainActor
private final class PasskeyRequest: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<PasskeyResult, Never>?

    func sign(_ options: Data) async -> PasskeyResult {
        guard
            let object = try? JSONSerialization.jsonObject(with: options) as? [String: Any],
            let challenge = (object["challenge"] as? String).flatMap(Base64URL.decode),
            let relyingParty = object["rpId"] as? String
        else { return .unavailable }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingParty)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        if let allowed = object["allowCredentials"] as? [[String: Any]] {
            request.allowedCredentials = allowed.compactMap { ($0["id"] as? String).flatMap(Base64URL.decode) }.map {
                ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
            }
        }
        request.userVerificationPreference = .required
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            return finish(.unavailable)
        }
        let id = Base64URL.encode(assertion.credentialID)
        let json: [String: Any] = [
            "id": id, "rawId": id, "type": "public-key", "authenticatorAttachment": "platform", "clientExtensionResults": [String: Any](),
            "response": [
                "clientDataJSON": Base64URL.encode(assertion.rawClientDataJSON),
                "authenticatorData": Base64URL.encode(assertion.rawAuthenticatorData),
                "signature": Base64URL.encode(assertion.signature),
                "userHandle": Base64URL.encode(assertion.userID),
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return finish(.unavailable) }
        finish(.signed(data))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        let code = (error as? ASAuthorizationError)?.code
        finish(code == .canceled ? .cancelled : .unavailable)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    private func finish(_ result: PasskeyResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

/// Base64url without padding, as WebAuthn carries its binary fields.
enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ text: String) -> Data? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
}
