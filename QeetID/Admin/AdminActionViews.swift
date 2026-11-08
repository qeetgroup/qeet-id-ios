import Qeetrix
import SwiftUI

/// How long access lasts: "For 8 hours", "For 7 days", "Until it’s taken away".
func durationText(_ hours: Int?) -> Text {
    guard let hours else { return Text("Until it’s taken away") }
    if hours < 24 || hours % 24 != 0 { return Text("For \(hours) hours") }
    return Text("For \(hours / 24) days")
}

/// When something happened, relative: "2 hr ago".
func ago(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Access requests

/// Access requests: the ones waiting for an administrator, newest first, each with who, what, for how long and when.
struct AdminRequestsView: View {
    let model: AppModel
    @State private var loader: AdminLoad<AccessRequestPage>

    init(model: AppModel) {
        self.model = model
        let api = model.admin.api
        _loader = State(initialValue: AdminLoad { await model.admin.inOrganization { await api.accessRequests($0, tenant: $1) } })
    }

    var body: some View {
        let waiting = (loader.result?.value?.accessRequests ?? []).filter(\.isPending).sorted { $0.createdAt > $1.createdAt }
        ScrollView {
            AdminContent(result: loader.result, model: model, retry: { await loader.reload() }) { _ in
                if waiting.isEmpty {
                    QeetrixEmptyState(
                        "Nothing waiting", description: "New access requests show here, and come to this iPhone as a notification.",
                        icon: .circleCheck, size: .section, tone: .success)
                } else {
                    SettingsGroup("Waiting") {
                        ForEach(Array(waiting.enumerated()), id: \.element.id) { index, request in
                            if index > 0 { SettingsRule() }
                            SettingsRow(
                                label: Text(verbatim: request.requester.shown),
                                detail: Text(verbatim: request.role.name) + Text(verbatim: " · ") + durationText(request.durationHours),
                                value: Text(verbatim: ago(request.createdAt)), accessory: .chevron,
                                action: { model.path.append(.adminRequest(request.id)) }
                            ) {
                                Initials(name: request.requester.shown)
                            } end: {
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Access requests"), subtitle: loader.result?.value.map { _ in Text("\(waiting.count) waiting") })
        .task { await loader.reload(quietly: loader.result != nil) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.request-list")
    }
}

/// One access request in full (who, what it gives, for how long, why), then Approve after a fresh passkey check (the
/// iPhone asks for Face ID), or Deny with a reason they will see. Every decision is in the audit log.
struct AdminRequestView: View {
    let model: AppModel
    let id: String
    @Environment(\.passkeys) private var passkeys
    @Environment(\.room) private var room
    @State private var loader: AdminLoad<AccessRequest>
    @State private var approved: AccessRequest?
    @State private var showsDeny = false
    @State private var reason = ""
    @State private var isBusy = false
    @State private var problem: String?

    init(model: AppModel, id: String) {
        self.model = model
        self.id = id
        let api = model.admin.api
        _loader = State(initialValue: AdminLoad { await model.admin.inOrganization { await api.accessRequest($0, tenant: $1, id: id) } })
    }

    var body: some View {
        if let approved {
            ResultScreen(title: Text("Access given"), line: approvedLine(approved), sealTone: .success) {
                QeetrixIcon(.check, size: .md, stroke: QeetrixIconStroke(2.5), shape: .sharp)
            } content: {
                AuditNote()
            }
            .actionFooter(primary: QeetrixScreenAction("Done") { _ = model.path.popLast() })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("admin.access-given")
        } else {
            review
        }
    }

    private var review: some View {
        let request = loader.result?.value
        return ScrollView {
            PageColumn {
                if let problem {
                    QeetrixAlert("Couldn’t do that", description: problem, tone: .danger)
                        .padding(.bottom, QeetrixSpace.insetLg)
                }
                AdminContent(result: loader.result, model: model, retry: { await loader.reload() }) { request in
                    VStack(alignment: .leading, spacing: 0) {
                        if !request.isPending {
                            QeetrixAlert("This request has already been decided.").padding(.bottom, QeetrixSpace.insetLg)
                        }
                        PersonHeader(
                            title: Text(verbatim: request.requester.shown),
                            line: request.requester.name == nil ? nil : request.requester.email)
                        GroupLabel("Asks for")
                            .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                            .padding(.bottom, QeetrixSpace.gapSm)
                        FactRows(
                            rows: [
                                (Text("Access"), Text(verbatim: request.role.name)),
                                (Text("For"), durationText(request.durationHours)),
                            ]
                                + (request.role.description.flatMap { $0.isEmpty ? nil : $0 }.map { [(Text("Gives"), Text(verbatim: $0))] }
                                    ?? [])
                                + [(Text("Asked"), Text(verbatim: ago(request.createdAt)))])
                        if let why = request.reason, !why.isEmpty {
                            GroupLabel("Their reason")
                                .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                                .padding(.bottom, QeetrixSpace.gapSm)
                            HStack(spacing: 12) {
                                Rectangle().fill(QeetrixColor.borderBrand).frame(width: 3)
                                QeetrixText(Text(verbatim: why))
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Access request"))
        .actionFooter(
            primary: request.map { request in
                request.isPending
                    ? QeetrixScreenAction("Approve", isLoading: isBusy) { approve(request) }
                    : QeetrixScreenAction("Done") { _ = model.path.popLast() }
            },
            tertiary: request?.isPending == true
                ? QeetrixScreenAction("Deny", tone: .neutral, isDisabled: isBusy) { showsDeny = true } : nil
        )
        .qeetrixSheet(isPresented: $showsDeny, detents: [.medium]) {
            if let request {
                QeetrixSheetContent(
                    "Deny this request?", description: Text("\(Initials.firstName(request.requester.shown)) will see your reason"),
                    onClose: { showsDeny = false }
                ) {
                    VStack(spacing: QeetrixSpace.gapLg) {
                        QeetrixTextField("Reason", text: $reason)
                            .accessibilityIdentifier("admin.deny-reason")
                        QeetrixButton("Deny request", tone: .danger, size: .lg, isLoading: isBusy, isFullWidth: true) { deny(request) }
                            .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityIdentifier("admin.deny")
                    }
                } actions: {
                    EmptyView()
                }
            }
        }
        .task { await loader.reload() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.request")
    }

    private func approvedLine(_ request: AccessRequest) -> Text {
        if let ends = request.accessEndsAt {
            return Text(
                "\(request.requester.shown) is \(request.role.name) until \(QeetrixFormat.date(ends, style: .long)). It ends by itself.")
        }
        return Text("\(request.requester.shown) now has \(request.role.name).")
    }

    private func approve(_ request: AccessRequest) {
        Task {
            isBusy = true
            problem = nil
            defer { isBusy = false }
            // The passkey check is the iPhone asking first: the person's own Face ID.
            switch await model.admin.stepUp(with: passkeys) {
            case .done:
                let api = model.admin.api
                let result = await model.admin.inOrganization { await api.approve($0, tenant: $1, id: request.id, note: "") }
                switch result {
                case .ok(let decided): approved = decided
                case .signedOut: model.toAdminSignIn()
                case let failure: problem = failure.problem
                }
            case .cancelled: break
            case .signedOut: model.toAdminSignIn()
            default: problem = String(localized: "Your passkey couldn’t be checked, so nothing changed. Try again.")
            }
        }
    }

    private func deny(_ request: AccessRequest) {
        Task {
            isBusy = true
            defer { isBusy = false }
            let api = model.admin.api
            let note = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            switch await model.admin.inOrganization({ await api.deny($0, tenant: $1, id: request.id, note: note) }) {
            case .ok:
                showsDeny = false
                _ = model.path.popLast()
            case .signedOut:
                showsDeny = false
                model.toAdminSignIn()
            case let failure:
                showsDeny = false
                problem = failure.problem
            }
        }
    }
}

/// A person's initials, name and a line under it (their email).
struct PersonHeader: View {
    let title: Text
    var line: String?

    var body: some View {
        HStack(spacing: QeetrixSpace.gapMd) {
            Initials(name: line ?? "", size: 48)
            VStack(alignment: .leading, spacing: 2) {
                title.qeetrixTextStyle(.labelMd).font(QeetrixTextMetrics(role: .bodyLg).font).fontWeight(.semibold)
                    .foregroundStyle(QeetrixColor.textDefault)
                if let line { Text(verbatim: line).qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Find a person, suspend

/// Find a person: search by name or email; before typing, the people in recent critical events come first.
struct AdminPeopleView: View {
    let model: AppModel
    @State private var query = ""
    @State private var result: AdminResult<(recent: [Member], others: [Member], searching: Bool)>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: QeetrixSpace.gapSm) {
                    QeetrixSearchField(text: $query, prompt: Text("Name or email")) { search($0) }
                        .accessibilityIdentifier("admin.people-search")
                    QeetrixText(
                        "Suspending signs them out everywhere and stops them signing in, until it’s undone.", size: .sm, tone: .subtle)
                }
                .padding(.horizontal, QeetrixSpace.insetLg)
                .padding(.bottom, 20)
                AdminContent(result: result, model: model, retry: { await load(query) }) { people in
                    if people.searching && people.others.isEmpty {
                        QeetrixEmptyState(
                            "Nobody matches", description: "Check the spelling, or search by email.", icon: .searchX, size: .section)
                    } else if people.searching {
                        group("Results", people.others)
                    } else {
                        if !people.recent.isEmpty { group("In recent events", people.recent) }
                        if !people.others.isEmpty { group("Everyone", people.others) }
                    }
                }
            }
            .padding(.top, QeetrixSpace.insetLg)
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Suspend a person"))
        .task { if result == nil { await load("") } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.people")
    }

    private func group(_ title: LocalizedStringResource, _ members: [Member]) -> some View {
        SettingsGroup(title) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                if index > 0 { SettingsRule() }
                SettingsRow(
                    label: Text(verbatim: member.name), detail: member.email == member.name ? nil : Text(verbatim: member.email),
                    accessory: .chevron, action: { model.path.append(.adminSuspend(member.id)) }
                ) {
                    Initials(name: member.name)
                } end: {
                    EmptyView()
                }
            }
        }
    }

    private func search(_ text: String) {
        Task { await load(text) }
    }

    private func load(_ text: String) async {
        let admin = model.admin
        let api = admin.api
        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            result = await admin.inOrganization { access, _ in await api.members(access, query: text) }.map {
                (recent: [], others: $0, searching: true)
            }
            return
        }
        let all = await admin.inOrganization { access, _ in await api.members(access, query: "") }
        guard case .ok(let everyone) = all else {
            result = all.map { _ in (recent: [], others: [], searching: false) }
            return
        }
        // The people the last day's critical events are about: the ones an on-call person looks for first.
        let events = await admin.inOrganization { await api.criticalEvents($0, tenant: $1) }.value?.events ?? []
        var seen = Set<String>()
        let ids = events.compactMap(\.personId).filter { seen.insert($0).inserted }.prefix(5)
        var recent: [Member] = []
        for id in ids {
            if let known = everyone.first(where: { $0.id == id }) {
                recent.append(known)
            } else if let member = await admin.inOrganization({ access, _ in await api.member(access, id: id) }).value {
                recent.append(member)
            }
        }
        recent = recent.filter { !$0.isSuspended }
        let recentIds = Set(recent.map(\.id))
        result = .ok((recent: recent, others: everyone.filter { !recentIds.contains($0.id) && !$0.isSuspended }, searching: false))
    }
}

/// Suspend a person: what happens and what doesn't, why (for the audit log), and the iPhone's own check first, every
/// time. Suspended shows Reactivate right there, for a mistake; reactivating asks for a fresh passkey check.
struct AdminSuspendView: View {
    let model: AppModel
    let userId: String
    @Environment(\.passkeys) private var passkeys
    @Environment(\.room) private var room
    @State private var loader: AdminLoad<Member>
    @State private var reason: SuspendReason?
    @State private var suspended: Bool?
    @State private var reactivated = false
    @State private var isBusy = false
    @State private var problem: String?

    init(model: AppModel, userId: String) {
        self.model = model
        self.userId = userId
        let api = model.admin.api
        _loader = State(initialValue: AdminLoad { await model.admin.inOrganization { access, _ in await api.member(access, id: userId) } })
    }

    var body: some View {
        let member = loader.result?.value
        if let member, suspended ?? member.isSuspended {
            ResultScreen(
                title: Text("\(member.name) is suspended"), line: Text("Signed out everywhere. Reactivate when it’s safe."),
                sealTone: .danger
            ) {
                QeetrixIcon(.lock, size: .md, shape: .sharp)
            } content: {
                if let problem { QeetrixAlert("Couldn’t do that", description: problem, tone: .danger) }
                AuditNote(text: Text("Recorded in the audit log, with your reason."))
            }
            .actionFooter(
                primary: QeetrixScreenAction("Done") { _ = model.path.popLast() },
                tertiary: QeetrixScreenAction("Reactivate", tone: .neutral, isLoading: isBusy) { reactivate(member) }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("admin.suspended")
        } else {
            decide(member)
        }
    }

    private func decide(_ member: Member?) -> some View {
        ScrollView {
            PageColumn {
                if reactivated, let member {
                    QeetrixAlert(LocalizedStringResource("\(member.name) can sign in again"), tone: .success)
                        .padding(.bottom, QeetrixSpace.insetLg)
                }
                if let problem {
                    QeetrixAlert("Couldn’t do that", description: problem, tone: .danger).padding(.bottom, QeetrixSpace.insetLg)
                }
                AdminContent(result: loader.result, model: model, retry: { await loader.reload() }) { member in
                    VStack(alignment: .leading, spacing: 0) {
                        PersonHeader(title: Text("Suspend \(member.name)?"), line: member.email)
                        Panel {
                            Fact("Signed out everywhere, at once", stops: true)
                            Fact("Can’t sign in until reactivated", stops: true)
                            Fact("Nothing is deleted; reactivate any time")
                        }
                        .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                        QeetrixRadioGroup(
                            "Reason", selection: $reason,
                            options: SuspendReason.allCases.map { QeetrixOption(title: Text(verbatim: $0.label), value: Optional($0)) },
                            description: Text("In the audit log, with this iPhone named")
                        )
                        .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                        .accessibilityIdentifier("admin.suspend-reason")
                    }
                }
            }
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Suspend a person"))
        .actionFooter(
            primary: member.map { member in
                QeetrixScreenAction(
                    title: Text("Suspend \(Initials.firstName(member.name))"), tone: .danger, isLoading: isBusy, isDisabled: reason == nil
                ) { suspend(member) }
            }
        )
        .task { if loader.result == nil { await loader.reload() } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.suspend-person")
    }

    private func suspend(_ member: Member) {
        guard let reason else { return }
        Task {
            isBusy = true
            problem = nil
            defer { isBusy = false }
            // Always the iPhone's own check first, even with the app open and unlocked.
            switch await model.lock.authenticate(reason: reason.label) {
            case .success:
                let api = model.admin.api
                switch await model.admin.inOrganization({ access, _ in await api.suspend(access, id: member.id) }) {
                case .ok:
                    _ = await model.admin.inOrganization { access, _ in await api.recordSuspension(access, id: member.id, reason: reason) }
                    suspended = true
                    reactivated = false
                case .signedOut: model.toAdminSignIn()
                case let failure: problem = failure.problem
                }
            case .cancelled: break
            case .passcodeNotSet:
                problem = String(localized: "Set a passcode on this iPhone first: it’s asked before every emergency action.")
            case .failed: problem = String(localized: "Couldn’t confirm it’s you, so nothing changed. Try again.")
            }
        }
    }

    private func reactivate(_ member: Member) {
        Task {
            isBusy = true
            problem = nil
            defer { isBusy = false }
            switch await model.admin.stepUp(with: passkeys) {
            case .done:
                let api = model.admin.api
                switch await model.admin.inOrganization({ access, _ in await api.reactivate(access, id: member.id) }) {
                case .ok, .conflict:
                    suspended = false
                    reactivated = true
                case .signedOut: model.toAdminSignIn()
                case let failure: problem = failure.problem
                }
            case .cancelled: break
            case .signedOut: model.toAdminSignIn()
            default: problem = String(localized: "Your passkey couldn’t be checked, so nothing changed. Try again.")
            }
        }
    }
}

// MARK: - Stop all AI agents

/// Stop all AI agents: the organisation's kill switch, for an agent misbehaving with no time to find which. What stops
/// (every agent's tokens, at once) and what doesn't (people), red, alone on its screen and behind the iPhone's check.
struct AdminAgentsView: View {
    let model: AppModel
    @Environment(\.room) private var room
    @State private var loader: AdminLoad<Int>
    @State private var stopped: Int?
    @State private var isBusy = false
    @State private var problem: String?

    init(model: AppModel) {
        self.model = model
        let api = model.admin.api
        _loader = State(initialValue: AdminLoad { await model.admin.inOrganization { await api.runningAgents($0, tenant: $1) } })
    }

    var body: some View {
        let organization = model.admin.summary?.organizationName ?? ""
        if let stopped {
            ResultScreen(
                title: Text("Every agent stopped"), line: Text("\(stopped) agents can’t act until they’re resumed in the console."),
                sealTone: .danger
            ) {
                QeetrixIcon(.botOff, size: .md, shape: .sharp)
            } content: {
                AuditNote()
            }
            .actionFooter(primary: QeetrixScreenAction("Done") { _ = model.path.popLast() })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("admin.agents-stopped")
        } else {
            let running = loader.result?.value
            ScrollView {
                PageColumn(alignment: .center) {
                    if let problem {
                        QeetrixAlert("Couldn’t do that", description: problem, tone: .danger).padding(.bottom, QeetrixSpace.insetLg)
                    }
                    AdminContent(result: loader.result, model: model, retry: { await loader.reload() }) { count in
                        VStack(spacing: 0) {
                            MarkRings(size: room.isShort ? .xs : .sm, sealTone: .danger) { QeetrixIcon(.botOff, shape: .sharp) }
                            if count == 0 {
                                PageTitle(
                                    title: Text("No AI agents running"), line: Text("Nothing to stop in this organisation right now."),
                                    centred: true
                                )
                                .padding(.top, room.isShort ? 12 : 20)
                            } else {
                                PageTitle(title: Text("Stop every AI agent in \(organization)?"), centred: true)
                                    .padding(.top, room.isShort ? 12 : 20)
                                Panel {
                                    Fact(Text("All \(count) stop at once: their tokens are refused"), stops: true)
                                    Fact("People aren’t affected")
                                    Fact("Each one comes back only when resumed in the console")
                                }
                                .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                            }
                        }
                    }
                }
            }
            .background(QeetrixColor.surfaceCanvas)
            .screenBar(Text("Stop all AI agents"))
            .actionFooter(
                primary: running.map { count in
                    count == 0
                        ? QeetrixScreenAction("Done") { _ = model.path.popLast() }
                        : QeetrixScreenAction(title: Text("Stop all \(count) agents"), tone: .danger, isLoading: isBusy) {
                            stop(count, in: organization)
                        }
                }
            )
            .task { if loader.result == nil { await loader.reload() } }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("admin.agents-stop")
        }
    }

    private func stop(_ count: Int, in organization: String) {
        Task {
            isBusy = true
            problem = nil
            defer { isBusy = false }
            switch await model.lock.authenticate(reason: String(localized: "\(count) agents in \(organization)")) {
            case .success:
                let api = model.admin.api
                switch await model.admin.inOrganization({ await api.stopAllAgents($0, tenant: $1) }) {
                case .ok(let suspended): stopped = suspended
                case .signedOut: model.toAdminSignIn()
                case let failure: problem = failure.problem
                }
            case .cancelled: break
            case .passcodeNotSet:
                problem = String(localized: "Set a passcode on this iPhone first: it’s asked before every emergency action.")
            case .failed: problem = String(localized: "Couldn’t confirm it’s you, so nothing changed. Try again.")
            }
        }
    }
}

// MARK: - Critical events

/// What happened, in words.
func eventTitle(_ event: CriticalEvent) -> Text {
    if event.isAnomaly { return Text("Unusual activity") }
    switch event.action {
    case "agent.kill_switch": return Text("Every AI agent stopped")
    case "user.suspended": return Text("Person suspended")
    case "tenant.suspended": return Text("Organisation suspended")
    case "auth.account_locked": return Text("Account locked after failed sign-ins")
    case "auth.mfa_locked": return Text("Second step locked after failed tries")
    case "mfa.admin_reset": return Text("Second step reset by an administrator")
    case "session.admin_revoked_all": return Text("Signed out everywhere by an administrator")
    case "role.assigned": return Text("Role given")
    case "user.reactivated": return Text("Person reactivated")
    case "mfa.totp_disabled": return Text("Authenticator app turned off")
    case "risk.settings_updated": return Text("Risk settings changed")
    default: return Text(verbatim: event.action ?? "")
    }
}

private struct LevelBadge: View {
    let event: CriticalEvent

    var body: some View {
        if event.isHigh {
            QeetrixBadge("High", tone: .danger)
        } else {
            QeetrixBadge("Medium", tone: .warning)
        }
    }
}

/// Critical events: the last day's high and medium events, newest first, read only.
struct AdminEventsView: View {
    let model: AppModel
    @State private var loader: AdminLoad<CriticalEventPage>

    init(model: AppModel) {
        self.model = model
        let api = model.admin.api
        _loader = State(initialValue: AdminLoad { await model.admin.inOrganization { await api.criticalEvents($0, tenant: $1) } })
    }

    var body: some View {
        ScrollView {
            AdminContent(result: loader.result, model: model, retry: { await loader.reload() }) { page in
                if page.events.isEmpty {
                    QeetrixEmptyState(
                        "No critical events", description: "Nothing high or medium in the last 24 hours.", icon: .circleCheck,
                        size: .section, tone: .success)
                } else {
                    SettingsGroup("Newest first") {
                        let events = page.events.sorted { $0.occurredAt > $1.occurredAt }
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            if index > 0 { SettingsRule() }
                            SettingsRow(
                                label: eventTitle(event),
                                detail: Text(
                                    verbatim: [event.actorEmail, ago(event.occurredAt)].compactMap { $0 }.joined(separator: " · ")),
                                accessory: .chevron, action: { model.path.append(.adminEvent(event.id)) }
                            ) {
                                LevelBadge(event: event)
                            } end: {
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Critical events"), subtitle: Text("Last 24 hours"))
        .task { await loader.reload(quietly: loader.result != nil) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.event-list")
    }
}

/// One critical event, read only: who, where, when, then the two next steps: open it in the console, or suspend the
/// person.
struct AdminEventView: View {
    let model: AppModel
    let id: String
    @Environment(\.openURL) private var openURL
    @Environment(\.room) private var room
    @State private var loader: AdminLoad<CriticalEvent>

    init(model: AppModel, id: String) {
        self.model = model
        self.id = id
        let api = model.admin.api
        _loader = State(
            initialValue: AdminLoad {
                await model.admin.inOrganization { await api.criticalEvents($0, tenant: $1) }.then { page in
                    page.events.first { $0.id == id }.map { .ok($0) } ?? .notFound
                }
            })
    }

    var body: some View {
        let event = loader.result?.value
        ScrollView {
            PageColumn {
                AdminContent(result: loader.result, model: model, retry: { await loader.reload() }) { event in
                    VStack(alignment: .leading, spacing: 0) {
                        LevelBadge(event: event)
                        QeetrixHeading(eventTitle(event), level: 1, size: room.isShort ? .headingSm : .headingMd)
                            .padding(.top, QeetrixSpace.gapSm)
                        FactRows(
                            rows: [
                                event.actorEmail.map { (Text("Person"), Text(verbatim: $0)) },
                                event.ip.map { (Text("Where"), Text(verbatim: $0)) },
                            ]
                            .compactMap { $0 }
                                + [
                                    (
                                        Text("When"),
                                        Text(
                                            verbatim: QeetrixFormat.date(event.occurredAt, style: .medium) + ", "
                                                + QeetrixFormat.time(event.occurredAt))
                                    )
                                ]
                        )
                        .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                    }
                }
            }
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Critical event"))
        .actionFooter(
            primary: event.map { event in QeetrixScreenAction("Open in the console") { openURL(consoleURL(event)) } },
            tertiary: event.flatMap { event in
                guard let person = event.personId, let email = event.actorEmail else { return nil }
                return QeetrixScreenAction(title: Text("Suspend \(Initials.firstName(email))"), tone: .neutral) {
                    model.path.append(.adminSuspend(person))
                }
            }
        )
        .task { await loader.reload() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.event")
    }

    /// The same event in the console, beside the API: api.id.qeet.in → console.id.qeet.in.
    private func consoleURL(_ event: CriticalEvent) -> URL {
        let base = APIEnvironment.baseURL
        let host = base.host() ?? "api.id.qeet.in"
        let console = host.hasPrefix("api.") ? "console." + host.dropFirst(4) : "console.id.qeet.in"
        let path = event.isAnomaly ? "/security/threats/anomalies" : "/security/audit-logs?event=\(event.id)"
        return URL(string: "\(base.scheme ?? "https")://\(console)\(path)")!
    }
}
