import Qeetrix
import SwiftUI

/// A final screen — the EmptyState pattern with a status-coloured icon: what happened and what to do next.
struct OutcomeView<Extra: View>: View {
    let icon: QeetrixIconName
    let iconColor: QeetrixColor
    let title: Text
    let message: Text
    @ViewBuilder var extra: Extra

    var body: some View {
        ScrollView {
            VStack(spacing: QeetrixSpace.gapSm) {
                QeetrixIcon(icon, size: .lg, shape: .sharp)
                    .foregroundStyle(iconColor)
                    .padding(.bottom, QeetrixSpace.gapXs)
                QeetrixHeading(title, level: 1, size: .titleMd, align: .center)
                QeetrixText(message, tone: .subtle, align: .center)
                extra
                    .padding(.top, QeetrixSpace.gapLg)
            }
            .padding(.horizontal, QeetrixSpace.insetXl)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .background(QeetrixColor.surfaceCanvas)
    }
}

extension OutcomeView where Extra == EmptyView {
    init(icon: QeetrixIconName, iconColor: QeetrixColor, title: Text, message: Text) {
        self.init(icon: icon, iconColor: iconColor, title: title, message: message) { EmptyView() }
    }
}
