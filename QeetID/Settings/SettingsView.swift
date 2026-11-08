import Qeetrix
import SwiftUI

/// Settings: the iPhone's link to the account (by its email), whether requests can reach it, and Unlink; the app lock
/// and hidden codes; AutoFill codes and moving to a new iPhone; administration; About and help. Same look as Accounts:
/// titles in caps, full-width ruled rows.
struct SettingsView: View {
    let model: AppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var alert: QeetrixAlertDialog?
    @State private var isUnlinking = false
    @State private var isAutoFillOn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                approvals
                security
                codes
                administration
                SettingsGroup("About") {
                    SettingsRow(Text("About and help"), value: Text("Version \(AppIdentity.version)")) { model.path.append(.about) }
                        .accessibilityIdentifier("settings.about")
                }
                #if DEBUG
                    QeetrixText(APIEnvironment.baseURL.absoluteString, size: .sm, tone: .subtlest, mono: true, align: .center)
                        .accessibilityIdentifier("settings.api")
                #endif
            }
            .padding(.top, 20)
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Settings"))
        .qeetrixAlertDialog($alert)
        .task(id: scenePhase) {
            isAutoFillOn = await OneTimeCodeIdentities.isEnabled()
            await model.refreshNotificationPermission()
            await model.admin.load()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings")
    }

    // MARK: - Sign-in approvals

    @ViewBuilder private var approvals: some View {
        let notificationsOn = model.notifications != .denied
        SettingsGroup("Sign-in approvals") {
            if let summary = model.link.summary {
                SettingsRow(
                    label: Text(verbatim: summary.accountEmail ?? String(localized: "Your Qeet ID account")),
                    detail: Text("\(summary.deviceName) · linked until \(QeetrixFormat.date(summary.linkedUntil, style: .long))")
                ) {
                    BrandMark(size: 40)
                } end: {
                    QeetrixBadge(notificationsOn ? "On" : "Off", tone: notificationsOn ? .success : .warning)
                }
                SettingsRule()
                SettingsRow(
                    Text("Notifications"),
                    detail: notificationsOn ? nil : Text("Sign-in requests can’t reach this iPhone. Turn notifications on in Settings."),
                    accessory: .none
                ) {
                    if notificationsOn {
                        QeetrixText("Allowed", size: .sm, tone: .subtle)
                    } else {
                        QeetrixButton("Open Settings", variant: .soft, size: .sm) { openNotificationSettings() }
                    }
                }
                SettingsRule()
                SettingsRow(Text("Unlink this iPhone"), danger: true) {
                    if !isUnlinking { confirmUnlink() }
                }
                .accessibilityIdentifier("settings.unlink")
            } else {
                SettingsRow(
                    label: Text("Not linked"), detail: Text("Approve Qeet ID sign-ins here instead of typing a code.")
                ) {
                    BrandMark(size: 40)
                } end: {
                    QeetrixButton("Link", size: .sm) { model.path.append(.linkIntro) }
                        .accessibilityIdentifier("settings.link")
                }
            }
        }
    }

    /// Unlink this iPhone: Qeetrix's danger dialog. What stops (requests, at once) and what stays (the codes), and to
    /// have another way to confirm sign-ins first.
    private func confirmUnlink() {
        let from = model.link.summary?.accountEmail.map { String(localized: "From \($0). ") } ?? ""
        alert = QeetrixAlertDialog(
            "Unlink this iPhone?",
            message: Text(
                "\(from)Sign-in requests stop coming here, at once. Your codes stay on this iPhone. Have another way to confirm sign-ins first, such as a passkey or another phone."
            ),
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
                    "Couldn’t unlink this iPhone", message: Text("\(error.connectionMessage) This iPhone is still linked; try again."))
            }
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }

    // MARK: - Security

    private var security: some View {
        let biometry = model.lock.biometry
        return SettingsGroup("Security") {
            SettingsRow(
                Text("Lock with \(biometry.name)"), detail: Text("Asks each time you open Qeet ID, and after 30 seconds away"),
                accessory: .none
            ) {
                Toggle(isOn: Binding(get: { model.preferences.isLockEnabled }, set: { setLock($0) })) {
                    Text("Lock with \(biometry.name)")
                }
                .labelsHidden()
                .toggleStyle(.qeetrixSwitch)
                .accessibilityIdentifier("settings.lock")
            }
            SettingsRule()
            SettingsRow(Text("Hide codes until tapped"), detail: Text("For when people can see your screen"), accessory: .none) {
                Toggle(isOn: Binding(get: { model.preferences.hidesCodes }, set: { model.preferences.hidesCodes = $0 })) {
                    Text("Hide codes until tapped")
                }
                .labelsHidden()
                .toggleStyle(.qeetrixSwitch)
                .accessibilityIdentifier("settings.hide-codes")
            }
        }
    }

    /// Turning the lock on or off asks for Face ID first, so someone holding an unlocked iPhone can't switch it off.
    private func setLock(_ isOn: Bool) {
        Task {
            let outcome = isOn ? await model.lock.enable() : await model.lock.disable()
            if outcome == .passcodeNotSet {
                alert = QeetrixAlertDialog(
                    "Set a passcode first",
                    message: Text("This iPhone has no passcode, so Qeet ID can’t be locked. Set one in iOS Settings."))
            }
        }
    }

    // MARK: - Codes, administration

    private var codes: some View {
        SettingsGroup("Codes") {
            if #available(iOS 18, *) {
                SettingsRow(Text("AutoFill codes"), value: isAutoFillOn ? Text("On") : Text("Off")) { model.path.append(.autoFill) }
                    .accessibilityIdentifier("settings.autofill")
                SettingsRule()
            }
            SettingsRow(Text("Move to a new iPhone")) { model.path.append(.move) }
                .accessibilityIdentifier("settings.move")
        }
    }

    private var administration: some View {
        let signedIn = model.admin.summary
        return SettingsGroup("Administration") {
            SettingsRow(
                Text("Administration"),
                detail: signedIn?.organizationName.map { Text("Signed in · \($0)") }
                    ?? Text("Access requests, emergencies and critical events")
            ) {
                if signedIn?.organizationId != nil {
                    model.path.append(.adminHome)
                } else if signedIn != nil {
                    model.path.append(.adminOrganizations)
                } else {
                    model.path.append(.adminSignIn)
                }
            }
            .accessibilityIdentifier("settings.admin")
        }
    }
}
