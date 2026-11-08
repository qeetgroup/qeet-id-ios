import AuthenticationServices
import Qeetrix
import SwiftUI

/// AutoFill codes (iOS 18 and later): a picture of a site asking for a code with the keyboard offering it from Qeet ID,
/// what filling promises, then Turn on AutoFill, which asks iOS with its own alert. Once it's on, the screen says so.
struct AutoFillSetupView: View {
    let biometry: Biometry
    let onDone: @MainActor () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.room) private var room
    @State private var isEnabled = false
    @State private var isAsking = false

    var body: some View {
        ScrollView {
            PageColumn {
                QuickTypeIllustration()
                    .padding(room.isShort ? QeetrixSpace.insetSm : QeetrixSpace.insetMd)
                    .frame(maxWidth: .infinity)
                    .brandPanel()
                PageTitle(
                    title: Text("Fill in codes with a tap"),
                    line: Text("When a website or app asks for a code, the keyboard offers it from Qeet ID. No copying.")
                )
                .padding(.top, room.isShort ? QeetrixSpace.gapMd : QeetrixSpace.layoutSm)
                if isEnabled {
                    QeetrixAlert(
                        "AutoFill is on",
                        description: "To turn it off, open the phone’s Settings, then General, then AutoFill & Passwords.", tone: .success
                    )
                    .padding(.top, QeetrixSpace.insetLg)
                    .accessibilityIdentifier("autofill.on")
                } else {
                    Panel {
                        Fact(Text("\(biometry.name) first, every time"))
                        Fact("Only the code for the site that’s open")
                        Fact("Codes never leave this iPhone")
                    }
                    .padding(.top, room.isShort ? QeetrixSpace.gapMd : QeetrixSpace.insetLg)
                }
            }
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("AutoFill codes"))
        .actionFooter(
            primary: isEnabled
                ? QeetrixScreenAction("Done") { onDone() }
                : QeetrixScreenAction("Turn on AutoFill", isLoading: isAsking) { turnOn() },
            tertiary: isEnabled ? nil : QeetrixScreenAction("Not now", tone: .neutral) { onDone() }
        )
        .task(id: scenePhase) { isEnabled = await OneTimeCodeIdentities.isEnabled() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autofill")
    }

    /// Asks iOS to turn on Qeet ID's AutoFill, with the system's own alert.
    private func turnOn() {
        Task {
            isAsking = true
            defer { isAsking = false }
            if #available(iOS 18, *) {
                _ = await ASSettingsHelper.requestToTurnOnCredentialProviderExtension()
            }
            isEnabled = await OneTimeCodeIdentities.isEnabled()
        }
    }
}

/// What AutoFill looks like: a site's code field, and Qeet ID's code in the bar above the keyboard. A picture of other
/// screens, so its page is white in dark mode too.
private struct QuickTypeIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: QeetrixSpace.gapSm) {
                Text(verbatim: "github.com").font(.caption).foregroundStyle(Color(white: 0.35))
                Text("Verification code")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.45))
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .padding(.horizontal, 10)
                    .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Color(white: 0.8)) }
            }
            .padding(12)
            .background(Color.white)
            HStack(spacing: 6) {
                BrandMark(size: 16)
                Text("From Qeet ID").font(.footnote.weight(.semibold))
                Text(verbatim: "093 551").font(.footnote.monospacedDigit())
            }
            .foregroundStyle(Color(white: 0.1))
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Color(white: 0.85))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Example: a code field, with Qeet ID’s code offered above the keyboard"))
    }
}
