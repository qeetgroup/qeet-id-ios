import Qeetrix
import SwiftUI

/// Get sign-in requests (step 2 of 2): the request people will get, as the iPhone shows it, why notifications are
/// asked for and what they carry, before iOS asks, so "Don't Allow" isn't tapped by reflex. Refused before: the fix is
/// in Settings.
struct NotificationsPrimerView: View {
    let lock: AppLock
    let onDone: @MainActor () -> Void
    @Environment(\.room) private var room
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var permission: NotificationPermission = .notDetermined

    var body: some View {
        let refused = permission == .denied
        ScrollView {
            PageColumn {
                // The request people will get, as the iPhone shows it.
                NotificationPreview()
                    .padding(room.isShort ? QeetrixSpace.insetSm : QeetrixSpace.insetMd)
                    .frame(maxWidth: .infinity)
                    .brandPanel()
                PageTitle(
                    title: Text("Get sign-in requests on this iPhone"),
                    line: Text(
                        "Qeet ID asks you to approve each sign-in to your account. Allow notifications so the requests reach you, even when the app is closed."
                    )
                )
                .padding(.top, room.isShort ? QeetrixSpace.gapMd : QeetrixSpace.layoutSm)
                Group {
                    if refused {
                        QeetrixAlert("Turn on notifications for Qeet ID in Settings so sign-in requests reach you.", tone: .warning)
                            .accessibilityIdentifier("onboarding.notifications-denied")
                    } else {
                        Panel {
                            Fact("Only sign-in requests. Nothing else, no marketing.")
                            Fact("Time-sensitive, so they reach you in a Focus")
                            if !room.isShort {
                                Fact(Text("Approving still asks for \(lock.biometry.name)"))
                            }
                        }
                    }
                }
                .padding(.top, room.isShort ? QeetrixSpace.gapMd : QeetrixSpace.insetLg)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(QeetrixColor.surfaceCanvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            // The bar alone, as the mockup draws it; the step is in the bar's title, and VoiceOver reads the label.
            QeetrixProgress(label: nil, value: 1)
                .accessibilityLabel(Text("Setting up: step 2 of 2"))
        }
        .screenBar(Text("Step 2 of 2"))
        .actionFooter(
            primary: refused
                ? QeetrixScreenAction("Open Settings") { openSettings() }
                : QeetrixScreenAction("Allow notifications", icon: .bell) { requestPermission() },
            tertiary: QeetrixScreenAction("Not now", tone: .neutral) { onDone() }
        )
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { permission = await NotificationPermission.current() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.notifications")
    }

    private func requestPermission() {
        Task {
            lock.beginSystemPrompt()
            permission = await NotificationPermission.request()
            lock.endSystemPrompt()
            onDone()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }
}

/// A picture of the sign-in request as iOS shows it: the app's icon and name, the time, the title and one line. A
/// picture of the system's banner, so its rounded corners are the system's.
private struct NotificationPreview: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            BrandMark(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Sign-in request").qeetrixTextStyle(.labelMd).fontWeight(.semibold)
                    Spacer(minLength: 0)
                    Text("now").qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
                }
                Text("Someone is signing in to your Qeet ID account. Tap to review.")
                    .qeetrixTextStyle(.bodySm)
                    .foregroundStyle(QeetrixColor.textSubtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(QeetrixColor.textDefault)
        .padding(12)
        .background(QeetrixColor.surfaceOverlay, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityHidden(true)
    }
}
