import AuthenticationServices
import Qeetrix
import SwiftUI

/// Qeet ID's AutoFill credential provider: one-time codes above the keyboard and in AutoFill's sheet (iOS 18 and
/// later). Every code is shown or filled only after Face ID, Touch ID or the passcode.
final class CredentialProviderViewController: ASCredentialProviderViewController {
    private let store = KeychainAccountStore()
    private var host: UIHostingController<AnyView>?

    /// AutoFill's sheet: the accounts for the asking site first, then the rest (screen 27).
    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        let site = serviceIdentifiers.first.map { ServiceMatcher.host(from: $0.identifier) } ?? ""
        let model = CodePickerModel(store: store, site: site)
        model.onChoose = { [weak self] account, code in self?.fill(code, for: account, site: site) }
        model.onCancel = { [weak self] in self?.cancel() }
        show(CodePickerView(model: model))
    }

    /// A code chosen in the bar above the keyboard: never filled without the person, so iOS shows the interface.
    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
    }

    /// After a code was chosen in the bar: Face ID, then fill that account's code.
    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        guard #available(iOS 18, *), credentialRequest.type == .oneTimeCode,
            let identity = credentialRequest.credentialIdentity as? ASOneTimeCodeCredentialIdentity,
            let id = identity.recordIdentifier.flatMap(UUID.init(uuidString:)),
            let account = (try? store.accounts())?.first(where: { $0.id == id })
        else {
            return cancel(.credentialIdentityNotFound)
        }
        let site = ServiceMatcher.host(from: identity.serviceIdentifier.identifier)
        let model = CodePickerModel(store: store, site: site, only: account)
        model.onChoose = { [weak self] account, code in self?.fill(code, for: account, site: site) }
        model.onCancel = { [weak self] in self?.cancel() }
        show(CodePickerView(model: model))
    }

    /// Passwords and passkeys aren't Qeet ID's: nothing to list.
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        cancel()
    }

    private func fill(_ code: String, for account: OTPAccount, site: String) {
        guard #available(iOS 18, *) else { return cancel() }
        remember(account, for: site)
        extensionContext.completeOneTimeCodeRequest(using: ASOneTimeCodeCredential(code: code))
    }

    /// The person chose `account` on `site`: from now on it comes first there, and in the bar above the keyboard.
    private func remember(_ account: OTPAccount, for site: String) {
        guard let site = ServiceMatcher.siteToRemember(site), !ServiceMatcher.isRemembered(account, for: site) else { return }
        var updated = account
        updated.websites.append(site)
        do {
            try store.update(updated)
            OneTimeCodeIdentities().sync((try? store.accounts()) ?? [])
        } catch {
            Log.autofill.notice("Couldn't remember the site for an account")
        }
    }

    private func cancel(_ code: ASExtensionError.Code = .userCanceled) {
        extensionContext.cancelRequest(withError: ASExtensionError(code))
    }

    private func show(_ content: some View) {
        host?.view.removeFromSuperview()
        host?.removeFromParent()
        let host = UIHostingController(rootView: AnyView(content.qeetrixThemeMode(.system)))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
        self.host = host
    }
}
