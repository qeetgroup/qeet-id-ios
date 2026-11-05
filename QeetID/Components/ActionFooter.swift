import Qeetrix
import SwiftUI

/// One action of an `ActionFooter`.
struct FooterAction {
    let title: Text
    let icon: QeetrixIconName?
    var isLoading = false
    let action: @MainActor () -> Void

    init(_ title: LocalizedStringKey, icon: QeetrixIconName? = nil, isLoading: Bool = false, action: @escaping @MainActor () -> Void) {
        self.title = Text(title)
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
}

extension View {
    /// Pins a screen's actions to the bottom, as Qeetrix's bottom action bar does, with what the bar can't hold yet:
    /// a ghost (tertiary) action stacked under the primary — "Continue" over "Not now" — or a ghost action alone.
    /// Use `qeetrixBottomActionBar(primary:secondary:)` wherever its solid + soft pair fits.
    func actionFooter(primary: FooterAction? = nil, tertiary: FooterAction? = nil) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            ActionFooterBar(primary: primary, tertiary: tertiary)
        }
    }
}

/// The bar: `color.surface.default` under the home indicator, a 1 pt `color.border.default` rule along its top, the
/// page gutter at the sides, and `lg` buttons — the field height — full width, `space.gap.sm` apart.
private struct ActionFooterBar: View {
    let primary: FooterAction?
    let tertiary: FooterAction?

    var body: some View {
        VStack(spacing: QeetrixSpace.gapSm) {
            if let primary {
                QeetrixButton(
                    title: primary.title, icon: primary.icon, size: .lg, isLoading: primary.isLoading, isFullWidth: true,
                    action: primary.action)
            }
            if let tertiary {
                QeetrixButton(
                    title: tertiary.title, icon: tertiary.icon, variant: .ghost, size: .lg, isLoading: tertiary.isLoading,
                    isFullWidth: true, action: tertiary.action)
            }
        }
        .padding(.horizontal, QeetrixSpace.insetLg)
        .padding(.vertical, QeetrixSpace.insetMd)
        .frame(maxWidth: .infinity)
        .background(QeetrixColor.surfaceDefault, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QeetrixColor.borderDefault)
                .frame(height: QeetrixBorderWidth.default)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
}
