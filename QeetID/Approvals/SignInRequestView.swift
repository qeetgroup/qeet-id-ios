import Qeetrix
import SwiftUI

/// Screens 16 to 20: review a sign-in and type the number from the sign-in screen, Face ID, then the outcome.
struct SignInRequestView: View {
    @State var model: SignInRequestModel
    let onClose: @MainActor () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Sign-in request")
                .navigationBarTitleDisplayMode(.inline)
                .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
                .toolbar { toolbar }
        }
        .task { await model.load() }
        .qeetrixAlertDialog(Binding(get: { model.alert }, set: { model.alert = $0 }))
        .qeetrixFeedback(trigger: model.phase) { _, phase in
            guard case .outcome(let outcome) = phase else { return nil }
            switch outcome {
            case .approved: return .success
            case .denied: return .warning
            case .ended: return .error
            }
        }
        .accessibilityIdentifier("sign-in-request")
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            QeetrixSpinner(size: .lg, tone: .brand, label: Text("Loading the request"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(QeetrixColor.surfaceCanvas)
        case .review(let fetched):
            ReviewView(model: model, fetched: fetched)
        case .outcome(let outcome):
            outcomeView(outcome)
        case .failedToLoad(let error):
            ScrollView {
                QeetrixEmptyState(
                    title: Text("Couldn't load the request"), description: Text(error.connectionMessage), icon: .circleAlert,
                    tone: .danger, level: 1
                ) {
                    QeetrixButton("Try again", icon: .refreshCw) { Task { await model.load() } }
                        .accessibilityIdentifier("request.retry")
                }
                .containerRelativeFrame(.vertical, alignment: .center)
            }
            .background(QeetrixColor.surfaceCanvas)
            .accessibilityIdentifier("request.load-error")
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if !model.phase.isOutcome {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
                    .accessibilityIdentifier("request.close")
            }
        }
        if case .review = model.phase {
            ToolbarItem(placement: .primaryAction) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = model.secondsLeft(at: context.date)
                    QeetrixBadge(
                        Self.clock(seconds), tone: seconds <= 30 ? .warning : .neutral, icon: .clock
                    )
                    .accessibilityLabel(Text("\(seconds) seconds left to answer"))
                    .onChange(of: seconds) { _, left in if left == 0 { model.expireIfDue() } }
                }
            }
        }
    }

    @ViewBuilder private func outcomeView(_ outcome: SignInRequestModel.Outcome) -> some View {
        switch outcome {
        case .approved(let browser):
            OutcomeView(
                icon: .circleCheck, iconColor: .iconSuccess, title: Text("Sign-in approved"),
                message: browser.map { Text("Go back to your computer. \($0) is signing in to Qeet ID.") }
                    ?? Text("Go back to your computer. It's signing in to Qeet ID.")
            )
            .qeetrixBottomActionBar(primary: QeetrixScreenAction("Done", icon: .check) { onClose() })
            .accessibilityIdentifier("request.approved")
        case .denied:
            OutcomeView(
                icon: .circleX, iconColor: .iconDanger, title: Text("Sign-in blocked"),
                message: Text("Nobody got in. But whoever tried has your password.")
            ) {
                QeetrixAlert(
                    "Change your Qeet ID password", description: "Use one you don't use anywhere else.", tone: .warning
                ) {
                    QeetrixButton("Open security", size: .sm) { openURL(QeetIDLinks.accountSecurity) }
                }
            }
            .actionFooter(tertiary: FooterAction("Done") { onClose() })
            .accessibilityIdentifier("request.denied")
        case .ended(let reason):
            OutcomeView(icon: .clock, iconColor: .iconSubtle, title: Text("This request has ended"), message: Self.message(reason)) {
                if reason == .notLinked {
                    QeetrixText("Link this iPhone again from Settings to approve sign-ins.", size: .sm, tone: .subtle, align: .center)
                } else {
                    QeetrixText(
                        "Was it you? Start signing in again on your computer; a new request will come here.", size: .sm, tone: .subtle,
                        align: .center)
                }
            }
            .qeetrixBottomActionBar(primary: QeetrixScreenAction("Done", icon: .check) { onClose() })
            .accessibilityIdentifier("request.ended")
        }
    }

    static func message(_ reason: SignInRequestModel.EndReason) -> Text {
        switch reason {
        case .numberMismatch: Text("The number didn't match, so the sign-in was refused. Nothing was approved.")
        case .expired: Text("Two minutes passed without an answer, so it expired. Nothing was approved.")
        case .answered: Text("It was already answered. Nothing more to do here.")
        case .notFound: Text("Qeet ID no longer has this request. Nothing was approved.")
        case .notLinked: Text("This iPhone can't answer for that account any more. Nothing was approved.")
        }
    }

    /// "1:46".
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Screen 16: where and what, then the number on the iPhone number pad, then Deny or Approve.
private struct ReviewView: View {
    let model: SignInRequestModel
    let fetched: FetchedChallenge

    var body: some View {
        let context = fetched.challenge.context
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.layoutSm) {
                QeetrixHeading("Are you signing in to Qeet ID?", level: 1, size: .titleLg)
                QeetrixCard {
                    QeetrixDescriptionList(layout: .columns, columns: 2) {
                        QeetrixDescriptionItem("Browser", value: context.browser ?? String(localized: "Unknown browser"))
                        QeetrixDescriptionItem("Time", value: QeetrixFormat.time(fetched.challenge.signedInAt))
                        if let location = context.location, !location.isEmpty {
                            QeetrixDescriptionItem("Near", value: location)
                        }
                        if let ip = context.ip, !ip.isEmpty {
                            QeetrixDescriptionItem("IP address") {
                                Text(verbatim: ip).font(QeetrixTextMetrics(role: .codeSm).font)
                            }
                        }
                    }
                }
                NumberEntry(model: model)
                #if DEBUG
                    // The request's id for the end-to-end test, which sends its notification with `simctl push`.
                    Text(verbatim: fetched.challenge.id.uuidString)
                        .font(.system(size: 1))
                        .opacity(0.01)
                        .accessibilityIdentifier("request.id")
                #endif
            }
            .padding(QeetrixSpace.insetLg)
        }
        .scrollDismissesKeyboard(.never)
        .background(QeetrixColor.surfaceCanvas)
        .qeetrixBottomActionBar(
            primary: QeetrixScreenAction("Approve", icon: .check, isLoading: model.isApproving) { Task { await model.approve() } },
            secondary: QeetrixScreenAction("Deny", icon: .x, isLoading: model.isDenying) { Task { await model.deny() } }
        )
        .task(id: fetched.expiresAtLocal) {
            let wait = fetched.expiresAtLocal.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if !Task.isCancelled { model.expireIfDue() }
        }
        .accessibilityIdentifier("request.review")
    }
}

/// The 2-digit number from the sign-in screen, in two slots, on the number pad.
private struct NumberEntry: View {
    @Bindable var model: SignInRequestModel

    var body: some View {
        VStack(alignment: .leading, spacing: QeetrixSpace.gapXs) {
            Text("Number on your sign-in screen")
                .qeetrixTextStyle(.labelSm)
                .foregroundStyle(QeetrixColor.textSubtle)
                .accessibilityHidden(true)
            QeetrixOTPInput(code: $model.number, length: 2, size: .lg)
                .frame(width: 128, alignment: .leading)
                .accessibilityLabel(Text("Number on your sign-in screen"))
                .accessibilityIdentifier("request.number")
            if let error = model.numberError {
                Label {
                    Text(error)
                } icon: {
                    QeetrixIcon(.circleAlert, size: .sm, shape: .sharp)
                }
                .qeetrixTextStyle(.bodySm)
                .foregroundStyle(QeetrixColor.textDanger)
                .accessibilityIdentifier("request.number-error")
            }
        }
    }
}

extension SignInRequestModel.Phase {
    var isOutcome: Bool {
        if case .outcome = self { return true }
        return false
    }
}

/// Qeet ID's own pages the app links to.
enum QeetIDLinks {
    /// The console's Security page: change the password, see linked phones.
    static let accountSecurity = URL(string: "https://console.id.qeet.in/account/security")!
    /// Help and privacy.
    static let helpAndPrivacy = URL(string: "https://id.qeet.in/security")!
}
