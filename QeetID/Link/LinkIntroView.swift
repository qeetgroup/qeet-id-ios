import Qeetrix
import SwiftUI

/// Link this iPhone: a picture of the computer showing its code and this iPhone, what linking is for, the three steps
/// on the computer in the console's own words, then Scan the code; typing it is the quiet alternative. An iPhone that's
/// already linked says so first.
struct LinkIntroView: View {
    let model: AppModel
    @Environment(\.room) private var room

    var body: some View {
        let linked = model.link.isLinked
        ScrollView {
            PageColumn {
                if linked {
                    QeetrixAlert(
                        "This iPhone is already linked",
                        description: "Unlink it in Settings first to link it to another Qeet ID account.", tone: .info
                    ) {
                        QeetrixButton("Go to Settings", variant: .soft, size: .sm) { model.path = [.settings] }
                    }
                    .padding(.bottom, QeetrixSpace.insetLg)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("link.already")
                }
                LinkScene()
                PageTitle(
                    title: Text("Approve sign-ins here"),
                    line: Text(
                        "Instead of typing a code, approve each Qeet ID sign-in on this iPhone. You’ll need Qeet ID open on a computer.")
                )
                .padding(.top, room.isShort ? QeetrixSpace.gapMd : QeetrixSpace.layoutSm)
                Panel {
                    QeetrixText("On the computer", size: .sm, weight: .semibold, tone: .subtle)
                    NumberedSteps(steps: [
                        (Text("Open Qeet ID and go to My account"), Text("Then Security")),
                        (Text("Choose Link a phone"), Text("Under Linked phones")),
                        (Text("Scan the code it shows"), Text("It links one phone, once, within 5 minutes")),
                    ])
                }
                .padding(.top, room.isShort ? QeetrixSpace.gapMd : QeetrixSpace.insetLg)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(QeetrixColor.surfaceCanvas)
        .screenBar(Text("Link this iPhone"))
        .actionFooter(
            primary: QeetrixScreenAction("Scan the code", icon: .scanLine, isDisabled: linked) { model.modal = .scanPairing },
            tertiary: QeetrixScreenAction("Type the code", tone: .neutral, isDisabled: linked) { model.path.append(.linkName(code: nil)) }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("link.intro")
    }
}

/// The computer showing its code, and this iPhone: a picture of another screen, so its page is white in dark mode too.
private struct LinkScene: View {
    @Environment(\.room) private var room

    var body: some View {
        let short = room.isShort
        HStack(spacing: short ? QeetrixSpace.gapMd : QeetrixSpace.insetLg) {
            VStack(spacing: 0) {
                QeetrixQRCode("qeetidauth://pair?code=7KQ2M9XH4T", label: "", size: short ? 46 : 58)
                    .frame(width: short ? 100 : 128, height: short ? 66 : 84)
                    .background(.white, in: RoundedRectangle(cornerRadius: QeetrixRadius.sm))
                    .overlay {
                        RoundedRectangle(cornerRadius: QeetrixRadius.sm)
                            .strokeBorder(QeetrixColor.textDefault, lineWidth: short ? 4 : 5)
                    }
                RoundedRectangle(cornerRadius: QeetrixRadius.sm)
                    .fill(QeetrixColor.textSubtle)
                    .frame(width: short ? 118 : 150, height: 6)
            }
            HStack(spacing: 4) {
                Rectangle().fill(QeetrixColor.borderBrand).frame(width: 6, height: 6)
                Rectangle().fill(QeetrixColor.borderBrand).frame(width: short ? 16 : 24, height: 2)
            }
            BrandMark(size: short ? 22 : 28)
                .frame(width: short ? 43 : 54, height: short ? 76 : 96)
                .background(QeetrixColor.surfaceRaised, in: RoundedRectangle(cornerRadius: QeetrixRadius.surface))
                .overlay {
                    RoundedRectangle(cornerRadius: QeetrixRadius.surface).strokeBorder(QeetrixColor.textDefault, lineWidth: 3)
                }
        }
        .padding(.vertical, short ? QeetrixSpace.insetMd : QeetrixSpace.insetXl)
        .frame(maxWidth: .infinity)
        .brandPanel()
        .accessibilityHidden(true)
    }
}

/// Scan the code: the same scanner, worded for linking. A pairing code goes on to Name this iPhone by itself; a site's
/// sign-in QR code scanned here is named, with a way to add it to Accounts instead; an iPhone already linked isn't
/// linked twice.
struct PairingScannerView: View {
    let model: AppModel
    @State private var refused: PairingRefusal?

    var body: some View {
        NavigationStack {
            ScannerScreen(
                title: "Scan the code", guidance: Text("Point the camera at the code on the computer"),
                typeInstead: Text("Type the code instead"), lock: model.lock,
                onPayload: { handle($0) },
                onTypeInstead: {
                    model.modal = nil
                    model.showLinking(code: nil)
                },
                onCancel: { model.modal = nil }
            ) {
                if let refused { RefusalPanel(refusal: refused, model: model) { self.refused = nil } }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("link.scanner")
    }

    private func handle(_ payload: String) {
        guard refused == nil else { return }
        if model.link.isLinked {
            refused = .alreadyLinked
            return
        }
        guard let code = PairingCode.from(payload) else {
            QeetrixFeedback.warning.play()
            refused = payload.lowercased().hasPrefix("otpauth://") ? .signInCode : .notACode
            return
        }
        QeetrixFeedback.success.play()
        model.modal = nil
        model.showLinking(code: code)
    }
}

/// Why a scanned code doesn't link this iPhone.
enum PairingRefusal {
    case alreadyLinked, signInCode, notACode
}

private struct RefusalPanel: View {
    let refusal: PairingRefusal
    let model: AppModel
    let onScanAgain: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: QeetrixSpace.insetLg) {
            VStack(alignment: .leading, spacing: 2) {
                title.qeetrixTextStyle(.labelMd).fontWeight(.semibold).foregroundStyle(QeetrixColor.textDefault)
                line.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
            }
            .accessibilityElement(children: .combine)
            VStack(spacing: QeetrixSpace.gapXs) {
                switch refusal {
                case .alreadyLinked:
                    QeetrixButton("Done", size: .lg, isFullWidth: true) { model.modal = nil }
                case .signInCode:
                    QeetrixButton("Add to Accounts", size: .lg, isFullWidth: true) { model.modal = .addAccount }
                    QeetrixButton("Scan again", variant: .ghost, tone: .neutral, size: .lg, isFullWidth: true, action: onScanAgain)
                case .notACode:
                    QeetrixButton("Scan again", size: .lg, isFullWidth: true, action: onScanAgain)
                }
            }
        }
        .padding(QeetrixSpace.insetLg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QeetrixColor.surfaceRaised, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) { QeetrixSeparator(tone: .default) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("link.refused")
    }

    private var title: Text {
        switch refusal {
        case .alreadyLinked: Text("This iPhone already approves sign-ins")
        case .signInCode: Text("This is a site’s sign-in code")
        case .notACode: Text("This isn’t Qeet ID’s code")
        }
    }

    private var line: Text {
        switch refusal {
        case .alreadyLinked:
            if let email = model.link.summary?.accountEmail {
                Text("For \(email). Nothing was changed.")
            } else {
                Text("Nothing was changed.")
            }
        case .signInCode:
            Text("It adds an account to Accounts. To link this iPhone, scan the code under Link a phone on the computer.")
        case .notACode:
            Text("To link this iPhone, scan the code under Link a phone on the computer.")
        }
    }
}
