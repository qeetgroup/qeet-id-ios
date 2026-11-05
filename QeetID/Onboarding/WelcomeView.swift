import Qeetrix
import SwiftUI

/// Screen 1, Welcome: the Q-key, one line on what the app is for, its two jobs and where secrets stay, then Get
/// started above the home indicator.
struct WelcomeView: View {
    let onStart: @MainActor () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.layoutSm) {
                QeetIDMark(size: 64)
                VStack(alignment: .leading, spacing: QeetrixSpace.gapMd) {
                    QeetrixHeading("Sign in safely, with this iPhone", level: 1, size: .displaySm)
                    QeetrixText(
                        "Your sign-in codes, and a quick way to confirm it’s you when you sign in to Qeet ID.", size: .lg, tone: .subtle)
                }
                VStack(spacing: 0) {
                    FeatureRow(
                        title: Text("Sign-in codes"),
                        description: Text("For Qeet ID and any site with 2-step verification. They work offline.")
                    ) { icon(.keyRound) }
                    FeatureRow(
                        title: Text("Approve sign-ins"), description: Text("Confirm it's you with Face ID when you sign in on a computer.")
                    ) { icon(.smartphone) }
                    FeatureRow(
                        title: Text("Kept on this iPhone"),
                        description: Text("Secrets stay in the Secure Enclave and the Keychain. Qeet ID never receives them.")
                    ) { icon(.lock) }
                }
            }
            .padding(.horizontal, QeetrixSpace.insetXl)
            .padding(.top, QeetrixSpace.layoutLg)
            .padding(.bottom, QeetrixSpace.layoutMd)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(QeetrixColor.surfaceCanvas)
        .toolbar(.hidden, for: .navigationBar)
        .qeetrixBottomActionBar(primary: QeetrixScreenAction("Get started", icon: .chevronRight, action: onStart))
        .accessibilityIdentifier("welcome")
    }

    private func icon(_ name: QeetrixIconName) -> some View {
        QeetrixIcon(name, size: .md, shape: .sharp)
            .foregroundStyle(QeetrixColor.iconSubtle)
    }
}
