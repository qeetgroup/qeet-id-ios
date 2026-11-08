import Qeetrix
import SwiftUI

/// Scan a QR code: the camera, then what it found, before anything is added (Add this account?), a code already on
/// this iPhone (nothing added twice), or another kind of QR code, named for what it is. A Qeet ID pairing code scanned
/// here goes to linking instead. Without the camera, Qeetrix's scanner explains and offers the setup key.
struct AddAccountView: View {
    let model: AppModel
    @State private var showsSetupKey = false
    @State private var outcome: ScanOutcome?
    /// The scanned account until Add: kept out of observable state, as it holds the secret.
    @State private var pending = PendingScan()

    var body: some View {
        NavigationStack {
            ScannerScreen(
                title: "Scan a QR code", guidance: Text("Point the camera at the QR code"), typeInstead: Text("Type the key instead"),
                lock: model.lock, onPayload: { handle($0) }, onTypeInstead: { showsSetupKey = true }, onCancel: { model.modal = nil }
            ) {
                if let outcome { ScanResultPanel(outcome: outcome, onAdd: add, onScanAgain: scanAgain, onShow: show) }
            }
        }
        .qeetrixSheet(isPresented: $showsSetupKey) {
            SetupKeySheet { draft throws(AccountStoreError) in
                let account = try model.accounts.add(draft)
                model.modal = nil
                model.accountAdded(account)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add-account")
    }

    private func handle(_ payload: String) {
        guard outcome == nil else { return }
        if let code = PairingCode.from(payload), payload.lowercased().hasPrefix("qeetidauth:") {
            model.startLinking(code: code)
            return
        }
        do {
            let draft = try OTPAuthURI.parse(payload)
            let already = model.accounts.accounts.contains {
                $0.issuer.caseInsensitiveCompare(draft.issuer) == .orderedSame
                    && $0.name.caseInsensitiveCompare(draft.name) == .orderedSame
            }
            if already {
                QeetrixFeedback.warning.play()
                outcome = .already(issuer: draft.issuer, name: draft.name)
            } else {
                QeetrixFeedback.success.play()
                pending.draft = draft
                outcome = .found(issuer: draft.issuer, name: draft.name)
            }
        } catch {
            QeetrixFeedback.warning.play()
            outcome = .notACode(ScanOutcome.description(of: payload, error: error))
        }
    }

    private func add() {
        guard let draft = pending.draft else { return scanAgain() }
        do {
            let account = try model.accounts.add(draft)
            pending.draft = nil
            model.modal = nil
            model.accountAdded(account)
        } catch {
            pending.draft = nil
            outcome = .already(issuer: draft.issuer, name: draft.name)
        }
    }

    private func scanAgain() {
        pending.draft = nil
        outcome = nil
    }

    private func show() {
        pending.draft = nil
        model.modal = nil
    }
}

/// The scanned account between the scan and Add, in a plain reference so the secret never enters observable state.
final class PendingScan {
    var draft: AccountDraft?
}

/// What a scan found.
enum ScanOutcome: Equatable {
    case found(issuer: String, name: String)
    case already(issuer: String, name: String)
    case notACode(String)

    /// What another QR code is, in words: the web page it opens, or the reason it isn't a sign-in code.
    static func description(of payload: String, error: SetupKeyError) -> String {
        if error != .notACodeQR { return error.message }
        if let url = URL(string: payload), let host = url.host(), url.scheme?.hasPrefix("http") == true {
            let place = host + (url.path().count > 1 ? url.path() : "")
            return String(localized: "It opens a web page, \(place). Use the QR code on the site’s 2-step verification page.")
        }
        return String(localized: "Use the QR code on the site’s 2-step verification page.")
    }
}

/// The panel over the foot of the camera: a solid surface, so it stays readable over any page.
private struct ScanResultPanel: View {
    let outcome: ScanOutcome
    let onAdd: @MainActor () -> Void
    let onScanAgain: @MainActor () -> Void
    let onShow: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: QeetrixSpace.insetLg) {
            HStack(alignment: .top, spacing: QeetrixSpace.gapMd) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    title.qeetrixTextStyle(.labelMd).fontWeight(.semibold).foregroundStyle(QeetrixColor.textDefault)
                    if let line { line.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            VStack(spacing: QeetrixSpace.gapXs) {
                switch outcome {
                case .found:
                    QeetrixButton("Add account", size: .lg, isFullWidth: true, action: onAdd)
                        .accessibilityIdentifier("scan.add")
                    QeetrixButton("Scan again", variant: .ghost, tone: .neutral, size: .lg, isFullWidth: true, action: onScanAgain)
                case .already:
                    QeetrixButton("Show it", size: .lg, isFullWidth: true, action: onShow)
                        .accessibilityIdentifier("scan.show")
                    QeetrixButton("Scan again", variant: .ghost, tone: .neutral, size: .lg, isFullWidth: true, action: onScanAgain)
                case .notACode:
                    QeetrixButton("Scan again", size: .lg, isFullWidth: true, action: onScanAgain)
                        .accessibilityIdentifier("scan.again")
                }
            }
        }
        .padding(QeetrixSpace.insetLg)
        .frame(maxWidth: .infinity)
        .background(QeetrixColor.surfaceRaised, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) { QeetrixSeparator(tone: .default) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan.result")
    }

    @ViewBuilder private var leading: some View {
        switch outcome {
        case .found(let issuer, _), .already(let issuer, _):
            QeetrixListItemIcon(monogram: String(issuer.prefix(1)).uppercased())
        case .notACode:
            QeetrixIcon(.triangleAlert, size: .md, shape: .sharp)
                .foregroundStyle(QeetrixColor.iconWarning)
                .frame(width: 32, height: 32)
        }
    }

    private var title: Text {
        switch outcome {
        case .found: Text("Add this account?")
        case .already(let issuer, let name):
            name.isEmpty ? Text("\(issuer) is already on this iPhone") : Text("\(issuer) (\(name)) is already on this iPhone")
        case .notACode: Text("This isn’t a sign-in code")
        }
    }

    private var line: Text? {
        switch outcome {
        case .found(let issuer, let name): name.isEmpty ? Text(verbatim: issuer) : Text(verbatim: "\(issuer) · \(name)")
        case .already: Text("Its codes are in Accounts. Nothing was added twice.")
        case .notACode(let description): Text(verbatim: description)
        }
    }
}
