import Qeetrix
import SwiftUI
import UIKit

/// Screen 13, Name this iPhone: the code (read-only when scanned, typed otherwise), the name the console will show,
/// and what linking means. Linking happens only on the person's tap.
struct NameAndLinkView: View {
    let model: AppModel
    let scannedCode: String?
    @State private var typedCode = ""
    @State private var name = UIDevice.current.name
    @State private var codeError: String?
    @State private var nameError: String?
    @State private var isLinking = false
    @State private var alert: QeetrixAlertDialog?
    @FocusState private var focus: Field?

    private enum Field { case code, name }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.gapLg) {
                if let scannedCode {
                    QeetrixTextField("Pairing code", text: .constant(scannedCode), isReadOnly: true)
                        .font(QeetrixTextMetrics(role: .codeMd).font)
                        .accessibilityIdentifier("link.code")
                } else {
                    QeetrixTextField("Pairing code", text: $typedCode, prompt: Text(verbatim: "e.g. KM7QX-4TRWP"), error: codeError)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .textContentType(nil)
                        .submitLabel(.next)
                        .focused($focus, equals: .code)
                        .onSubmit { focus = .name }
                        .onChange(of: typedCode) { codeError = nil }
                        .accessibilityIdentifier("link.code")
                }
                QeetrixTextField(
                    "Name for this iPhone", text: $name, description: Text("Shown in Qeet ID, in the list of your phones."),
                    error: nameError
                )
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($focus, equals: .name)
                .onSubmit { link() }
                .onChange(of: name) { nameError = nil }
                .accessibilityIdentifier("link.name")
                QeetrixCard {
                    QeetrixDescriptionList {
                        QeetrixDescriptionItem("Sign-in requests", value: String(localized: "Come to this iPhone"))
                        QeetrixDescriptionItem("Stays linked", value: String(localized: "180 days after you last link it"))
                    }
                }
            }
            .padding(QeetrixSpace.insetLg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle("Link this iPhone")
        .navigationBarTitleDisplayMode(.inline)
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
        .qeetrixBottomActionBar(primary: QeetrixScreenAction("Link iPhone", icon: .smartphone, isLoading: isLinking) { link() })
        .qeetrixAlertDialog($alert)
        .onAppear { focus = scannedCode == nil ? .code : .name }
        .accessibilityIdentifier("link.name-screen")
    }

    private func link() {
        guard !isLinking else { return }
        guard let code = scannedCode ?? PairingCode.from(typedCode) else {
            codeError = String(localized: "Enter the 10-character code shown in Qeet ID, like KM7QX-4TRWP.")
            return
        }
        let name = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            nameError = String(localized: "Give this iPhone a name, so you can tell it apart in Qeet ID.")
            return
        }
        focus = nil
        Task {
            isLinking = true
            defer { isLinking = false }
            model.lock.beginSystemPrompt()
            let permission = await NotificationPermission.current()
            if permission == .notDetermined { _ = await NotificationPermission.request() }
            model.lock.endSystemPrompt()
            do throws(LinkError) {
                try await model.link.link(code: code, name: name)
                QeetrixFeedback.success.play()
                model.path = [.linked]
            } catch {
                QeetrixFeedback.error.play()
                show(error)
            }
        }
    }

    private func show(_ error: LinkError) {
        switch error {
        case .api(.pairingCodeInvalid):
            let message = String(
                localized: "That code is wrong, already used or expired. Ask for a new one in Qeet ID, under Account, then Security.")
            if scannedCode == nil {
                codeError = message
            } else {
                alert = QeetrixAlertDialog("This code can't link the iPhone", message: Text(message))
            }
        case .api(.throttled(let seconds)):
            let minutes = max(1, Int((Double(seconds) / 60).rounded(.up)))
            alert = QeetrixAlertDialog(
                "Too many tries", message: Text("Wait \(minutes) min, then ask for a new code in Qeet ID and try again."))
        case .api(let apiError):
            alert = QeetrixAlertDialog("Couldn't link this iPhone", message: Text(apiError.connectionMessage))
        case .noPushToken:
            alert = QeetrixAlertDialog(
                "Couldn't set up sign-in requests",
                message: Text("This iPhone couldn't register for notifications. Check your connection and try again."))
        case .storage:
            alert = QeetrixAlertDialog(
                "Couldn't link this iPhone", message: Text("Qeet ID couldn't save to this iPhone's Keychain. Try again."))
        }
    }
}
