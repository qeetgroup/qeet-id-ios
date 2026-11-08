import Qeetrix
import SwiftUI

/// Accounts: the large title with how many are on this iPhone, search, whether sign-in requests come here (and
/// what stops them), each account's code, and press-and-hold for copy, rename and remove; with no accounts, both ways
/// to add one.
struct AccountsView: View {
    let model: AppModel
    @Environment(\.locale) private var locale
    @State private var showsAdd = false
    @State private var afterAdd: AddChoice?
    @State private var showsSetupKey = false
    @State private var renameIssuer = ""
    @State private var renameName = ""
    @State private var alert: QeetrixAlertDialog?

    private enum AddChoice { case scan, type }

    private var accounts: AccountsModel { model.accounts }

    var body: some View {
        list
            .qeetrixListStyle()
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.large)
            .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
            .toolbar { toolbar }
            .qeetrixAlertDialog($alert)
            .qeetrixSheet(isPresented: $showsAdd, detents: [.medium], onDismiss: openChosenWay) {
                AddAccountSheet(onScan: { afterAdd = .scan }, onTypeKey: { afterAdd = .type })
            }
            .qeetrixSheet(isPresented: $showsSetupKey) {
                SetupKeySheet { draft throws(AccountStoreError) in
                    let account = try accounts.add(draft)
                    model.accountAdded(account)
                }
            }
            .task { await accounts.runClock() }
    }

    /// Opens the way chosen in Add an account once its sheet has gone.
    private func openChosenWay() {
        switch afterAdd {
        case .scan: model.modal = .addAccount
        case .type: showsSetupKey = true
        case nil: break
        }
        afterAdd = nil
    }

    @ViewBuilder private var list: some View {
        if accounts.accounts.isEmpty {
            List {
                countLine
                problems
                approvalsSection
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
                countLine
                problems
                if accounts.query.isEmpty { approvalsSection }
                Section {
                    let visible = accounts.visibleAccounts
                    if visible.isEmpty {
                        noResults
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(visible) { account in
                        row(account)
                    }
                } header: {
                    if accounts.query.isEmpty { QeetrixSectionHeader("Codes", isRuled: false) }
                }
                .listSectionSeparator(.hidden, edges: .top)
            }
            .searchable(
                text: Binding(get: { accounts.query }, set: { accounts.query = $0 }),
                placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search accounts")
            )
            .qeetrixRefreshable { await model.checkPendingRequests(force: true) }
        }
    }

    /// "2 on this iPhone", under the large title.
    private var countLine: some View {
        let count = accounts.accounts.count
        return Section {
            EmptyView()
        } header: {
            Group {
                if count == 0 {
                    Text("None yet")
                } else {
                    Text("\(count) on this iPhone")
                }
            }
            .qeetrixTextStyle(.bodySm)
            .foregroundStyle(QeetrixColor.textSubtle)
            .textCase(nil)
            .accessibilityIdentifier("accounts.count")
        }
    }

    /// Nothing matches the search: say so, and offer to add it.
    private var noResults: some View {
        VStack(spacing: QeetrixSpace.gapXs) {
            QeetrixText("No accounts match “\(accounts.query)”", weight: .semibold, align: .center)
            QeetrixText("Check the spelling, or add the account.", size: .sm, tone: .subtle, align: .center)
            QeetrixButton("Add account", icon: .plus, variant: .soft) { showsAdd = true }
                .padding(.top, QeetrixSpace.insetLg)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, QeetrixSpace.layoutSm)
    }

    /// What stops sign-in requests reaching this iPhone, with the fix. Offline, codes still work.
    @ViewBuilder private var problems: some View {
        let link = model.link
        if link.isLinked && (link.isStale || model.notifications == .denied || model.network.isOffline) {
            Section {
                VStack(spacing: QeetrixSpace.gapSm) {
                    if link.isStale {
                        QeetrixAlert(
                            "This iPhone was unlinked from Qeet ID",
                            description: String(localized: "Codes still work; link again to approve sign-ins."), tone: .warning
                        ) {
                            QeetrixButton("Link again", variant: .soft, size: .sm) { model.path = [.linkIntro] }
                        }
                        .accessibilityIdentifier("problem.stale")
                    }
                    if model.notifications == .denied {
                        QeetrixAlert(
                            "Sign-in requests can’t reach this iPhone",
                            description: String(localized: "Notifications are off for Qeet ID."),
                            tone: .warning
                        ) {
                            QeetrixButton("Turn on", variant: .soft, size: .sm) { openNotificationSettings() }
                        }
                        .accessibilityIdentifier("problem.notifications")
                    }
                    if model.network.isOffline {
                        QeetrixAlert(
                            "You’re offline",
                            description: String(localized: "Codes still work. Sign-in requests arrive when you’re back online.")
                        )
                        .accessibilityIdentifier("problem.offline")
                    }
                }
                .padding(.horizontal, QeetrixSpace.insetLg)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    /// Whether this iPhone gets sign-in requests, and for which account: a one-row list.
    private var approvalsSection: some View {
        let summary = model.link.summary
        return Section {
            NavigationLink(value: summary == nil ? Route.linkIntro : Route.settings) {
                HStack(spacing: QeetrixSpace.gapMd) {
                    QeetrixIcon(.shieldCheck, shape: .sharp)
                        .foregroundStyle(summary == nil ? QeetrixColor.iconSubtle : QeetrixColor.iconSuccess)
                        .frame(width: 40, height: 40)
                        .background(
                            summary == nil ? QeetrixColor.bgNeutralSubtle : QeetrixColor.bgSuccessSubtle,
                            in: RoundedRectangle(cornerRadius: QeetrixRadius.control))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign-in approvals").qeetrixTextStyle(.labelMd).fontWeight(.semibold).foregroundStyle(QeetrixColor.textDefault)
                        Group {
                            if let summary {
                                if let email = summary.accountEmail {
                                    Text("For \(email)")
                                } else {
                                    Text("Linked · \(summary.deviceName)")
                                }
                            } else {
                                Text("Link this iPhone to approve Qeet ID sign-ins")
                            }
                        }
                        .qeetrixTextStyle(.bodySm)
                        .foregroundStyle(QeetrixColor.textSubtle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if summary != nil {
                        QeetrixBadge("On", tone: .success)
                    } else {
                        QeetrixBadge("Link", tone: .brand, variant: .solid)
                    }
                }
                .padding(.vertical, 4)
            }
            .qeetrixListRow()
            .padding(.horizontal, QeetrixSpace.insetLg)
            .accessibilityIdentifier(summary == nil ? "accounts.link" : "accounts.approvals")
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
    }

    private func row(_ account: OTPAccount) -> some View {
        let code = accounts.codes[account.id]
        return AccountRow(
            account: account, code: code, hidesCode: model.preferences.hidesCodes,
            toast: toast
        )
        .contextMenu {
            if let code {
                QeetrixMenuItem("Copy Code", icon: .copy) { copy(code) }
            }
            QeetrixMenuItem("Rename", icon: .pencil) { startRenaming(account) }
            Divider()
            QeetrixMenuItem("Remove from this iPhone", icon: .trash, tone: .danger) { confirmRemove(account) }
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
            Button("Remove from this iPhone") { confirmRemove(account) }
        }
        .accessibilityIdentifier("account.\(account.issuer)")
    }

    /// No accounts yet: where codes come from, and both ways in; and, while not linked, the way to approve sign-ins.
    private var emptyState: some View {
        VStack(spacing: 0) {
            QeetrixIcon(.scanQrCode, size: .lg, shape: .sharp)
                .foregroundStyle(QeetrixColor.iconBrand)
                .frame(width: 56, height: 56)
                .background(QeetrixColor.bgBrandSubtle, in: RoundedRectangle(cornerRadius: QeetrixRadius.control))
            QeetrixHeading("No accounts yet", level: 2, size: .titleLg, align: .center)
                .padding(.top, QeetrixSpace.insetLg)
            QeetrixText(
                "Turn on 2-step verification on a website or app. It shows a QR code: scan it here.", tone: .subtle, align: .center
            )
            .frame(maxWidth: 300)
            .padding(.top, 6)
            VStack(spacing: QeetrixSpace.gapSm) {
                QeetrixButton("Scan QR code", icon: .scanLine, size: .lg, isFullWidth: true) { model.modal = .addAccount }
                    .accessibilityIdentifier("empty.scan")
                QeetrixButton("Type the key instead", icon: .keyboard, variant: .ghost, size: .lg, isFullWidth: true) {
                    showsSetupKey = true
                }
                .accessibilityIdentifier("empty.type")
            }
            .frame(maxWidth: 320)
            .padding(.top, QeetrixSpace.layoutSm)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, QeetrixSpace.insetXl)
        .padding(.top, QeetrixSpace.insetXl)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accounts.empty")
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showsAdd = true
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

    private var toast: Binding<QeetrixToast?> {
        Binding(get: { model.toast }, set: { model.toast = $0 })
    }

    /// Copy Code from the menu: Qeetrix's copy, as a tap on the code does — on this iPhone only, gone after a minute.
    private func copy(_ code: GeneratedCode) {
        QeetrixCopy.copy(code.code, isSensitive: true, toast: toast, locale: locale)
    }

    /// Rename: Qeetrix's dialog with the site and the account name. Only this iPhone sees the change.
    private func startRenaming(_ account: OTPAccount) {
        renameIssuer = account.issuer
        renameName = account.name
        alert = QeetrixAlertDialog(
            "Rename",
            message: Text("Only changes how it shows on this iPhone. \(account.issuer) isn’t told."),
            textFields: [
                QeetrixAlertTextField("Site or app", text: $renameIssuer, contentType: .organizationName, isRequired: true),
                QeetrixAlertTextField("Account", text: $renameName, contentType: .username),
            ],
            actions: [
                QeetrixDialogAction("Cancel", role: .cancel),
                QeetrixDialogAction("Save") { accounts.rename(account, issuer: renameIssuer, name: renameName) },
            ])
    }

    /// Remove: Qeetrix's danger dialog. The codes stop on this iPhone, and the site still asks for one.
    private func confirmRemove(_ account: OTPAccount) {
        let who = account.name.isEmpty ? account.issuer : account.name
        alert = QeetrixAlertDialog(
            title: Text("Remove \(account.issuer)?"),
            message: Text(
                "Codes for \(who) will stop on this iPhone. \(account.issuer) will still ask for a code when you sign in. Turn off 2-step verification there first, or set it up in another app, so you aren’t locked out."
            ),
            actions: [
                QeetrixDialogAction("Cancel", role: .cancel),
                QeetrixDialogAction("Remove", role: .destructive) {
                    accounts.delete(account)
                    QeetrixFeedback.success.play()
                    model.toast = QeetrixToast(.info, title: String(localized: "\(account.issuer) removed"))
                },
            ])
    }
}
