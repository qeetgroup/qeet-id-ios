import Qeetrix
import SwiftUI

/// An account's tile: its issuer's letter in the 32 pt tile `QeetrixListItemIcon` draws — `color.bg.neutral.subtle`
/// inside a 1 pt `color.border.subtle` edge, 4 pt corners — so issuer marks are letters, never logos.
struct IssuerTile: View {
    let monogram: String
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 32

    var body: some View {
        Text(verbatim: monogram)
            .qeetrixTextStyle(.labelMd)
            .foregroundStyle(QeetrixColor.textDefault)
            .frame(width: side, height: side)
            .background(QeetrixColor.bgNeutralSubtle, in: RoundedRectangle(cornerRadius: QeetrixRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: QeetrixRadius.control)
                    .strokeBorder(QeetrixColor.borderSubtle, lineWidth: QeetrixBorderWidth.default)
            }
            .accessibilityHidden(true)
    }
}

/// An account's issuer over its name, as a list row's title and description.
struct AccountTitle: View {
    let account: OTPAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: account.issuer)
                .qeetrixTextStyle(.labelMd)
                .foregroundStyle(QeetrixColor.textDefault)
            if !account.name.isEmpty {
                Text(verbatim: account.name)
                    .qeetrixTextStyle(.bodySm)
                    .foregroundStyle(QeetrixColor.textSubtle)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
