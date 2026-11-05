import Qeetrix
import SwiftUI

/// Screens 22 and 23, Settings: titled cards for the linked account (with Unlink, a quiet red action), the lock and
/// hidden codes, AutoFill, and help and privacy.
struct SettingsView: View {
    let model: AppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var alert: QeetrixAlertDialog?
    @State private var isUnlinking = false
    @State private var isAutoFillOn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.gapLg) {
                approvals
                security
                more
                about
            }
            .padding(QeetrixSpace.insetLg)
        }
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
        .qeetrixAlertDialog($alert)
        .task(id: scenePhase) { isAutoFillOn = await OneTimeCodeIdentities.isEnabled() }
        .accessibilityIdentifier("settings")
    }

    // MARK: - Sign-in approvals

    private var approvals: some View {
        let summary = model.link.summary
        return QeetrixCard(title: Text("Sign-in approvals")) {
            if let summary {
                QeetrixDescriptionList {
                    QeetrixDescriptionItem("Account", value: summary.accountEmail ?? String(localized: "your Qeet ID account"))
                    QeetrixDescriptionItem(
                        "This iPhone",
                        value: String(localized: "\(summary.deviceName) · until \(QeetrixFormat.date(summary.linkedUntil, style: .long))"))
                }
            } else {
                QeetrixText("Link this iPhone to approve Qeet ID sign-ins with \(model.lock.biometry.name).", tone: .subtle)
            }
        } actions: {
            QeetrixBadge(summary == nil ? "Off" : "On", tone: summary == nil ? .neutral : .success)
        } footer: {
            if summary != nil {
                QeetrixButton("Unlink this iPhone", variant: .ghost, tone: .danger, size: .sm, isLoading: isUnlinking) { confirmUnlink() }
                    .accessibilityIdentifier("settings.unlink")
            } else {
                QeetrixButton("Link this iPhone", icon: .chevronRight, variant: .ghost, size: .sm) { model.path.append(.linkIntro) }
                    .accessibilityIdentifier("settings.link")
            }
        }
    }

    private func confirmUnlink() {
        let account = model.link.summary?.accountEmail ?? String(localized: "your Qeet ID account")
        alert = QeetrixAlertDialog(
            "Unlink this iPhone?",
            message: Text("Sign-in requests for \(account) will stop coming here. Your sign-in codes stay on this iPhone."),
            actions: [
                QeetrixDialogAction("Cancel", role: .cancel),
                QeetrixDialogAction("Unlink", role: .destructive) { unlink() },
            ])
    }

    private func unlink() {
        Task {
            isUnlinking = true
            defer { isUnlinking = false }
            do throws(APIError) {
                _ = try await model.link.unlink()
                QeetrixFeedback.success.play()
                model.toast = QeetrixToast(.success, title: String(localized: "This iPhone is unlinked"))
            } catch {
                QeetrixFeedback.error.play()
                alert = QeetrixAlertDialog(
                    "Couldn't unlink this iPhone", message: Text("\(error.connectionMessage) The link stays until Qeet ID removes it."))
            }
        }
    }

    // MARK: - Security

    private var security: some View {
        QeetrixCard(title: Text("Security")) {
            QeetrixSwitch(
                isOn: Binding(get: { model.preferences.isLockEnabled }, set: { setLock($0) }),
                description: Text("\(model.lock.biometry.name) or passcode to open")
            ) {
                Text(model.lock.biometry.lockTitle)
            }
            .accessibilityIdentifier("settings.lock")
            QeetrixSwitch(
                "Hide codes until tapped", isOn: Binding(get: { model.preferences.hidesCodes }, set: { model.preferences.hidesCodes = $0 }),
                description: Text("For screens others can see")
            )
            .accessibilityIdentifier("settings.hide-codes")
        }
    }

    /// Turning the lock on or off asks for Face ID first, so someone holding an unlocked iPhone can't switch it off.
    private func setLock(_ isOn: Bool) {
        Task {
            let outcome = isOn ? await model.lock.enable() : await model.lock.disable()
            if outcome == .passcodeNotSet {
                alert = QeetrixAlertDialog(
                    "Set a passcode first",
                    message: Text("This iPhone has no passcode, so Qeet ID can't be locked. Set one in iOS Settings."))
            }
        }
    }

    // MARK: - AutoFill, help

    private var more: some View {
        VStack(spacing: 0) {
            if #available(iOS 18, *) {
                QeetrixListItem("AutoFill codes", value: Route.autoFill) {
                    QeetrixListItemIcon(.keyboard)
                } trailing: {
                    QeetrixBadge(isAutoFillOn ? "On" : "Off", tone: isAutoFillOn ? .success : .neutral)
                }
                .accessibilityIdentifier("settings.autofill")
                QeetrixSeparator()
            }
            QeetrixListItem("Help and privacy", metadata: Text(verbatim: AppIdentity.version), accessory: .chevron) {
                openURL(QeetIDLinks.helpAndPrivacy)
            } leading: {
                QeetrixListItemIcon(.info)
            }
            .accessibilityIdentifier("settings.help")
        }
        .background(QeetrixColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: QeetrixRadius.surface))
        .overlay {
            RoundedRectangle(cornerRadius: QeetrixRadius.surface)
                .strokeBorder(QeetrixColor.borderDefault, lineWidth: QeetrixBorderWidth.default)
        }
    }

    private var about: some View {
        VStack(spacing: QeetrixSpace.gapXs) {
            QeetrixText("Qeet ID \(AppIdentity.version) (\(AppIdentity.build)) · by Qeet Group", size: .sm, tone: .subtle, align: .center)
            #if DEBUG
                QeetrixText(APIEnvironment.baseURL.absoluteString, size: .sm, tone: .subtlest, mono: true, align: .center)
                    .accessibilityIdentifier("settings.api")
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.top, QeetrixSpace.gapSm)
    }
}
