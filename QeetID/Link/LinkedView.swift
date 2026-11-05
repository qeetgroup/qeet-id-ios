import Qeetrix
import SwiftUI

/// Screen 14, iPhone linked: a success alert and the facts — which account, which phone, until when.
struct LinkedView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.gapLg) {
                QeetrixAlert(
                    "iPhone linked", description: "Sign-in requests for your account now come here.", tone: .success, announce: .polite)
                if let summary = model.link.summary {
                    QeetrixCard(title: Text("This iPhone")) {
                        QeetrixDescriptionList {
                            QeetrixDescriptionItem("Account", value: summary.accountEmail ?? String(localized: "your Qeet ID account"))
                            QeetrixDescriptionItem("Name", value: summary.deviceName)
                            QeetrixDescriptionItem(
                                "Linked until",
                                value: String(localized: "\(QeetrixFormat.date(summary.linkedUntil, style: .long)) · link again to extend"))
                        }
                    }
                }
            }
            .padding(QeetrixSpace.insetLg)
        }
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle("Link this iPhone")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
        .qeetrixBottomActionBar(primary: QeetrixScreenAction("Done", icon: .check) { model.path = [] })
        .accessibilityIdentifier("link.linked")
    }
}
