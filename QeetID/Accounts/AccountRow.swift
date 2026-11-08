import Qeetrix
import SwiftUI

/// One account on the Accounts screen: Qeetrix's list row with the issuer's letter, the issuer and name, and the code
/// with the time left under them. Tapping the code copies it (on this iPhone only, for a minute); in the last five
/// seconds the ring and seconds turn amber.
struct AccountRow: View {
    let account: OTPAccount
    let code: GeneratedCode?
    let hidesCode: Bool
    let toast: Binding<QeetrixToast?>?

    var body: some View {
        QeetrixListItem(title: Text(verbatim: account.issuer), description: account.name.isEmpty ? nil : Text(verbatim: account.name)) {
            QeetrixListItemIcon(monogram: account.monogram)
        }
        .qeetrixListItemContent {
            if let code {
                QeetrixOTPCode(
                    code.code, validity: code.validity, label: Text(verbatim: account.spokenName), size: .md, isHidden: hidesCode,
                    toast: toast
                )
            } else {
                QeetrixText("Unlock this iPhone to see the code.", size: .sm, tone: .subtle)
            }
        }
    }
}
