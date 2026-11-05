import Qeetrix
import SwiftUI

/// Screen 11, Link this iPhone: three numbered steps in the console's own words, then scan; typing the code is the
/// quiet alternative.
struct LinkIntroView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.layoutSm) {
                QeetrixText(
                    "Approve Qeet ID sign-ins here instead of typing a code. You need Qeet ID open on a computer.", size: .lg, tone: .subtle
                )
                VStack(spacing: 0) {
                    FeatureRow(title: Text("Open Qeet ID on your computer"), description: Text("Go to Account, then Security")) {
                        StepNumber(number: 1)
                    }
                    FeatureRow(title: Text("Choose Link a phone"), description: Text("Under Two-step verification")) {
                        StepNumber(number: 2)
                    }
                    FeatureRow(title: Text("Scan the code it shows"), description: Text("It works once, for a few minutes")) {
                        StepNumber(number: 3)
                    }
                }
            }
            .padding(QeetrixSpace.insetLg)
        }
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle("Link this iPhone")
        .navigationBarTitleDisplayMode(.inline)
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
        .actionFooter(
            primary: FooterAction("Scan the code", icon: .scanLine) { model.modal = .scanPairing },
            tertiary: FooterAction("Type the code instead") { model.path.append(.linkName(code: nil)) }
        )
        .accessibilityIdentifier("link.intro")
    }
}

/// Screen 12, Scan the pairing code: the same scanner, worded for linking. A code that isn't a Qeet ID pairing code is
/// refused with the reason.
struct PairingScannerView: View {
    let model: AppModel
    @State private var toast: QeetrixToast?

    var body: some View {
        NavigationStack {
            ScannerScreen(
                title: "Link this iPhone", guidance: Text("Point the camera at the code on the Qeet ID setup page"),
                typeInstead: Text("Type the code instead"), lock: model.lock,
                onPayload: { handle($0) },
                onTypeInstead: {
                    model.modal = nil
                    model.showLinking(code: nil)
                },
                onCancel: { model.modal = nil })
        }
        .qeetrixToast($toast)
        .accessibilityIdentifier("link.scanner")
    }

    private func handle(_ payload: String) {
        guard let code = PairingCode.from(payload) else {
            QeetrixFeedback.warning.play()
            toast = QeetrixToast(
                .warning, title: String(localized: "That isn't a Qeet ID pairing code"),
                description: String(localized: "Scan the code on the Link a phone page in Qeet ID, under Account, then Security."))
            return
        }
        QeetrixFeedback.success.play()
        model.modal = nil
        model.showLinking(code: code)
    }
}
