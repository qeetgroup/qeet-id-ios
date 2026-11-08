import Qeetrix
import SwiftUI

/// Update required: Qeet ID no longer accepts this version for sign-in approvals. It says what stops (approvals) and
/// what doesn't (codes), so nobody is locked out of their sites while updating, and that updating keeps the codes and
/// the link. Update opens the App Store at Qeet ID; Show my codes goes back to Accounts.
struct UpdateRequiredView: View {
    let onShowCodes: @MainActor () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ResultScreen(title: Text("Update Qeet ID"), line: Text("This version can’t approve sign-ins any more. Your codes still work."))
            {
                QeetrixIcon(.download, size: .md, shape: .sharp)
            } content: {
                ResultDetails(rows: [(Text("This version"), Text(verbatim: AppIdentity.version))])
                ResultNote(text: Text("Updating keeps your codes and this iPhone’s link to your account.")) {
                    QeetrixIcon(.keyRound, size: .sm, shape: .sharp)
                }
            }
            .actionFooter(
                primary: QeetrixScreenAction("Update in the App Store") { openURL(Self.appStore) },
                tertiary: QeetrixScreenAction("Show my codes", tone: .neutral) { onShowCodes() }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("update-required")
    }

    /// Qeet ID in the App Store. Until the app is published there is no App Store ID to link to, so this searches for it;
    /// replace it with `https://apps.apple.com/app/id<the ID>` once there is one.
    private static let appStore = URL(string: "https://apps.apple.com/search?term=Qeet%20ID")!
}
