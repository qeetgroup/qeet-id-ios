import Qeetrix
import SwiftUI

/// Welcome: the icon on its rings in the brand band, what Qeet ID is for, its two jobs and where secrets stay, then
/// Get started above the home indicator, and that no account is needed to start.
struct WelcomeView: View {
    let biometry: Biometry
    let onStart: @MainActor () -> Void
    @Environment(\.room) private var room

    var body: some View {
        let tiny = room.height <= 640
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The brand band: edge to edge, under the status bar.
                MarkRings(size: tiny ? .xs : room.isShort ? .sm : .md)
                    .padding(.top, room.isShort ? QeetrixSpace.gapSm : QeetrixSpace.insetXl)
                    .padding(.bottom, room.isShort ? QeetrixSpace.gapSm : QeetrixSpace.insetLg)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 0) {
                    QeetrixHeading("Sign in safely, with this iPhone", level: 1, size: room.isShort ? .headingLg : .displaySm)
                        .padding(.top, QeetrixSpace.gapSm)
                    QeetrixText(
                        "Your sign-in codes, and a quick way to confirm it’s you when you sign in to Qeet ID.", size: tiny ? .md : .lg,
                        tone: .subtle
                    )
                    .padding(.top, tiny ? QeetrixSpace.gapSm : 12)
                    VStack(spacing: 0) {
                        JobRow(
                            title: Text("Sign-in codes"),
                            note: Text("For Qeet ID and any site with 2-step verification. They work offline.")
                        ) {
                            QeetrixIcon(.keyRound, size: .md, shape: .sharp)
                        }
                        JobRow(
                            title: Text("Approve sign-ins"),
                            note: Text("Confirm it’s you with \(biometry.name) when you sign in on a computer.")
                        ) {
                            QeetrixIcon(.shieldCheck, shape: .sharp)
                        }
                        JobRow(
                            title: Text("Kept on this iPhone"),
                            note: Text("Secrets stay in the Secure Enclave. Qeet ID never receives them."), isLast: true
                        ) {
                            QeetrixIcon(.lock, size: .md, shape: .sharp)
                        }
                    }
                    .overlay(alignment: .top) { QeetrixSeparator(tone: .default) }
                    .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                }
                .padding(.horizontal, 20)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .brandWash()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: QeetrixSpace.gapSm) {
                QeetrixButton("Get started", icon: .chevronRight, size: .lg, isFullWidth: true, action: onStart)
                    .accessibilityIdentifier("welcome.start")
                QeetrixText("No account needed to start", size: .sm, tone: .subtle, align: .center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, QeetrixSpace.gapSm)
            .background(QeetrixColor.surfaceCanvas, ignoresSafeAreaEdges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome")
    }
}

/// One thing the app does: an icon in the brand colour, a title and one line, on a ruled row.
private struct JobRow<Icon: View>: View {
    @Environment(\.room) private var room
    let title: Text
    let note: Text
    var isLast = false
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            icon
                .foregroundStyle(QeetrixColor.iconBrand)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                title.qeetrixTextStyle(.labelMd).fontWeight(.semibold).foregroundStyle(QeetrixColor.textDefault)
                note.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, room.isShort ? 10 : 14)
        .overlay(alignment: .bottom) {
            if !isLast { QeetrixSeparator() }
        }
        .accessibilityElement(children: .combine)
    }
}
