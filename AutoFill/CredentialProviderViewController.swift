import AuthenticationServices
import UIKit

/// The AutoFill credential provider: Qeet ID's codes above the keyboard (iOS 18 and later).
final class CredentialProviderViewController: ASCredentialProviderViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}
