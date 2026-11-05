import Qeetrix
import SwiftUI

/// Screens 6 and 7, Add account: scan the QR code a site shows, or type its setup key. A Qeet ID pairing code scanned
/// here goes to linking instead.
struct AddAccountView: View {
    let model: AppModel
    @State private var showsSetupKey = false
    @State private var toast: QeetrixToast?

    var body: some View {
        NavigationStack {
            ScannerScreen(
                title: "Add account", guidance: Text("Point the camera at the QR code"), typeInstead: Text("Type the key instead"),
                lock: model.lock, onPayload: { handle($0) }, onTypeInstead: { showsSetupKey = true }, onCancel: { model.modal = nil })
        }
        .qeetrixSheet(isPresented: $showsSetupKey) {
            SetupKeySheet { draft throws(AccountStoreError) in
                let account = try model.accounts.add(draft)
                model.modal = nil
                model.accountAdded(account)
            }
        }
        .qeetrixToast($toast)
        .accessibilityIdentifier("add-account")
    }

    private func handle(_ payload: String) {
        if let code = PairingCode.from(payload), payload.lowercased().hasPrefix("qeetidauth:") {
            model.startLinking(code: code)
            return
        }
        do {
            let draft = try OTPAuthURI.parse(payload)
            let account = try model.accounts.add(draft)
            QeetrixFeedback.success.play()
            model.modal = nil
            model.accountAdded(account)
        } catch let error as SetupKeyError {
            QeetrixFeedback.warning.play()
            toast = QeetrixToast(.warning, title: String(localized: "Can't add this account"), description: error.message)
        } catch let error as AccountStoreError {
            QeetrixFeedback.warning.play()
            toast = QeetrixToast(.warning, title: String(localized: "Can't add this account"), description: error.message)
        } catch {
            toast = QeetrixToast(.warning, title: String(localized: "Can't add this account"))
        }
    }
}
