import Qeetrix
import SwiftUI

/// Screen 21, Locked: the Q-key, what is locked, and the way in. Opening or returning to the app shows it while the
/// lock is on, and asks for Face ID by itself.
struct LockedView: View {
    let lock: AppLock

    var body: some View {
        let biometry = lock.biometry
        VStack(spacing: QeetrixSpace.gapSm) {
            QeetIDMark(size: 64)
                .padding(.bottom, QeetrixSpace.gapSm)
            QeetrixHeading("Qeet ID is locked", level: 1, size: .titleMd, align: .center)
            QeetrixText("Unlock to see your codes and sign-in requests.", tone: .subtle, align: .center)
            if lock.lastOutcome == .failed {
                QeetrixText(
                    "\(biometry.name) didn't recognise you. Try again, or use your passcode.", size: .sm, tone: .danger, align: .center
                )
                .accessibilityIdentifier("locked.failed")
            }
            QeetrixButton(biometry.unlockTitle, icon: .scanLine, size: .lg, isLoading: lock.isAuthenticating) {
                Task { await lock.unlock() }
            }
            .padding(.top, QeetrixSpace.gapSm)
            .accessibilityIdentifier("locked.unlock")
        }
        .padding(.horizontal, QeetrixSpace.layoutMd)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QeetrixColor.surfaceCanvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("locked")
    }
}

/// The cover the app switcher shows while the lock is off: the Q-key and the app's name, never a code.
struct PrivacyCoverView: View {
    var body: some View {
        VStack(spacing: QeetrixSpace.gapMd) {
            QeetIDMark(size: 64)
            QeetrixHeading("Qeet ID", level: 1, size: .titleMd, align: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QeetrixColor.surfaceCanvas)
        .accessibilityIdentifier("privacy-cover")
    }
}
