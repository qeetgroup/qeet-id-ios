import Qeetrix
import SwiftUI

/// Screen 3, Get sign-in requests (step 2 of 2): why notifications, before iOS asks, so "Don't Allow" isn't tapped by
/// reflex.
struct NotificationsPrimerView: View {
    let lock: AppLock
    let onDone: @MainActor () -> Void
    @State private var permission: NotificationPermission = .notDetermined

    var body: some View {
        ScrollView {
            VStack(spacing: QeetrixSpace.gapLg) {
                QeetrixPermissionPrimer(
                    .notifications, status: permission == .denied ? .denied : .notDetermined,
                    title: "Get sign-in requests on this iPhone",
                    message: "Qeet ID asks you to approve each sign-in to your account. Allow notifications so the requests reach you.",
                    headingLevel: 1,
                    onContinue: { requestPermission() },
                    onNotNow: { onDone() })
                QeetrixText("Only sign-in requests. Nothing else, no marketing.", size: .sm, tone: .subtle, align: .center)
                    .padding(.horizontal, QeetrixSpace.insetLg)
            }
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle("Step 2 of 2")
        .navigationBarTitleDisplayMode(.inline)
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
        .task { permission = await NotificationPermission.current() }
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
}
