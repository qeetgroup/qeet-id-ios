import Qeetrix
import SwiftUI

/// Screen 27, AutoFill: choose a code. Codes for the asking site first, then Face ID, then one tap fills the field.
/// Accounts for other sites open first, a deliberate second step, so a code isn't filled on the wrong site by reflex.
struct CodePickerView: View {
    let model: CodePickerModel

    var body: some View {
        NavigationStack {
            List {
                if model.access == .refused {
                    Section {
                        QeetrixEmptyState("Qeet ID is locked", description: "Unlock to fill a code.", icon: .lock, size: .section) {
                            QeetrixButton("Unlock", icon: model.biometry.icon) { Task { await model.unlock() } }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                if model.isEmpty {
                    QeetrixEmptyState(
                        "No accounts yet", description: "Add an account in Qeet ID, then its codes appear here.", icon: .keyRound,
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
                                    QeetrixListItemIcon(monogram: account.monogram)
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
                    Button("Close") { model.cancel() }
                }
            }
        }
        .task { await model.unlock() }
    }

    /// An account and its code, to fill rather than copy: Qeetrix's code, whose tap runs the fill. It refreshes each
    /// second, so the next code shows when the period ends.
    private func codeRow(_ account: OTPAccount) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let code = model.code(for: account, at: context.date)
            QeetrixListItem(title: Text(verbatim: account.issuer), description: account.name.isEmpty ? nil : Text(verbatim: account.name)) {
                QeetrixListItemIcon(monogram: account.monogram)
            }
            .qeetrixListItemContent {
                if let code {
                    QeetrixOTPCode(
                        code.code, validity: code.validity, label: Text(verbatim: account.spokenName), size: .md,
                        actionHint: Text("Fills this code")
                    ) { _ in model.choose(account) }
                } else {
                    QeetrixText("Unlock to fill this code.", size: .sm, tone: .subtle)
                }
            }
        }
        .disabled(model.access != .unlocked)
        // The row's list look on the cell itself, outside the timeline.
        .qeetrixListRow()
    }
}
