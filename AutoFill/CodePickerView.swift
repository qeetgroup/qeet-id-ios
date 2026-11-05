import Qeetrix
import SwiftUI

/// Screen 27, AutoFill: choose a code. Codes for the asking site first, then Face ID, then one tap fills the field.
/// Accounts for other sites open first, a deliberate second step, so a code isn't filled on the wrong site by reflex.
struct CodePickerView: View {
    let model: CodePickerModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                if model.access == .refused {
                    Section {
                        QeetrixEmptyState("Qeet ID is locked", description: "Unlock to fill a code.", icon: .lock, size: .section) {
                            QeetrixButton("Unlock", icon: .scanLine) { Task { await model.unlock() } }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                if model.isEmpty {
                    QeetrixEmptyState(
                        "No accounts yet", description: "Add an account in the Qeet ID app, then its codes appear here.", icon: .keyRound,
                        size: .section
                    )
                    .listRowBackground(Color.clear)
                }
                if !model.matching.isEmpty {
                    Section {
                        ForEach(model.matching) { account in
                            codeRow(account)
                        }
                    } header: {
                        QeetrixSectionHeader(title: Text("For \(model.site)"), isRuled: false)
                    }
                }
                if !model.others.isEmpty {
                    Section {
                        ForEach(model.others) { account in
                            if model.expanded.contains(account.id) {
                                codeRow(account)
                            } else {
                                QeetrixListItem(
                                    title: Text(verbatim: account.issuer),
                                    description: account.name.isEmpty ? nil : Text(verbatim: account.name), accessory: .chevron
                                ) {
                                    model.expanded.insert(account.id)
                                } leading: {
                                    IssuerTile(monogram: account.monogram)
                                }
                                .accessibilityHint(Text("Shows this account's code"))
                            }
                        }
                    } header: {
                        QeetrixSectionHeader(model.matching.isEmpty ? "Accounts" : "Other accounts", isRuled: !model.matching.isEmpty)
                    }
                }
            }
            .qeetrixListStyle()
            .navigationTitle("Choose a code")
            .navigationBarTitleDisplayMode(.inline)
            .qeetrixNavigationBar(title: .qeetrix)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancel() }
                }
            }
        }
        .task { await model.unlock() }
    }

    private func codeRow(_ account: OTPAccount) -> some View {
        Button {
            model.choose(account)
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                AutoFillCodeRow(account: account, code: model.code(for: account, at: context.date), now: context.date)
            }
        }
        .buttonStyle(.qeetrixListItem())
        .disabled(model.access != .unlocked)
        .qeetrixListRow(colorScheme: colorScheme)
    }
}

/// An account and its code, to fill rather than copy: the tile, issuer and name, then the code in two groups with the
/// ring and seconds left, amber in the last five seconds — `QeetrixOTPCode`'s look, whose tap can only copy.
private struct AutoFillCodeRow: View {
    let account: OTPAccount
    let code: GeneratedCode?
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: QeetrixSpace.gapMd) {
            IssuerTile(monogram: account.monogram)
            VStack(alignment: .leading, spacing: QeetrixSpace.gapSm) {
                AccountTitle(account: account)
                HStack(spacing: QeetrixSpace.gapMd) {
                    Text(verbatim: digits)
                        .font(QeetrixTextMetrics(role: .codeMd, size: 20).font)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(code == nil ? QeetrixColor.textSubtle : QeetrixColor.textDefault)
                        .environment(\.layoutDirection, .leftToRight)
                    if let code {
                        let secondsLeft = max(0, Int(code.validity.upperBound.timeIntervalSince(now).rounded(.up)))
                        let isUrgent = secondsLeft <= 5
                        QeetrixCircularProgress(
                            timerInterval: code.validity, countsDown: true, size: .lg, tone: isUrgent ? .warning : .brand)
                        Text(verbatim: QeetrixFormat.number(secondsLeft))
                            .qeetrixTextStyle(.labelMd)
                            .monospacedDigit()
                            .foregroundStyle(isUrgent ? QeetrixColor.textWarning : QeetrixColor.textSubtle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, QeetrixSpace.insetLg)
        .padding(.vertical, QeetrixSpace.insetMd)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: account.spokenName))
        .accessibilityValue(code.map { Text(verbatim: $0.code.map(String.init).joined(separator: " ")) } ?? Text("Locked"))
        .accessibilityHint(Text("Fills this code"))
        .privacySensitive()
    }

    /// "093 551", or dots while locked.
    private var digits: String {
        guard let code else { return "••• •••" }
        let text = code.code
        guard text.count >= 6, text.count.isMultiple(of: 2) else { return text }
        return "\(text.prefix(text.count / 2)) \(text.suffix(text.count / 2))"
    }
}
