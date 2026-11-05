import Qeetrix
import SwiftUI

/// One account on the Accounts screen: its tile, issuer and name, then its code with the time left. Tapping the code
/// copies it (on this iPhone only, for a minute); in the last five seconds the ring and seconds turn amber.
struct AccountRow: View {
    let account: OTPAccount
    let code: GeneratedCode?
    let hidesCode: Bool
    let toast: Binding<QeetrixToast?>?

    var body: some View {
        HStack(alignment: .top, spacing: QeetrixSpace.gapMd) {
            IssuerTile(monogram: account.monogram)
            VStack(alignment: .leading, spacing: QeetrixSpace.gapSm) {
                AccountTitle(account: account)
                if let code {
                    QeetrixOTPCode(
                        code.code, validity: code.validity, label: Text(verbatim: account.spokenName), size: .md, isHidden: hidesCode,
                        toast: toast
                    )
                    .accessibilityIdentifier("code.\(account.issuer)")
                } else {
                    QeetrixText("Unlock this iPhone to see the code.", size: .sm, tone: .subtle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, QeetrixSpace.insetLg)
        .padding(.vertical, QeetrixSpace.insetMd)
        .contentShape(Rectangle())
    }
}
