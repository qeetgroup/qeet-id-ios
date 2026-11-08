import Qeetrix
import SwiftUI

// MARK: - Shared

/// Loads a screen's data from Qeet ID, and again on Try again or on coming back to the screen.
@MainActor
@Observable
final class AdminLoad<T: Sendable> {
    /// Nil while loading the first time.
    private(set) var result: AdminResult<T>?
    @ObservationIgnored private let load: @MainActor () async -> AdminResult<T>

    init(_ load: @escaping @MainActor () async -> AdminResult<T>) {
        self.load = load
    }

    /// Loads again; `quietly` keeps what's shown until the answer comes, and keeps it if that fails.
    func reload(quietly: Bool = false) async {
        if !quietly { result = nil }
        let next = await load()
        if !quietly || next.value != nil || result?.value == nil { result = next }
    }
}

/// A screen's body for `result`: a spinner while it loads, the content once it's there, the problem with Try again
/// when it isn't, and back to sign-in when the session has ended.
struct AdminContent<T: Sendable, Content: View>: View {
    let result: AdminResult<T>?
    let model: AppModel
    let retry: @MainActor () async -> Void
    @ViewBuilder let content: (T) -> Content

    var body: some View {
        switch result {
        case nil:
            QeetrixSpinner(size: .lg, tone: .brand, label: Text("Loading"))
                .frame(maxWidth: .infinity)
                .padding(.top, QeetrixSpace.layoutMd)
        case .ok(let value)?:
            content(value)
        case .signedOut?:
            Color.clear.onAppear { model.toAdminSignIn() }
        case let problem?:
            QeetrixAlert("Couldn’t do that", description: problem.problem, tone: .danger) {
                QeetrixButton("Try again", size: .sm) { Task { await retry() } }
            }
            .padding(QeetrixSpace.insetLg)
        }
    }
}

extension AppModel {
    /// Back to the start of administration when the session has ended, with Settings behind.
    func toAdminSignIn() { path = [.settings, .adminSignIn] }
    /// Admin home for the chosen organisation, with Settings behind it.
    func toAdminHome() { path = [.settings, .adminHome] }
}

/// A person's or organisation's initials on a 4 pt tile; brand-tinted for an organisation.
struct Initials: View {
    let name: String
    var size: CGFloat = 40
    var brand = false

    var body: some View {
        Text(verbatim: Self.of(name))
            .qeetrixTextStyle(.labelMd)
            .fontWeight(.semibold)
            .foregroundStyle(brand ? QeetrixColor.textBrand : QeetrixColor.textDefault)
            .frame(width: size, height: size)
            .background(
                brand ? QeetrixColor.bgBrandSubtle : QeetrixColor.bgNeutralSubtle, in: RoundedRectangle(cornerRadius: QeetrixRadius.control)
            )
            .accessibilityHidden(true)
    }

    /// "AR" for Arjun Rao, "A" for arjun@….
    static func of(_ name: String) -> String {
        let words = name.split(separator: "@").first.map(String.init) ?? name
        let initials = words.split(whereSeparator: { " ._-".contains($0) }).prefix(2).compactMap { $0.first?.uppercased() }
        return initials.isEmpty ? "?" : initials.joined()
    }

    /// The first word of a name, for "Suspend Kabir".
    static func firstName(_ name: String) -> String {
        let base = name.split(separator: "@").first.map(String.init) ?? name
        return base.split(separator: " ").first.map(String.init) ?? base
    }
}

/// "Recorded in the audit log, with this iPhone named."
struct AuditNote: View {
    var text = Text("Recorded in the audit log, with this iPhone named.")

    var body: some View {
        ResultNote(text: text) { QeetrixIcon(.fileText, size: .sm, shape: .sharp) }
    }
}

/// A label and its value on a ruled row, the label on a fixed column (the request and event details).
struct FactRows: View {
    let rows: [(label: Text, value: Text)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { QeetrixSeparator() }
                HStack(alignment: .firstTextBaseline, spacing: QeetrixSpace.gapMd) {
                    row.label.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle).frame(width: 72, alignment: .leading)
                    row.value.qeetrixTextStyle(.bodyMd).foregroundStyle(QeetrixColor.textDefault)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, QeetrixSpace.insetLg)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
        }
        .background(QeetrixColor.surfaceRaised, in: RoundedRectangle(cornerRadius: QeetrixRadius.surface))
        .overlay {
            RoundedRectangle(cornerRadius: QeetrixRadius.surface)
                .strokeBorder(QeetrixColor.borderDefault, lineWidth: QeetrixBorderWidth.default)
        }
    }
}

// MARK: - Admin sign-in

/// Admin sign-in: what administration on the iPhone is for (a few urgent actions, not the console), then a passkey
/// sign-in, as on the computer. One organisation goes straight to Admin home; more go to Choose organisation.
struct AdminSignInView: View {
    let model: AppModel
    @Environment(\.passkeys) private var passkeys
    @Environment(\.room) private var room
    @State private var isSigningIn = false
    @State private var problem: SignInOutcome?

    var body: some View {
        ScrollView {
            PageColumn(alignment: .center) {
                if let problem {
                    QeetrixAlert(title, description: message(problem), tone: .danger)
                        .padding(.bottom, QeetrixSpace.insetLg)
                        .accessibilityIdentifier("admin.sign-in-problem")
                }
                MarkRings(size: room.isShort ? .xs : .sm) { QeetrixIcon(.shieldCheck, shape: .sharp) }
                PageTitle(
                    title: Text("For administrators, away from the desk"),
                    line: Text(
                        "Approve access, suspend an account in an emergency, and see critical events. Everything else stays in the console."
                    ),
                    centred: true
                )
                .padding(.top, room.isShort ? 12 : 20)
                Panel {
                    Fact("Sign in with your passkey, as on the computer")
                    Fact(Text("\(model.lock.biometry.name) again before anything that changes access"))
                    Fact("Everything you do is in the audit log, with this iPhone named")
                }
                .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
            }
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Administration"))
        .actionFooter(
            primary: QeetrixScreenAction("Sign in", icon: .keyRound, isLoading: isSigningIn) { signIn() },
            tertiary: QeetrixScreenAction("Not now", tone: .neutral) { _ = model.path.popLast() }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.sign-in")
    }

    private var title: LocalizedStringResource {
        switch problem {
        case .passkeyUnavailable: "No passkey for Qeet ID here"
        case .notAnAdministrator: "You don’t administer an organisation"
        default: "Couldn’t sign in"
        }
    }

    private func message(_ outcome: SignInOutcome) -> LocalizedStringResource {
        switch outcome {
        case .passkeyUnavailable:
            "Add a passkey in Qeet ID on the computer (My account, Security, Passkeys), or use one saved in your passwords. This iPhone needs a passcode for passkeys."
        case .notAnAdministrator: "Administration is for people with an administrator role. You were signed out again."
        case .network: "Couldn’t reach Qeet ID. Check your connection and try again."
        default: "Qeet ID didn’t accept it. Try again."
        }
    }

    private func signIn() {
        Task {
            isSigningIn = true
            problem = nil
            defer { isSigningIn = false }
            switch await model.admin.signIn(with: passkeys) {
            case .signedIn(let organizations):
                if organizations.count == 1, case .ok = await model.admin.choose(organizations[0]) {
                    model.toAdminHome()
                } else {
                    model.path = [.settings, .adminOrganizations]
                }
            case .cancelled:
                break
            case let outcome:
                problem = outcome
            }
        }
    }
}

// MARK: - Choose organisation

/// Choose organisation: the ones the person has a role in, each with their role; choosing one scopes the session.
struct AdminOrganizationsView: View {
    let model: AppModel
    @State private var loader: AdminLoad<[Organization]>
    @State private var choosing: String?
    @State private var failure: String?

    init(model: AppModel) {
        self.model = model
        _loader = State(initialValue: AdminLoad { await model.admin.organizations() })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let email = model.admin.summary?.email, !email.isEmpty {
                    QeetrixText("Signed in as \(email)", tone: .subtle)
                        .padding(.horizontal, QeetrixSpace.insetLg)
                        .padding(.bottom, QeetrixSpace.insetLg)
                }
                if let failure {
                    QeetrixAlert("Couldn’t do that", description: failure, tone: .danger)
                        .padding(.horizontal, QeetrixSpace.insetLg)
                        .padding(.bottom, QeetrixSpace.insetLg)
                }
                AdminContent(result: loader.result, model: model, retry: { await loader.reload() }) { organizations in
                    SettingsGroup("You manage") {
                        ForEach(Array(organizations.enumerated()), id: \.element.id) { index, organization in
                            if index > 0 { SettingsRule() }
                            SettingsRow(
                                label: Text(verbatim: organization.name),
                                detail: Text(verbatim: organization.roles.joined(separator: ", ")),
                                accessory: .chevron, action: { choose(organization) }
                            ) {
                                Initials(name: organization.name, brand: true)
                            } end: {
                                if choosing == organization.id { QeetrixSpinner(size: .sm, label: Text("Choosing")) }
                            }
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Choose organisation"))
        .task { await loader.reload() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.organizations")
    }

    private func choose(_ organization: Organization) {
        guard choosing == nil else { return }
        Task {
            choosing = organization.id
            failure = nil
            defer { choosing = nil }
            switch await model.admin.choose(organization) {
            case .ok: model.toAdminHome()
            case .signedOut: model.toAdminSignIn()
            case let problem: failure = problem.problem
            }
        }
    }
}

// MARK: - Admin home

/// What Admin home counts; nil where this administrator may not see it.
struct HomeCounts: Sendable {
    var requests: Int?
    var events: Int?
    var high: Int?
    var agents: Int?
}

/// Admin home: the organisation in the bar with Switch, then only what needs a person now (access requests, critical
/// events) and, apart under their own title, the two emergency actions.
struct AdminHomeView: View {
    let model: AppModel
    @State private var loader: AdminLoad<HomeCounts>

    init(model: AppModel) {
        self.model = model
        _loader = State(initialValue: AdminLoad { await Self.counts(model.admin) })
    }

    var body: some View {
        ScrollView {
            AdminContent(result: loader.result, model: model, retry: { await loader.reload() }) { counts in
                VStack(spacing: 0) {
                    SettingsGroup("Needs you") {
                        SettingsRow(Text("Access requests"), detail: Text("Waiting for an administrator")) {
                            model.path.append(.adminRequests)
                        } end: {
                            if let requests = counts.requests {
                                QeetrixBadge(QeetrixFormat.number(requests), tone: requests > 0 ? .warning : .neutral)
                            }
                        }
                        .accessibilityIdentifier("admin.requests")
                        SettingsRule()
                        SettingsRow(Text("Critical events"), detail: Text("In the last 24 hours")) {
                            model.path.append(.adminEvents)
                        } end: {
                            if let high = counts.high, high > 0 {
                                QeetrixBadge(String(localized: "\(high) high"), tone: .danger)
                            } else if let events = counts.events {
                                QeetrixBadge(QeetrixFormat.number(events), tone: .neutral)
                            }
                        }
                        .accessibilityIdentifier("admin.events")
                    }
                    SettingsGroup("Emergency") {
                        SettingsRow(Text("Suspend a person"), detail: Text("Signs them out everywhere and stops sign-in")) {
                            model.path.append(.adminPeople)
                        }
                        .accessibilityIdentifier("admin.suspend")
                        SettingsRule()
                        SettingsRow(
                            Text("Stop all AI agents"), detail: counts.agents.map { Text("\($0) running in this organisation") },
                            danger: true
                        ) {
                            model.path.append(.adminAgents)
                        }
                        .accessibilityIdentifier("admin.agents")
                    }
                    SettingsGroup("Your session") {
                        SettingsRow(
                            Text("Sign out of administration"), detail: model.admin.summary.map { Text("Signed in as \($0.email)") },
                            danger: true
                        ) {
                            Task {
                                await model.admin.signOut()
                                model.path = [.settings]
                            }
                        }
                        .accessibilityIdentifier("admin.sign-out")
                    }
                }
            }
            .padding(.top, 20)
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(
            Text(verbatim: model.admin.summary?.organizationName ?? String(localized: "Administration")), subtitle: Text("Administration")
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.path.append(.adminOrganizations)
                } label: {
                    Label {
                        Text("Switch organisation")
                    } icon: {
                        Image(qeetrix: .arrowLeftRight, shape: .sharp)
                    }
                }
                .accessibilityIdentifier("admin.switch")
            }
        }
        .task { await loader.reload(quietly: loader.result != nil) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.home")
    }

    static func counts(_ admin: AdminSession) async -> AdminResult<HomeCounts> {
        let api = admin.api
        async let requests = admin.inOrganization { access, tenant in await api.accessRequests(access, tenant: tenant) }
        async let events = admin.inOrganization { access, tenant in await api.criticalEvents(access, tenant: tenant) }
        async let agents = admin.inOrganization { access, tenant in await api.runningAgents(access, tenant: tenant) }
        let (r, e, a) = await (requests, events, agents)
        if r.isSignedOut || e.isSignedOut || a.isSignedOut { return .signedOut }
        if case .network = r, case .network = e { return .network }
        return .ok(HomeCounts(requests: r.value?.pending, events: e.value?.events.count, high: e.value?.high, agents: a.value))
    }
}
