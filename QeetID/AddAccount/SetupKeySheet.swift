import Qeetrix
import SwiftUI

/// Screen 8, Type the setup key: a form sheet, the iOS way, with Cancel and Add in the bar and Add enabled once the
/// key is valid. Placeholders are examples; the rare settings sit under Advanced.
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
                    if let saveError {
                        QeetrixAlert(saveError, tone: .danger)
                    }
                    QeetrixTextField("Service", text: $service, prompt: Text(verbatim: "e.g. Razorpay"))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focus, equals: .service)
                        .onSubmit { focus = .account }
                        .accessibilityIdentifier("setup.service")
                    QeetrixTextField(
                        "Account", text: $accountName, prompt: Text(verbatim: "e.g. accounts@brightleaffoods.in"), isOptional: true
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .submitLabel(.next)
                    .focused($focus, equals: .account)
                    .onSubmit { focus = .key }
                    .accessibilityIdentifier("setup.account")
                    QeetrixTextField(
                        "Setup key", text: $key, prompt: Text(verbatim: "e.g. JBSW Y3DP EHPK 3PXP"),
                        description: Text("From the site's setup page. Spaces don't matter."), error: keyError
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
                    advanced
                }
                .padding(QeetrixSpace.insetLg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(QeetrixColor.surfaceOverlay)
            .navigationTitle("Setup key")
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

    /// Advanced: digits, period and algorithm, with today's choice summarised under the title.
    private var advanced: some View {
        QeetrixAccordionItem(title: advancedTitle, isExpanded: $showsAdvanced) {
            VStack(alignment: .leading, spacing: QeetrixSpace.gapLg) {
                labelled("Digits") {
                    QeetrixSegmentedControl(
                        "Digits", selection: $parameters.digits,
                        options: OTPParameters.supportedDigits.map { QeetrixOption(QeetrixFormat.number($0), value: $0) })
                }
                labelled("New code every") {
                    QeetrixSegmentedControl(
                        "New code every", selection: $parameters.period,
                        options: OTPParameters.supportedPeriods.map { QeetrixOption(title: Text("\($0) seconds"), value: $0) })
                }
                labelled("Algorithm") {
                    QeetrixSegmentedControl(
                        "Algorithm", selection: $parameters.algorithm,
                        options: OTPAlgorithm.allCases.map { QeetrixOption($0.displayName, value: $0) })
                }
            }
        }
        .accessibilityIdentifier("setup.advanced")
    }

    /// "Advanced" over "6 digits · every 30 seconds · SHA-1", in `body.sm`, `color.text.subtle`.
    private var advancedTitle: Text {
        let summary = String(
            localized: "\(parameters.digits) digits · every \(parameters.period) seconds · \(parameters.algorithm.displayName)")
        return Text("Advanced")
            + Text(verbatim: "\n" + summary)
            .font(QeetrixTextMetrics(role: .bodySm).font)
            .foregroundStyle(QeetrixColor.textSubtle)
    }

    private func labelled<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: QeetrixSpace.gapXs) {
            Text(title)
                .qeetrixTextStyle(.labelSm)
                .foregroundStyle(QeetrixColor.textSubtle)
                .accessibilityHidden(true)
            content()
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

    private var keyError: String? {
        showsKeyError ? keyProblem?.message : nil
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
