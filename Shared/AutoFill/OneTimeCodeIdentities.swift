import AuthenticationServices
import Foundation

/// Tells iOS which sites each account's codes are for, so AutoFill can offer them above the keyboard (iOS 18 and
/// later). Only sites the person chose an account for are registered: nothing is guessed from an issuer's name, so a
/// look-alike site is never offered a code.
struct OneTimeCodeIdentities: Sendable {
    /// Replaces every registered identity with one per remembered site of each account. Does nothing before iOS 18 or
    /// while Qeet ID isn't turned on for AutoFill.
    func sync(_ accounts: [OTPAccount]) {
        guard #available(iOS 18, *) else { return }
        Task.detached(priority: .utility) {
            let identities = Self.identities(for: accounts)
            let store = ASCredentialIdentityStore.shared
            guard await store.state().isEnabled else { return }
            do {
                try await store.replaceCredentialIdentities(identities)
            } catch {
                Log.autofill.notice("Couldn't update AutoFill's list of sites")
            }
        }
    }

    @available(iOS 18, *)
    static func identities(for accounts: [OTPAccount]) -> [any ASCredentialIdentity] {
        accounts.flatMap { account in
            account.websites.map { site in
                ASOneTimeCodeCredentialIdentity(
                    serviceIdentifier: ASCredentialServiceIdentifier(identifier: site, type: .domain),
                    label: account.name.isEmpty ? account.issuer : "\(account.issuer) · \(account.name)",
                    recordIdentifier: account.id.uuidString)
            }
        }
    }

    /// Whether Qeet ID is turned on for AutoFill in iOS Settings.
    static func isEnabled() async -> Bool {
        guard #available(iOS 18, *) else { return false }
        return await ASCredentialIdentityStore.shared.state().isEnabled
    }
}
