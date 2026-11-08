import Qeetrix
import SwiftUI

/// About and help: the version (tap to copy it with the build number, to quote when asking for help), help first, then
/// the legal pages. An arrow out marks a row that leaves the app.
struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @State private var toast: QeetrixToast?
    @State private var showsLicences = false

    var body: some View {
        let version = String(localized: "Version \(AppIdentity.version) (\(AppIdentity.build))")
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: QeetrixSpace.gapXs) {
                    BrandMark(size: 64)
                    QeetrixText("Qeet ID", size: .lg, weight: .semibold)
                        .padding(.top, QeetrixSpace.gapSm)
                    Button {
                        QeetrixCopy.copy(version, toast: $toast, locale: locale)
                    } label: {
                        Text(verbatim: version).qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Copies the version"))
                    .accessibilityIdentifier("about.version")
                }
                .padding(.top, 28)
                .padding(.bottom, QeetrixSpace.insetXl)
                SettingsGroup("Help") {
                    SettingsRow(Text("Help centre"), detail: Text("How codes and sign-in approvals work"), accessory: .external) {
                        openURL(QeetIDLinks.help)
                    }
                    SettingsRule()
                    SettingsRow(Text("Contact support"), detail: Text(verbatim: "support@qeet.in"), accessory: .external) {
                        openURL(QeetIDLinks.support)
                    }
                }
                SettingsGroup("Legal") {
                    SettingsRow(Text("Privacy policy"), accessory: .external) { openURL(QeetIDLinks.privacy) }
                        .accessibilityIdentifier("about.privacy")
                    SettingsRule()
                    SettingsRow(Text("Terms of use"), accessory: .external) { openURL(QeetIDLinks.terms) }
                    SettingsRule()
                    SettingsRow(Text("Licences")) { showsLicences = true }
                }
                HStack(spacing: 4) {
                    Text("from").foregroundStyle(QeetrixColor.textSubtle)
                    Text(verbatim: "Qeet Group").fontWeight(.semibold).foregroundStyle(QeetrixColor.textDefault)
                }
                .qeetrixTextStyle(.bodySm)
                Text("© 2026 Qeet Group")
                    .qeetrixTextStyle(.labelSm)
                    .foregroundStyle(QeetrixColor.textSubtle)
                    .padding(.top, 2)
                    .padding(.bottom, QeetrixSpace.layoutSm)
            }
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("About and help"))
        .qeetrixToast($toast)
        .qeetrixSheet(isPresented: $showsLicences, detents: [.medium, .large]) {
            QeetrixSheetContent(
                "Licences", description: Text("Qeet ID is built with these, each under its own licence."),
                onClose: {
                    showsLicences = false
                }
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(Self.thirdParty.enumerated()), id: \.offset) { index, item in
                        if index > 0 { QeetrixSeparator() }
                        SettingsRow(Text(verbatim: item.name), detail: Text(verbatim: item.licence), accessory: .external) {
                            openURL(item.url)
                        }
                    }
                }
            } actions: {
                EmptyView()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("about")
    }

    /// What Qeet ID is built with, and under which licence: names, not translated.
    private static let thirdParty: [(name: String, licence: String, url: URL)] = [
        ("Qeetrix for iOS", "MIT License", URL(string: "https://opensource.org/license/mit")!),
        ("Icons, based on Lucide and Feather", "MIT and ISC Licenses", URL(string: "https://lucide.dev/license")!),
        ("Qeet Sans (Cal Sans) and Fira Code", "SIL Open Font License 1.1", URL(string: "https://openfontlicense.org")!),
    ]
}
