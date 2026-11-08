import Qeetrix
import SwiftUI
import UIKit

/// Name this iPhone: the code (when it was typed), the name the computer will list it by, and what linking means;
/// then Link this iPhone. Linking happens only on the person's tap. A scanned code that didn't work says so, with a way
/// to scan a new one.
struct NameAndLinkView: View {
    let model: AppModel
    let scannedCode: String?
    @Environment(\.room) private var room
    @State private var typedCode = ""
    @State private var name = UIDevice.current.name
    @State private var codeError: String?
    @State private var nameError: String?
    @State private var scannedCodeFailed = false
    @State private var isLinking = false
    @State private var alert: QeetrixAlertDialog?
    @FocusState private var focus: Field?

    private enum Field { case code, name }

    var body: some View {
        ScrollView {
            PageColumn {
                if scannedCodeFailed {
                    QeetrixAlert(
                        "This code didn’t work",
                        description:
                            "It may have been used already, or it’s older than 5 minutes. On the computer, choose Get a new code, then scan it.",
                        tone: .danger
                    )
                    .padding(.bottom, QeetrixSpace.insetLg)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("link.code-failed")
                }
                PageTitle(title: Text("Name this iPhone"), line: Text("It’s how you’ll know it under Linked phones on the computer."))
                VStack(alignment: .leading, spacing: QeetrixSpace.gapLg) {
                    if scannedCode == nil {
                        QeetrixTextField(
                            "Pairing code", text: $typedCode, prompt: Text(verbatim: "e.g. KM7QX-4TRWP"),
                            description: Text("Shown in Qeet ID under Link a phone."), error: codeError
                        )
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
                    QeetrixTextField("Name", text: $name, error: nameError)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($focus, equals: .name)
                        .onSubmit { link() }
                        .onChange(of: name) { nameError = nil }
                        .accessibilityIdentifier("link.name")
                }
                .padding(.top, QeetrixSpace.layoutSm)
                Panel {
                    QeetrixText("Once it’s linked", size: .sm, weight: .semibold, tone: .subtle)
                    Fact("Sign-ins to your Qeet ID account can be approved here")
                    Fact(Text("Approving asks for \(model.lock.biometry.name) and the number on the sign-in screen"))
                    Fact("Unlink it any time, here or on the computer")
                }
                .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Link this iPhone"))
        .actionFooter(
            primary: scannedCodeFailed
                ? QeetrixScreenAction("Scan a new code", icon: .scanLine) { model.modal = .scanPairing }
                : QeetrixScreenAction("Link this iPhone", isLoading: isLinking) { link() }
        )
        .qeetrixAlertDialog($alert)
        .onAppear { focus = scannedCode == nil ? .code : .name }
        .accessibilityElement(children: .contain)
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
            if permission == .notDetermined {
                Log.push.info("Linking: asking for notifications")
                _ = await NotificationPermission.request()
            }
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
                scannedCodeFailed = true
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
