import Qeetrix
import SwiftUI

/// Type the setup key: a form sheet, the iOS way, with Cancel and Add in the bar and Add enabled once there's a name and
/// a whole key. The line at the top says where sites show the key; the key is grouped in fours as it's typed, spaces
/// ignored, a wrong character explained at once, and a Paste button under it, as the key is usually copied. The rare
/// code settings stay closed, saying what's set.
struct SetupKeySheet: View {
    /// Stores the account; throws when it is already here or the Keychain refuses.
    let onAdd: @MainActor (AccountDraft) throws(AccountStoreError) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var service = ""
    @State private var accountName = ""
    /// The key as typed. It lives only in this field while the sheet is open, and is cleared when it closes.
    @State private var key = ""
    @State private var parameters = OTPParameters()
    @State private var showsAdvanced = false
    @State private var showsKeyError = false
    @State private var saveError: String?
    @FocusState private var focus: Field?

    private enum Field { case service, account, key }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: QeetrixSpace.gapLg) {
                    QeetrixText(
                        "On the site, look under the QR code for a link like “Can’t scan it?”. It shows the setup key.", tone: .subtle)
                    if let saveError {
                        QeetrixAlert(saveError, tone: .danger)
                    }
                    QeetrixTextField("Site or app", text: $service, prompt: Text("For example, Razorpay"))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focus, equals: .service)
                        .onSubmit { focus = .account }
                        .accessibilityIdentifier("setup.service")
                    QeetrixTextField(
                        "Account", text: $accountName, prompt: Text(verbatim: "you@example.com"),
                        description: Text("Your email or username there, to tell accounts apart"), isOptional: true
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .submitLabel(.next)
                    .focused($focus, equals: .account)
                    .onSubmit { focus = .key }
                    .accessibilityIdentifier("setup.account")
                    QeetrixTextField(
                        "Setup key", text: $key, prompt: Text(verbatim: "XXXX XXXX XXXX XXXX"),
                        description: Text("Letters A–Z and numbers 2–7. Spaces don’t matter."), error: keyError
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .textContentType(nil)
                    .privacySensitive()
                    .submitLabel(.done)
                    .focused($focus, equals: .key)
                    .onSubmit { add() }
                    .accessibilityIdentifier("setup.key")
                    .onChange(of: key) { _, typed in
                        let grouped = SetupKeySheet.grouped(typed)
                        if grouped != typed { key = grouped }
                    }
                    PasteButton(payloadType: String.self) { strings in
                        Task { @MainActor in key = SetupKeySheet.grouped(strings.first ?? "") }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.roundedRectangle(radius: QeetrixRadius.control))
                    .tint(QeetrixColor.bgBrandBold)
                    .accessibilityIdentifier("setup.paste")
                    advanced
                }
                .padding(QeetrixSpace.insetLg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(QeetrixColor.surfaceOverlay)
            .navigationTitle("Type the setup key")
            .navigationBarTitleDisplayMode(.inline)
            .qeetrixNavigationBar(title: .qeetrix)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { close() }
                        .accessibilityIdentifier("setup.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(!canAdd)
                        .accessibilityIdentifier("setup.add")
                }
            }
            .onChange(of: focus) { old, _ in
                if old == .key, !key.isEmpty { showsKeyError = true }
            }
            .onChange(of: key) { showsKeyError = showsKeyError && keyProblem != nil }
            .onAppear { focus = .service }
            .onDisappear { key = "" }
        }
    }

    /// Code settings: digits, period and algorithm, with today's choice summarised under the title. Each is a row, as the
    /// mockup draws it: the name at the start and a small segmented choice at the end.
    private var advanced: some View {
        QeetrixAccordionItem("Code settings", description: advancedSummary, isExpanded: $showsAdvanced) {
            VStack(alignment: .leading, spacing: QeetrixSpace.gapMd) {
                QeetrixText("Change these only if the site says to.", size: .sm, tone: .subtle)
                setting("Digits") {
                    QeetrixSegmentedControl(
                        "Digits", selection: $parameters.digits,
                        options: OTPParameters.supportedDigits.map { QeetrixOption(QeetrixFormat.number($0), value: $0) }, size: .sm)
                }
                setting("New code every") {
                    QeetrixSegmentedControl(
                        "New code every", selection: $parameters.period,
                        options: OTPParameters.supportedPeriods.map { QeetrixOption(title: Text("\($0) s"), value: $0) }, size: .sm)
                }
                setting("Algorithm") {
                    QeetrixSegmentedControl(
                        "Algorithm", selection: $parameters.algorithm,
                        options: OTPAlgorithm.allCases.map { QeetrixOption($0.displayName, value: $0) }, size: .sm)
                }
            }
        }
        .accessibilityIdentifier("setup.advanced")
    }

    /// Today's choice under "Code settings": "6 digits · every 30 s · SHA-1".
    private var advancedSummary: Text {
        Text("\(parameters.digits) digits · every \(parameters.period) s · \(parameters.algorithm.displayName)")
    }

    /// One code setting: its name at the start and the choice, at its own width, at the end; the choice moves under the
    /// name when the line is too narrow for both (a small iPhone, large text). The control's own label names it for
    /// VoiceOver, so the name shown isn't read twice.
    private func setting<Control: View>(_ title: LocalizedStringKey, @ViewBuilder control: () -> Control) -> some View {
        let name = Text(title)
            .qeetrixTextStyle(.labelMd)
            .foregroundStyle(QeetrixColor.textDefault)
            .accessibilityHidden(true)
        let choice = control()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: QeetrixSpace.gapLg) {
                name
                Spacer(minLength: 0)
                choice.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: QeetrixSpace.gapSm) {
                name
                choice
            }
        }
    }

    private var keyProblem: SetupKeyError? {
        do {
            _ = try SetupKey.decode(key)
            return nil
        } catch {
            return error
        }
    }

    /// A wrong character is said at once; a short key once the person moves on.
    private var keyError: String? {
        let problem = keyProblem
        if problem == .keyInvalid { return problem?.message }
        return showsKeyError ? problem?.message : nil
    }

    /// The key in groups of four, upper case, as sites show it; spaces and dashes typed are ignored.
    static func grouped(_ text: String) -> String {
        let characters = text.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        var out = ""
        for (index, character) in characters.enumerated() {
            if index > 0 && index % 4 == 0 { out.append(" ") }
            out.append(character)
        }
        return out
    }

    private var canAdd: Bool {
        !service.trimmingCharacters(in: .whitespaces).isEmpty && keyProblem == nil
    }

    private func add() {
        guard canAdd else {
            showsKeyError = !key.isEmpty
            return
        }
        do {
            let secret = try SetupKey.decode(key)
            let draft = AccountDraft(
                issuer: service.trimmingCharacters(in: .whitespacesAndNewlines),
                name: accountName.trimmingCharacters(in: .whitespacesAndNewlines), secret: secret, parameters: parameters)
            try onAdd(draft)
            close()
        } catch let error as AccountStoreError {
            saveError = error.message
        } catch {
            showsKeyError = true
        }
    }

    private func close() {
        key = ""
        dismiss()
    }
}
