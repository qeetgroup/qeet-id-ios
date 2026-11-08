import SwiftUI
import UIKit

/// Shows the Locked screen or the privacy cover in a window of its own above the app's, so it covers sheets, alerts
/// and full-screen covers too, and the app switcher's snapshot never shows a code.
@MainActor
final class ShieldWindowController {
    private var window: UIWindow?
    private weak var mainWindow: UIWindow?

    func install(over mainWindow: UIWindow, model: AppModel) {
        guard window == nil, let scene = mainWindow.windowScene else { return }
        self.mainWindow = mainWindow
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: ShieldView(model: model).qeetrixRootTheme().measuresScreenHeight())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = true
        self.window = window
        update(model.shield)
    }

    func update(_ shield: Shield) {
        guard let window else { return }
        if shield == .none {
            guard !window.isHidden else { return }
            window.isHidden = true
            mainWindow?.makeKey()
        } else if window.isHidden {
            window.makeKeyAndVisible()
        }
    }
}

/// The shield's content: the Locked screen, or the cover the app switcher shows.
struct ShieldView: View {
    let model: AppModel

    var body: some View {
        switch model.shield {
        case .locked: LockedView(lock: model.lock, requestWaiting: model.hasQueuedRequest)
        case .privacy: PrivacyCoverView()
        case .none: Color.clear
        }
    }
}

/// Reports the `UIWindow` a view is in, once it has one.
struct WindowReader: UIViewRepresentable {
    let onWindow: @MainActor (UIWindow) -> Void

    func makeUIView(context: Context) -> WindowReaderView {
        let view = WindowReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateUIView(_ uiView: WindowReaderView, context: Context) {}

    final class WindowReaderView: UIView {
        var onWindow: (@MainActor (UIWindow) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { onWindow?(window) }
        }
    }
}

extension View {
    /// The Qeetrix theme every window of the app uses: following the iPhone's appearance.
    func qeetrixRootTheme() -> some View {
        qeetrixThemeMode(.system)
    }
}
