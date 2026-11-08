import Qeetrix
import SwiftUI

/// iPhone linked: the icon with a green seal, which account and the name the computer shows, and what happens next.
struct LinkedView: View {
    let model: AppModel

    var body: some View {
        ResultScreen(
            title: Text("This iPhone is linked"), line: Text("Sign-ins to your Qeet ID account can be approved here now."),
            sealTone: .success
        ) {
            QeetrixIcon(.check, size: .md, stroke: QeetrixIconStroke(2.5), shape: .sharp)
        } content: {
            if let summary = model.link.summary {
                ResultDetails(rows: [
                    (Text("Account"), Text(verbatim: summary.accountEmail ?? String(localized: "your Qeet ID account"))),
                    (Text("On the computer"), Text(verbatim: summary.deviceName)),
                ])
            }
            ResultNote(text: Text("Next time you sign in on a computer, a request comes to this iPhone.")) {
                QeetrixIcon(.bellRing, size: .sm, shape: .sharp)
            }
        }
        .navigationBarBackButtonHidden()
        .actionFooter(primary: QeetrixScreenAction("Done") { model.path = [] })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("link.linked")
    }
}
