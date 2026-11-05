import SwiftUI

/// The Q-key: Qeet ID's app icon, drawn from the brand's own artwork, light or dark with the appearance. It stands
/// where the mockup shows the app's mark (Welcome, Locked); never the Qeet Group logo.
struct QeetIDMark: View {
    var size: CGFloat = 64

    var body: some View {
        Image("QeetIDMark")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
