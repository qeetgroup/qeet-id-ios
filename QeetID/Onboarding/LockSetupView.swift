import Qeetrix
import SwiftUI

/// Lock Qeet ID (step 1 of 2): what the lock does, on the icon with a Face ID seal, then Use Face ID (which asks for
/// it once, so nobody locks themselves out) or Not now. With no passcode on the iPhone it says so, and offers to go on
/// without the lock.
struct LockSetupView: View {
    let lock: AppLock
    let onDone: @MainActor () -> Void
    @Environment(\.room) private var room
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var isEnabling = false
    @State private var hasPasscode = true
    @State private var alert: QeetrixAlertDialog?

    var body: some View {
        let biometry = lock.biometry
        ScrollView {
            PageColumn {
                if !room.isShort {
                    MarkRings(size: room.isMedium ? .xs : .sm) {
                        QeetrixIcon(biometry == .touchID ? .fingerprintPattern : .scanFace, shape: .sharp)
                    }
                    .padding(.leading, -8)
                    .padding(.bottom, QeetrixSpace.insetLg)
                }
                PageTitle(
                    title: Text("Lock Qeet ID"),
                    line: Text(
                        "Ask for \(biometry.name) each time the app opens. Someone holding your unlocked iPhone still can’t read your codes."
                    ))
                if hasPasscode {
                    Panel {
                        Fact(Text("\(biometry.name) each time Qeet ID opens, and again after 30 seconds away"))
                        Fact(
                            biometry == .touchID
                                ? Text("Your passcode when Touch ID can’t read your finger")
                                : Text("Your passcode when Face ID can’t see you"))
                        Fact("Codes hidden in the app switcher")
                    }
                    .padding(.top, room.isShort ? 12 : 20)
                    QeetrixAlert("Approving a sign-in always asks for \(biometry.name), even with the lock off.")
                        .padding(.top, room.isShort ? 12 : QeetrixSpace.insetLg)
                } else {
                    QeetrixAlert(
                        "Set a passcode first",
                        description:
                            "This iPhone has no passcode, so Qeet ID can’t lock itself or approve sign-ins. Set one in Settings › \(biometry.name) & Passcode, then turn on the lock in Qeet ID’s Settings. Sign-in codes work without it.",
                        tone: .warning
                    )
                    .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("onboarding.no-passcode")
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(QeetrixColor.surfaceCanvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            QeetrixProgress("Setting up: step 1 of 2", value: 0.5)
        }
        .screenBar(Text("Step 1 of 2"))
        .actionFooter(
            primary: hasPasscode
                ? QeetrixScreenAction(title: Text("Use \(biometry.name)"), isLoading: isEnabling) { useLock() }
                : QeetrixScreenAction("Continue without the lock", icon: .chevronRight) { onDone() },
            tertiary: hasPasscode
                ? QeetrixScreenAction("Not now", tone: .neutral) { onDone() }
                : QeetrixScreenAction("Open Settings", tone: .neutral) { openSettings() }
        )
        .qeetrixAlertDialog($alert)
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Back from Settings with a passcode set.
            if phase == .active { hasPasscode = lock.canAuthenticate }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.lock")
    }

    /// Turning the lock on proves it can be passed, so nobody locks themselves out.
    private func useLock() {
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
                    message: Text("\(lock.biometry.name) didn’t confirm it’s you. Try again, or turn it on later in Settings."))
            case .passcodeNotSet:
                hasPasscode = false
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
