import Qeetrix
import SwiftUI

extension View {
    /// A Qeetrix list row: the row draws its own insets on `color.surface.raised`, ruled in `color.border.subtle` edge
    /// to edge, as `QeetrixListItem` is in a `List`.
    func qeetrixListRow(colorScheme: ColorScheme) -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Rectangle().fill(QeetrixColor.surfaceRaised))
            .listRowSeparatorTint(QeetrixColor.borderSubtle.color(for: colorScheme))
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }
}
