import AuthenticationServices
import Qeetrix
import SwiftUI

/// Screen 25, AutoFill codes: iOS 18 and later let Qeet ID fill its codes into apps and Safari, right above the
/// keyboard, once it's turned on in iOS Settings.
struct AutoFillSetupView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.layoutSm) {
                QeetrixText(
                    "Your codes appear above the keyboard when a site or app asks for one. Tap to fill; nothing to copy.", size: .lg,
                    tone: .subtle)
                if isEnabled {
                    QeetrixAlert(
                        "AutoFill codes are on", description: "Qeet ID's codes appear above the keyboard when a site asks for one.",
                        tone: .success
                    )
                    .accessibilityIdentifier("autofill.on")
                }
                QuickTypeIllustration()
                VStack(spacing: 0) {
                    FeatureRow(title: Text("Open iOS Settings"), description: Text("General, then AutoFill & Passwords")) {
                        StepNumber(number: 1)
                    }
                    FeatureRow(title: Text("Turn on Qeet ID"), description: Text("Under “AutoFill From” and Verification Codes")) {
                        StepNumber(number: 2)
                    }
                }
            }
            .padding(QeetrixSpace.insetLg)
        }
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle("AutoFill codes")
        .navigationBarTitleDisplayMode(.inline)
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
        .qeetrixBottomActionBar(primary: QeetrixScreenAction("Open iOS Settings", icon: .settings) { openSettings() })
        .task(id: scenePhase) { isEnabled = await OneTimeCodeIdentities.isEnabled() }
        .accessibilityIdentifier("autofill")
    }

    private func openSettings() {
        Task {
            if #available(iOS 18, *) {
                try? await ASSettingsHelper.openCredentialProviderAppSettings()
            }
        }
    }
}

/// What AutoFill looks like: a code field, and Qeet ID's code in the bar above the keyboard.
private struct QuickTypeIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Verification code")
                .qeetrixTextStyle(.bodyMd)
                .foregroundStyle(QeetrixColor.textSubtlest)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, QeetrixSpace.insetMd)
                .background(
                    QeetrixColor.bgNeutralSubtle,
                    in: UnevenRoundedRectangle(topLeadingRadius: QeetrixRadius.control, topTrailingRadius: QeetrixRadius.control)
                )
                .overlay(alignment: .bottom) { Rectangle().fill(QeetrixColor.borderStrong).frame(height: 1) }
                .padding(QeetrixSpace.insetMd)
            HStack(spacing: QeetrixSpace.gapXs) {
                Text("From")
                QeetIDMark(size: 16)
                Text(verbatim: "Qeet ID · 482 913")
                    .monospacedDigit()
            }
            .qeetrixTextStyle(.labelMd)
            .foregroundStyle(QeetrixColor.textDefault)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(QeetrixColor.bgNeutralSubtleHover)
        }
        .background(QeetrixColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: QeetrixRadius.surface))
        .overlay { RoundedRectangle(cornerRadius: QeetrixRadius.surface).strokeBorder(QeetrixColor.borderDefault) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Example: a code field, with Qeet ID's code offered above the keyboard"))
    }
}
