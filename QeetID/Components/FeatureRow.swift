import Qeetrix
import SwiftUI

/// A ruled row with an icon, a title and a line under it: the jobs on Welcome, the steps on Link this iPhone.
struct FeatureRow<Leading: View>: View {
    let title: Text
    let description: Text
    @ViewBuilder let leading: Leading

    var body: some View {
        HStack(alignment: .top, spacing: QeetrixSpace.gapMd) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                title
                    .qeetrixTextStyle(.labelMd)
                    .foregroundStyle(QeetrixColor.textDefault)
                description
                    .qeetrixTextStyle(.bodySm)
                    .foregroundStyle(QeetrixColor.textSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, QeetrixSpace.insetMd)
        .overlay(alignment: .top) { QeetrixSeparator() }
        .accessibilityElement(children: .combine)
    }
}

/// A row's number tile, as `QeetrixListItemIcon` draws its tile: 32 pt, `color.bg.neutral.subtle` in a 1 pt
/// `color.border.subtle` edge, 4 pt corners, the digit in `label.md`.
struct StepNumber: View {
    let number: Int
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 32

    var body: some View {
        Text(verbatim: QeetrixFormat.number(number, locale: .current))
            .qeetrixTextStyle(.labelMd)
            .monospacedDigit()
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
