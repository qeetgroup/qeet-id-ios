import Qeetrix
import SwiftUI

/// Screens 4, 5, 9, 10 and 26: the large title and search, each account's code, and the context menu with copy,
/// rename and delete; with no accounts, both ways to add one.
struct AccountsView: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsSetupKey = false
    @State private var renaming: OTPAccount?
    @State private var renameIssuer = ""
    @State private var renameName = ""
    @State private var confirmation: QeetrixConfirmationDialog?

    private var accounts: AccountsModel { model.accounts }

    var body: some View {
        list
            .qeetrixListStyle()
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.large)
            .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
            .toolbar { toolbar }
            .qeetrixConfirmationDialog($confirmation)
            .alert("Rename account", isPresented: isRenaming, presenting: renaming) { account in
                TextField("Service", text: $renameIssuer)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("rename.service")
                TextField("Account", text: $renameName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("rename.account")
                Button("Cancel", role: .cancel) {}
                Button("Save") { accounts.rename(account, issuer: renameIssuer, name: renameName) }
            } message: { _ in
                Text("Only changes how it's shown on this iPhone.")
            }
            .qeetrixSheet(isPresented: $showsSetupKey) {
                SetupKeySheet { draft throws(AccountStoreError) in
                    let account = try accounts.add(draft)
                    model.accountAdded(account)
                }
            }
            .task { await accounts.runClock() }
    }

    @ViewBuilder private var list: some View {
        if accounts.accounts.isEmpty {
            List {
                problems
                if model.link.isLinked { approvalsSection }
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
            }
            .qeetrixRefreshable { await model.checkPendingRequests(force: true) }
        } else {
            List {
                problems
                approvalsSection
                Section {
                    let visible = accounts.visibleAccounts
                    if visible.isEmpty {
                        QeetrixEmptyState("No results", description: "No account matches your search.", icon: .search, size: .section)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(visible) { account in
                        row(account)
                    }
                } header: {
                    QeetrixSectionHeader("Codes", isRuled: false)
                }
                .listSectionSeparator(.hidden, edges: .top)
            }
            .searchable(
                text: Binding(get: { accounts.query }, set: { accounts.query = $0 }),
                placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search")
            )
            .qeetrixRefreshable { await model.checkPendingRequests(force: true) }
        }
    }

    /// Screen 24: what stops requests reaching this iPhone, with the fix. Offline, codes still work.
    @ViewBuilder private var problems: some View {
        let link = model.link
        if link.isLinked && (link.isStale || model.notifications == .denied || model.network.isOffline) {
            Section {
                VStack(spacing: 0) {
                    if link.isStale {
                        QeetrixAlert(
                            "Sign-in requests have stopped",
                            description: String(
                                localized: "Qeet ID no longer accepts this iPhone's link. Link it again to approve sign-ins."),
                            tone: .warning, icon: .bellOff
                        ) {
                            QeetrixButton("Link again", size: .sm) { model.path = [.linkIntro] }
                        }
                        .accessibilityIdentifier("problem.stale")
                    }
                    if model.notifications == .denied {
                        QeetrixAlert(
                            "Sign-in requests are off",
                            description: String(localized: "Notifications are off for Qeet ID, so requests won't reach this iPhone."),
                            tone: .warning, icon: .bellOff
                        ) {
                            QeetrixButton("Open Settings", size: .sm) { openNotificationSettings() }
                        }
                        .accessibilityIdentifier("problem.notifications")
                    }
                    if model.network.isOffline {
                        QeetrixAlert(
                            "You're offline", description: String(localized: "Codes still work. Approvals arrive when you reconnect."),
                            icon: .wifiOff
                        )
                        .accessibilityIdentifier("problem.offline")
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    /// Sign-in approvals: linked and on, or the way to link.
    @ViewBuilder private var approvalsSection: some View {
        Section {
            if let summary = model.link.summary {
                QeetrixListItem(
                    "Sign-in approvals", description: Text("Linked · \(summary.deviceName)"), value: Route.settings
                ) {
                    QeetrixListItemIcon(.smartphone)
                } trailing: {
                    QeetrixBadge("On", tone: .success)
                }
                .accessibilityIdentifier("accounts.approvals")
            } else {
                QeetrixListItem(
                    "Sign-in approvals", description: Text("Link this iPhone to approve Qeet ID sign-ins"), value: Route.linkIntro
                ) {
                    QeetrixListItemIcon(.smartphone)
                }
                .accessibilityIdentifier("accounts.link")
            }
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
    }

    private func row(_ account: OTPAccount) -> some View {
        let code = accounts.codes[account.id]
        return AccountRow(
            account: account, code: code, hidesCode: model.preferences.hidesCodes,
            toast: Binding(get: { model.toast }, set: { model.toast = $0 })
        )
        .qeetrixListRow(colorScheme: colorScheme)
        .contextMenu {
            if let code {
                QeetrixMenuItem("Copy Code", icon: .copy) { copy(code) }
            }
            QeetrixMenuItem("Rename", icon: .pencil) { startRenaming(account) }
            Divider()
            QeetrixMenuItem("Delete Account", icon: .trash, tone: .danger) { confirmDelete(account) }
        } preview: {
            AccountRow(account: account, code: code, hidesCode: model.preferences.hidesCodes, toast: nil)
                .frame(width: 340)
                .background(QeetrixColor.surfaceRaised)
                .qeetrixRootTheme()
        }
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if let code {
                Button("Copy Code") { copy(code) }
            }
            Button("Rename") { startRenaming(account) }
            Button("Delete Account") { confirmDelete(account) }
        }
        .accessibilityIdentifier("account.\(account.issuer)")
    }

    private var emptyState: some View {
        QeetrixEmptyState(
            "No accounts yet", description: "Turn on 2-step verification on a website or app. It shows a QR code; scan it here.",
            icon: .keyRound, level: 2
        ) {
            QeetrixButton("Scan QR code", icon: .scanLine) { model.modal = .addAccount }
                .accessibilityIdentifier("empty.scan")
            QeetrixButton("Type the key", variant: .ghost) { showsSetupKey = true }
                .accessibilityIdentifier("empty.type")
        } footer: {
            if !model.link.isLinked {
                Button {
                    model.path = [.linkIntro]
                } label: {
                    Text("Using Qeet ID? ") + Text("Link this iPhone").foregroundStyle(QeetrixColor.textLink)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("empty.link")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, QeetrixSpace.layoutLg)
        .accessibilityIdentifier("accounts.empty")
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.modal = .addAccount
            } label: {
                Label {
                    Text("Add account")
                } icon: {
                    Image(qeetrix: .plus, shape: .sharp)
                }
            }
            .accessibilityIdentifier("accounts.add")
            NavigationLink(value: Route.settings) {
                Label {
                    Text("Settings")
                } icon: {
                    Image(qeetrix: .settings, shape: .sharp)
                }
            }
            .accessibilityIdentifier("accounts.settings")
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private func copy(_ code: GeneratedCode) {
        SensitiveCopy.copy(code.code)
        QeetrixFeedback.lightImpact.play()
        model.toast = QeetrixToast(
            .success, title: String(localized: "Copied"), description: String(localized: "Clears from the clipboard after 1 minute"))
    }

    private func startRenaming(_ account: OTPAccount) {
        renameIssuer = account.issuer
        renameName = account.name
        renaming = account
    }

    private func confirmDelete(_ account: OTPAccount) {
        let message =
            account.name.isEmpty
            ? Text(
                "You'll stop getting codes for \(account.issuer). Turn off 2-step verification on \(account.issuer) first, or you may be locked out."
            )
            : Text(
                "You'll stop getting codes for \(account.name). Turn off 2-step verification on \(account.issuer) first, or you may be locked out."
            )
        confirmation = QeetrixConfirmationDialog(
            title: Text("Delete \(account.issuer)?"), message: message,
            actions: [
                QeetrixDialogAction("Delete Account", role: .destructive) {
                    accounts.delete(account)
                    QeetrixFeedback.success.play()
                    model.toast = QeetrixToast(.info, title: String(localized: "\(account.issuer) deleted"))
                }
            ])
    }
}
