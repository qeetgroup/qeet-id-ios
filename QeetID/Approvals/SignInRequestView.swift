import Qeetrix
import SwiftUI

/// A sign-in request: Review (is this you signing in, to which account, what's signing in from where and when, and the
/// number from the sign-in screen), Confirm it's you (the system's Face ID), and how it ended: Approved, Denied,
/// Request ended, Already answered. A wrong number keeps the request on screen with what happened.
struct SignInRequestView: View {
    @State var model: SignInRequestModel
    let onClose: @MainActor () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            content
        }
        .task { await model.load() }
        .qeetrixAlertDialog(Binding(get: { model.alert }, set: { model.alert = $0 }))
        .qeetrixFeedback(trigger: model.phase) { _, phase in
            guard case .outcome(let outcome) = phase else { return nil }
            switch outcome {
            case .approved: return .success
            case .denied: return .warning
            case .ended(.numberMismatch): return .error
            case .ended: return nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sign-in-request")
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            QeetrixSpinner(size: .lg, tone: .brand, label: Text("Loading the request"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(QeetrixColor.surfaceCanvas)
                .screenBar(Text("Sign-in request"))
                .toolbar { closeButton }
        case .review(let fetched):
            ReviewView(model: model, fetched: fetched)
                .toolbar { closeButton }
        case .outcome(.ended(.numberMismatch)):
            WrongNumberView(model: model, onClose: onClose)
        case .outcome(let outcome):
            outcomeView(outcome)
        case .failedToLoad(let error):
            ResultScreen(title: Text("Couldn’t open the request"), line: Text(error.connectionMessage)) {
                QeetrixIcon(.circleAlert, size: .md, shape: .sharp)
            } content: {
                EmptyView()
            }
            .actionFooter(
                primary: QeetrixScreenAction("Try again", icon: .refreshCw) { Task { await model.load() } },
                tertiary: QeetrixScreenAction("Done", tone: .neutral) { onClose() }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("request.load-error")
        }
    }

    @ToolbarContentBuilder private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { onClose() }
                .accessibilityIdentifier("request.close")
        }
    }

    @ViewBuilder private func outcomeView(_ outcome: SignInRequestModel.Outcome) -> some View {
        switch outcome {
        case .approved:
            ResultScreen(title: Text("Sign-in approved"), line: Text("Go back to the computer: it signs in by itself."), sealTone: .success)
            {
                QeetrixIcon(.check, size: .md, stroke: QeetrixIconStroke(2.5), shape: .sharp)
            } content: {
                RequestDetails(request: model.request, withPlace: true)
                ResultNote(text: Text("Not you after all? On the computer, go to My account, then Sessions, and sign it out.")) {
                    QeetrixIcon(.shieldAlert, size: .sm, shape: .sharp)
                }
            }
            .actionFooter(primary: QeetrixScreenAction("Done") { onClose() })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("request.approved")
        case .denied:
            DeniedResult(title: Text("Sign-in denied"), onDone: onClose) {
                RequestDetails(request: model.request, withPlace: true)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("request.denied")
        case .ended(.answered):
            ResultScreen(
                title: Text("Already answered"),
                line: Text("This sign-in was answered on another linked phone, or cancelled on the computer.")
            ) {
                QeetrixIcon(.smartphone, size: .md, shape: .sharp)
            } content: {
                RequestDetails(request: model.request, withPlace: false)
            }
            .actionFooter(primary: QeetrixScreenAction("Done") { onClose() })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("request.ended")
        case .ended(.notLinked):
            ResultScreen(
                title: Text("This iPhone can’t answer it"),
                line: Text(
                    "It isn’t linked to the account the request is for, or it was removed from the account. Link it again in Settings."),
                sealTone: .danger
            ) {
                QeetrixIcon(.x, size: .md, stroke: QeetrixIconStroke(2.5), shape: .sharp)
            } content: {
                EmptyView()
            }
            .actionFooter(primary: QeetrixScreenAction("Done") { onClose() })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("request.ended")
        case .ended(let reason):
            ResultScreen(
                title: Text("This request ended"),
                line: reason == .notFound
                    ? Text("It ran out of time, or it was answered already, so there’s nothing to do here.")
                    : Text("It wasn’t answered within 2 minutes, so nobody was signed in.")
            ) {
                QeetrixIcon(.clock, size: .md, shape: .sharp)
            } content: {
                RequestDetails(request: model.request, withPlace: false)
                ResultNote(text: Text("If it’s you, sign in again on the computer. A new request comes here.")) {
                    QeetrixIcon(.rotateCcw, size: .sm, shape: .sharp)
                }
            }
            .actionFooter(primary: QeetrixScreenAction("Done") { onClose() })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("request.ended")
        }
    }

    /// "1:46".
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Review the request: the question, the account, the sign-in's facts with their icons, and the number, centred, on
/// the number pad; Approve waits for both digits, then asks for Face ID. The time left counts down in the bar.
private struct ReviewView: View {
    @Bindable var model: SignInRequestModel
    let fetched: FetchedChallenge
    @Environment(\.room) private var room

    var body: some View {
        ScrollView {
            PageColumn {
                RequestHeading(action: fetched.challenge.action, email: model.accountEmail)
                FactsCard(challenge: fetched.challenge)
                    .padding(.top, room.isShort ? 12 : 20)
                VStack(spacing: 0) {
                    QeetrixText("Type the number on your sign-in screen", weight: .semibold, align: .center)
                    // A number match: two square slots, centred at their own width, and no SMS or authenticator code
                    // offered over the number pad.
                    QeetrixOTPInput(code: $model.number, accessibilityLabel: Text("Number from the sign-in screen"), length: 2, size: .lg)
                        .qeetrixOTPSlotWidth(.square)
                        .qeetrixOTPAutoFill(false)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.top, 12)
                        .accessibilityIdentifier("request.number")
                    if let error = model.numberError {
                        QeetrixText(Text(error), size: .sm, tone: .danger, align: .center)
                            .padding(.top, QeetrixSpace.gapSm)
                            .accessibilityIdentifier("request.number-error")
                    }
                    QeetrixText("Didn’t start this? Choose Deny.", size: .sm, tone: .subtle, align: .center)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                #if DEBUG
                    // The request's id for the end-to-end test, which sends its notification with `simctl push`.
                    Text(verbatim: fetched.challenge.id.uuidString)
                        .font(.system(size: 1))
                        .opacity(0.01)
                        .accessibilityIdentifier("request.id")
                #endif
            }
        }
        .scrollDismissesKeyboard(.never)
        .background(QeetrixColor.surfaceCanvas)
        .modifier(CountdownBar(model: model, fetched: fetched))
        .actionFooter(
            primary: QeetrixScreenAction("Approve", isLoading: model.isApproving, isDisabled: model.number.count < 2 || model.isDenying) {
                Task { await model.approve() }
            },
            tertiary: QeetrixScreenAction("Deny", tone: .neutral, isLoading: model.isDenying, isDisabled: model.isApproving) {
                Task { await model.deny() }
            }
        )
        .task(id: fetched.expiresAtLocal) {
            let wait = fetched.expiresAtLocal.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if !Task.isCancelled { model.expireIfDue() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("request.review")
    }
}

/// The bar's title, with the time left under it, ticking each second.
private struct CountdownBar: ViewModifier {
    let model: SignInRequestModel
    let fetched: FetchedChallenge

    func body(content: Content) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = model.secondsLeft(at: context.date)
            content
                .screenBar(Text("Sign-in request"), subtitle: Text("\(SignInRequestView.clock(seconds)) left"))
                .onChange(of: seconds) { _, left in if left == 0 { model.expireIfDue() } }
        }
    }
}

/// The number didn't match: Qeet ID stopped the sign-in. The request stays on screen, so people see which one.
private struct WrongNumberView: View {
    let model: SignInRequestModel
    let onClose: @MainActor () -> Void
    @Environment(\.room) private var room

    var body: some View {
        ScrollView {
            PageColumn {
                QeetrixAlert(
                    "The number didn’t match",
                    description: "So the sign-in was stopped. If it was you, sign in again on the computer and type the new number here.",
                    tone: .danger
                )
                .padding(.bottom, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                if let request = model.request {
                    RequestHeading(action: request.action, email: model.accountEmail)
                    FactsCard(challenge: request)
                        .padding(.top, room.isShort ? 12 : 20)
                }
            }
        }
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Sign-in request"))
        .actionFooter(primary: QeetrixScreenAction("Done") { onClose() })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("request.ended")
    }
}

/// "Is this you signing in?" and, under it, the account it's for.
private struct RequestHeading: View {
    let action: String
    let email: String?
    @Environment(\.room) private var room

    var body: some View {
        VStack(alignment: .leading, spacing: QeetrixSpace.gapXs) {
            QeetrixHeading(question, level: 1, size: room.isShort ? .headingSm : .headingMd)
            if let email, !email.isEmpty {
                QeetrixText("To \(email)", tone: .subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var question: Text {
        switch action {
        case "sign_in": Text("Is this you signing in?")
        case "step_up": Text("Is this you confirming it’s you?")
        default: Text("Is this you?")
        }
    }
}

/// The sign-in's facts on ruled rows, each with its icon: laptop, pin, clock, globe; each only when the server knows it.
private struct FactsCard: View {
    let challenge: SignInChallenge
    @Environment(\.room) private var room

    var body: some View {
        let context = challenge.context
        let place = context.location.flatMap { $0.isEmpty ? nil : $0 }
        let ip = context.ip.flatMap { $0.isEmpty ? nil : $0 }
        VStack(spacing: 0) {
            if let browser = context.browser {
                row(Text(verbatim: browser)) { QeetrixIcon(.laptop, size: .sm, shape: .sharp) }
            }
            if let place {
                QeetrixSeparator()
                row(Text("Near \(place)")) { QeetrixIcon(.mapPin, size: .sm, shape: .sharp) }
            }
            QeetrixSeparator()
            row(Text(RequestDetails.day(challenge.signedInAt))) { QeetrixIcon(.clock, size: .sm, shape: .sharp) }
            if let ip {
                QeetrixSeparator()
                row(Text("IP address \(ip)")) { QeetrixIcon(.globe, size: .sm, shape: .sharp) }
            }
        }
        .background(QeetrixColor.surfaceRaised, in: RoundedRectangle(cornerRadius: QeetrixRadius.surface))
        .overlay {
            RoundedRectangle(cornerRadius: QeetrixRadius.surface)
                .strokeBorder(QeetrixColor.borderDefault, lineWidth: QeetrixBorderWidth.default)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("The sign-in"))
    }

    private func row<Icon: View>(_ text: Text, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: QeetrixSpace.gapMd) {
            icon().foregroundStyle(QeetrixColor.iconSubtle)
            text.qeetrixTextStyle(.bodyMd).foregroundStyle(QeetrixColor.textDefault)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, QeetrixSpace.insetLg)
        .padding(.vertical, room.isShort ? QeetrixSpace.insetSm : 10)
        .accessibilityElement(children: .combine)
    }
}

/// Browser, where and time, label and value, for a result; where only when `withPlace`.
struct RequestDetails: View {
    let request: SignInChallenge?
    let withPlace: Bool

    var body: some View {
        if let request {
            let context = request.context
            let place = context.location.flatMap { $0.isEmpty ? nil : $0 }
            let rows: [(label: Text, value: Text)] =
                [
                    context.browser.map { (Text("Browser"), Text(verbatim: $0)) },
                    withPlace ? place.map { (Text("Where"), Text("Near \($0)")) } : nil,
                ]
                .compactMap { $0 } + [(Text("Time"), Text(QeetrixFormat.time(request.signedInAt)))]
            ResultDetails(rows: rows)
        }
    }

    /// "Today, 10:42 am", or the date and time on another day.
    static func day(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? String(localized: "Today, \(QeetrixFormat.time(date))")
            : QeetrixFormat.date(date, style: .medium) + ", " + QeetrixFormat.time(date)
    }
}

/// Denied, for one request or for all of them: the icon with a red seal, nobody signed in, and the next step spelt
/// out, since whoever tried got past the first step (usually the password). Change password opens the Security page.
struct DeniedResult<Details: View>: View {
    let title: Text
    let onDone: @MainActor () -> Void
    @ViewBuilder let details: Details
    @Environment(\.openURL) private var openURL

    var body: some View {
        ResultScreen(
            title: title, line: Text("Nobody was signed in. Whoever tried got past the first step, usually your password."),
            sealTone: .danger
        ) {
            QeetrixIcon(.x, size: .md, stroke: QeetrixIconStroke(2.5), shape: .sharp)
        } content: {
            details
            ResultNote(
                text: Text("Change your password, in case someone knows it. If it was you, sign in again on the computer."), warning: true
            ) {
                QeetrixIcon(.keyRound, size: .sm, shape: .sharp)
            }
        }
        .actionFooter(
            primary: QeetrixScreenAction("Change password") { openURL(QeetIDLinks.accountSecurity) },
            tertiary: QeetrixScreenAction("Done", tone: .neutral) { onDone() }
        )
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
    /// Qeet ID's privacy policy.
    static let privacy = URL(string: "https://id.qeet.in/legal/privacy")!
    /// The terms of use.
    static let terms = URL(string: "https://id.qeet.in/legal/terms")!
    /// The help centre.
    static let help = URL(string: "https://docs.qeet.in/id")!
    /// Support, by mail.
    static let support = URL(string: "mailto:support@qeet.in")!
}
