import Qeetrix
import SwiftUI

extension View {
    /// Pins a screen's actions to the bottom with Qeetrix's bottom action bar, as the mockups' iOS action bar does: the
    /// main action, a quiet ghost one stacked under it ("Approve" over "Deny", "Use Face ID" over "Not now"), or either
    /// on its own. Give a tertiary `tone: .neutral`. Picks the bar for the actions a screen has at the moment, since
    /// some screens drop one once something is done.
    @ViewBuilder
    func actionFooter(primary: QeetrixScreenAction? = nil, tertiary: QeetrixScreenAction? = nil) -> some View {
        if let tertiary {
            qeetrixBottomActionBar(primary: primary, tertiary: tertiary)
        } else if let primary {
            qeetrixBottomActionBar(primary: primary)
        } else {
            self
        }
    }
}
