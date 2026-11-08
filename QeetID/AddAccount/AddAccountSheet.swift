import Qeetrix
import SwiftUI

/// Add an account: Qeetrix's sheet over Accounts with both ways in, each said in a line, so people who have never added
/// a code know which to pick. Scanning comes first; the note answers the worry: codes stay on this iPhone.
struct AddAccountSheet: View {
    let onScan: @MainActor () -> Void
    let onTypeKey: @MainActor () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        QeetrixSheetContent(
            "Add an account", description: Text("From a website or app with 2-step verification"), onClose: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                choice(Text("Scan a QR code"), Text("The site shows one when you turn on 2-step verification"), id: "add.scan") {
                    QeetrixIcon(.qrCode, shape: .sharp)
                } action: {
                    dismiss()
                    onScan()
                }
                QeetrixSeparator()
                choice(Text("Type the setup key"), Text("If you can’t scan, the site gives a key to type"), id: "add.type") {
                    QeetrixIcon(.keyboard, size: .md, shape: .sharp)
                } action: {
                    dismiss()
                    onTypeKey()
                }
                HStack(alignment: .top, spacing: QeetrixSpace.gapSm) {
                    QeetrixIcon(.lock, size: .sm, shape: .sharp).foregroundStyle(QeetrixColor.iconSubtle)
                    QeetrixText("Codes are worked out on this iPhone and never leave it.", size: .sm, tone: .subtle)
                }
                .padding(.top, QeetrixSpace.insetLg)
            }
        } actions: {
            EmptyView()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add.sheet")
    }

    private func choice<Icon: View>(
        _ title: Text, _ note: Text, id: String, @ViewBuilder icon: () -> Icon, action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: QeetrixSpace.gapMd) {
                icon()
                    .foregroundStyle(QeetrixColor.iconBrand)
                    .frame(width: 40, height: 40)
                    .background(QeetrixColor.bgBrandSubtle, in: RoundedRectangle(cornerRadius: QeetrixRadius.control))
                VStack(alignment: .leading, spacing: 2) {
                    title.qeetrixTextStyle(.labelMd).fontWeight(.semibold).foregroundStyle(QeetrixColor.textDefault)
                    note.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                QeetrixIcon(.chevronRight, size: .sm, shape: .sharp).foregroundStyle(QeetrixColor.iconSubtle)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
