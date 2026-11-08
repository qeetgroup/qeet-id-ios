import Qeetrix
import SwiftUI

/// Locked: the icon with a lock seal on the brand wash, "Qeet ID is locked", and Unlock with Face ID at the foot.
/// Opening or returning to the app shows it while the lock is on, and asks for Face ID by itself. Opened from a
/// sign-in request's notification, it says one is waiting. Nothing behind it shows while it does.
struct LockedView: View {
    let lock: AppLock
    var requestWaiting = false
    @Environment(\.room) private var room

    var body: some View {
        let biometry = lock.biometry
        ScrollView {
            VStack(spacing: 0) {
                MarkRings(size: room.isShort ? .sm : .md) {
                    QeetrixIcon(.lock, size: .md, shape: .sharp)
                }
                PageTitle(title: Text("Qeet ID is locked"), line: Text("Unlock to see your codes and sign-in requests."), centred: true)
                    .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                if lock.lastOutcome == .failed {
                    QeetrixText(
                        "\(biometry.name) didn’t recognise you. Try again, or use your passcode.", size: .sm, tone: .danger, align: .center
                    )
                    .padding(.top, QeetrixSpace.gapMd)
                    .accessibilityIdentifier("locked.failed")
                }
                if requestWaiting {
                    RequestWaitingCard()
                        .padding(.top, QeetrixSpace.layoutSm)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("locked.request-waiting")
                }
            }
            .padding(QeetrixSpace.insetXl)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center) { length, _ in length }
        }
        .scrollBounceBehavior(.basedOnSize)
        .brandWash()
        .actionFooter(
            primary: QeetrixScreenAction(title: Text(biometry.unlockTitle), isLoading: lock.isAuthenticating) {
                Task { await lock.unlock() }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("locked")
    }
}

/// The card a sign-in request's notification opens the locked app with.
private struct RequestWaitingCard: View {
    var body: some View {
        HStack(spacing: QeetrixSpace.gapMd) {
            AppIcon(.bellRing)
                .foregroundStyle(QeetrixColor.iconBrand)
                .frame(width: 40, height: 40)
                .background(QeetrixColor.bgBrandSubtle, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("A sign-in request is waiting").qeetrixTextStyle(.labelMd).fontWeight(.semibold)
                    .foregroundStyle(QeetrixColor.textDefault)
                Text("Unlock to see who’s signing in, and approve or deny it.").qeetrixTextStyle(.bodySm)
                    .foregroundStyle(QeetrixColor.textSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(QeetrixSpace.insetMd)
        .background(QeetrixColor.surfaceRaised, in: RoundedRectangle(cornerRadius: QeetrixRadius.surface))
        .overlay {
            RoundedRectangle(cornerRadius: QeetrixRadius.surface)
                .strokeBorder(QeetrixColor.borderDefault, lineWidth: QeetrixBorderWidth.default)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The cover the app switcher shows while the lock is off: the icon and the app's name, never a code.
struct PrivacyCoverView: View {
    var body: some View {
        VStack(spacing: QeetrixSpace.gapMd) {
            BrandMark(size: 64)
            QeetrixHeading("Qeet ID", level: 1, size: .titleMd, align: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QeetrixColor.surfaceCanvas)
        .accessibilityIdentifier("privacy-cover")
    }
}
