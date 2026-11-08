import Qeetrix
import SwiftUI

/// Requests waiting: more than one sign-in waiting for this iPhone. An alert says what it can mean (red when there are
/// lots: someone may be trying to wear the person down into approving one), each request's what, where, when and time
/// left, and Deny all as the main action.
struct RequestsWaitingView: View {
    let model: AppModel
    @State private var requests: [FetchedChallenge]?
    @State private var isDenying = false
    @State private var deniedAll = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            if deniedAll {
                DeniedResult(title: Text("Sign-ins denied"), onDone: { model.modal = nil }) { EmptyView() }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("requests.denied")
            } else {
                list
            }
        }
        .task { await load() }
    }

    private var list: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let open = (requests ?? []).filter { $0.isOpen(at: context.date) }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if requests == nil {
                        QeetrixSpinner(size: .lg, tone: .brand, label: Text("Loading the requests"))
                            .frame(maxWidth: .infinity)
                            .padding(.top, QeetrixSpace.layoutMd)
                    } else {
                        VStack(spacing: QeetrixSpace.gapMd) {
                            if failed {
                                QeetrixAlert(
                                    "Some requests couldn’t be denied", description: "Check your connection and try again.", tone: .danger)
                            }
                            if open.count >= 3 {
                                QeetrixAlert(
                                    "Lots of requests at once",
                                    description:
                                        "Someone may be trying to get you to approve one. Deny them all, then change your password.",
                                    tone: .danger)
                            } else if open.count == 2 {
                                QeetrixAlert(
                                    "More than one sign-in is waiting",
                                    description:
                                        "If you started only one, someone else may know your password. Deny the one you don’t recognise.",
                                    tone: .warning)
                            }
                        }
                        .padding(QeetrixSpace.insetLg)
                        VStack(spacing: 0) {
                            ForEach(Array(open.enumerated()), id: \.element.challenge.id) { index, fetched in
                                if index > 0 { QeetrixSeparator() }
                                WaitingRow(fetched: fetched, now: context.date) { model.openFromWaiting(fetched) }
                            }
                        }
                        .background(QeetrixColor.surfaceRaised)
                        .overlay(alignment: .top) { QeetrixSeparator(tone: .default) }
                        .overlay(alignment: .bottom) { QeetrixSeparator(tone: .default) }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text("Waiting requests"))
                    }
                }
            }
            .background(QeetrixColor.surfaceCanvas)
            .screenBar(Text("Sign-in requests"), subtitle: requests == nil ? nil : Text("\(open.count) waiting"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { model.modal = nil }
                        .accessibilityIdentifier("requests.close")
                }
            }
            .actionFooter(
                primary: QeetrixScreenAction("Deny all", tone: .danger, isLoading: isDenying, isDisabled: open.isEmpty) {
                    Task { await denyAll(open) }
                }
            )
            .onChange(of: open.isEmpty) { _, isEmpty in
                if isEmpty && requests != nil && !isDenying { model.modal = nil }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("requests.waiting")
        }
    }

    private func load() async {
        requests = await model.link.pendingRequests()
    }

    /// Denies every waiting request; a request that ended meanwhile needs no answer.
    private func denyAll(_ open: [FetchedChallenge]) async {
        isDenying = true
        failed = false
        var anyFailed = false
        for fetched in open {
            do throws(APIError) {
                try await model.link.respond(to: fetched.challenge.id, approved: false, number: nil)
            } catch {
                switch error {
                case .challengeExpired, .challengeAnswered, .notFound, .numberMismatch: break
                default: anyFailed = true
                }
            }
        }
        isDenying = false
        if anyFailed {
            failed = true
            await load()
        } else {
            QeetrixFeedback.warning.play()
            deniedAll = true
        }
    }
}

/// One waiting request: what's signing in, from where and when, and its time left.
private struct WaitingRow: View {
    let fetched: FetchedChallenge
    let now: Date
    let action: @MainActor () -> Void

    var body: some View {
        let context = fetched.challenge.context
        let place = context.location.flatMap { $0.isEmpty ? nil : $0 }
        let time = QeetrixFormat.time(fetched.challenge.signedInAt)
        let seconds = max(0, Int(fetched.expiresAtLocal.timeIntervalSince(now).rounded(.up)))
        Button(action: action) {
            HStack(spacing: QeetrixSpace.gapMd) {
                deviceIcon(context.userAgent)
                    .foregroundStyle(QeetrixColor.iconSubtle)
                    .frame(width: 40, height: 40)
                    .background(QeetrixColor.bgNeutralSubtle, in: RoundedRectangle(cornerRadius: QeetrixRadius.control))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: context.browser ?? String(localized: "A browser"))
                        .qeetrixTextStyle(.labelMd).fontWeight(.semibold).foregroundStyle(QeetrixColor.textDefault)
                        .lineLimit(1)
                    Group {
                        if let place { Text("Near \(place) · \(time)") } else { Text(verbatim: time) }
                    }
                    .qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(SignInRequestView.clock(seconds)) left")
                    .qeetrixTextStyle(.bodySm).monospacedDigit().foregroundStyle(QeetrixColor.textSubtle)
                QeetrixIcon(.chevronRight, size: .sm, shape: .sharp).foregroundStyle(QeetrixColor.iconSubtle)
            }
            .padding(.horizontal, QeetrixSpace.insetLg)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.qeetrixListItem())
        .accessibilityIdentifier("requests.row")
    }

    /// A laptop for a Mac or Chromebook, a phone for a phone or tablet, a monitor otherwise.
    @ViewBuilder private func deviceIcon(_ userAgent: String?) -> some View {
        let agent = userAgent ?? ""
        if agent.contains("iPhone") || agent.contains("iPad") || agent.contains("Android") {
            QeetrixIcon(.smartphone, size: .md, shape: .sharp)
        } else if agent.contains("Macintosh") || agent.contains("CrOS") {
            AppIcon(.laptop)
        } else {
            AppIcon(.monitor)
        }
    }
}
