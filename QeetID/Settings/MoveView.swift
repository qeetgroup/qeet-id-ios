import Qeetrix
import SwiftUI

/// Move to a new iPhone. Codes are kept only on this iPhone, not in a backup, which is what keeps them safe; so moving
/// means linking the new iPhone, adding each account there again, and only then unlinking this one. The accounts on
/// this iPhone are listed (names only), so nothing is forgotten.
struct MoveView: View {
    let model: AppModel
    @Environment(\.room) private var room

    var body: some View {
        let accounts = model.accounts.accounts
        ScrollView {
            PageColumn {
                PageTitle(
                    title: Text("Set up the new iPhone"),
                    line: Text("Your codes never leave this iPhone, not even in a backup. So they’re set up again on the new one."))
                Panel {
                    QeetrixText("In this order", size: .sm, weight: .semibold, tone: .subtle)
                    NumberedSteps(steps: [
                        (Text("Install Qeet ID on the new phone and link it"), Text("It can be linked alongside this one")),
                        (Text("Add each account again"), Text("At each site, set up 2-step verification again and scan its new code")),
                        (Text("Then unlink this iPhone"), Text("And remove its codes, once the new one has them all")),
                    ])
                }
                .padding(.top, room.isShort ? QeetrixSpace.insetLg : 20)
                QeetrixAlert(
                    "Keep this iPhone until every code has moved", description: "Without it, you could be locked out of those sites.",
                    tone: .warning
                )
                .padding(.top, room.isShort ? QeetrixSpace.insetLg : 20)
                if !accounts.isEmpty {
                    GroupLabel("On this iPhone (\(accounts.count))")
                        .padding(.top, room.isShort ? 20 : QeetrixSpace.layoutSm)
                        .padding(.bottom, QeetrixSpace.gapSm)
                    QeetrixCard {
                        ForEach(accounts) { account in
                            QeetrixListItem(
                                title: Text(verbatim: account.issuer),
                                description: account.name.isEmpty ? nil : Text(verbatim: account.name)
                            ) {
                                QeetrixListItemIcon(monogram: account.monogram)
                            }
                        }
                    }
                    .flushRows()
                }
            }
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Move to a new iPhone"))
        .actionFooter(primary: QeetrixScreenAction("Done") { _ = model.path.popLast() })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("move")
    }
}
