import Qeetrix
import SwiftUI

/// Screen 2, Lock Qeet ID (step 1 of 2): one switch, explained, and the reminder that approving always asks.
struct LockSetupView: View {
    let lock: AppLock
    let onDone: @MainActor () -> Void
    @State private var wantsLock = true
    @State private var isEnabling = false
    @State private var alert: QeetrixAlertDialog?

    var body: some View {
        let biometry = lock.biometry
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.layoutSm) {
                VStack(alignment: .leading, spacing: QeetrixSpace.gapMd) {
                    QeetrixHeading("Lock Qeet ID", level: 1, size: .headingLg)
                    QeetrixText(
                        "Ask for \(biometry.name) each time the app opens. Someone holding your unlocked iPhone still can't read your codes.",
                        size: .lg, tone: .subtle)
                }
                QeetrixCard {
                    QeetrixSwitch(isOn: $wantsLock, description: Text("Your passcode if \(biometry.name) can't see you")) {
                        Text(biometry.lockTitle)
                    }
                    .accessibilityIdentifier("onboarding.lock-switch")
                }
                QeetrixAlert("Approving a Qeet ID sign-in always asks for \(biometry.name).")
            }
            .padding(.horizontal, QeetrixSpace.insetXl)
            .padding(.vertical, QeetrixSpace.layoutSm)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle("Step 1 of 2")
        .navigationBarTitleDisplayMode(.inline)
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
        .actionFooter(
            primary: FooterAction("Continue", icon: .chevronRight, isLoading: isEnabling) { continueTapped() },
            tertiary: FooterAction("Not now") { onDone() }
        )
        .qeetrixAlertDialog($alert)
        .accessibilityIdentifier("onboarding.lock")
    }

    private func continueTapped() {
        guard wantsLock else { return onDone() }
        Task {
            isEnabling = true
            let outcome = await lock.enable()
            isEnabling = false
            switch outcome {
            case .success:
                onDone()
            case .cancelled:
                break
            case .failed:
                alert = QeetrixAlertDialog(
                    "The lock is off",
                    message: Text("\(lock.biometry.name) didn't confirm it's you. Try again, or turn it on later in Settings."))
            case .passcodeNotSet:
                alert = QeetrixAlertDialog(
                    "Set a passcode first",
                    message: Text(
                        "This iPhone has no passcode, so Qeet ID can't be locked. Set one in iOS Settings, then turn on the lock in Qeet ID's Settings."
                    ),
                    actions: [QeetrixDialogAction("Continue without the lock") { onDone() }])
            }
        }
    }
}
