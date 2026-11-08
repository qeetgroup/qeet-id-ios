import Qeetrix
import SwiftUI

/// Qeet ID's icon inside the app: the white keyhole on the Qeet orange gradient, in the app icon's rounded square, as
/// on the Home Screen. Logo colours, not UI colours (so not tokens), the same in light and dark. Drawn from the brand's
/// geometry in a 100-unit box: disc r 29, the keyhole's head r 8.5 at (50, 43), its stem to y 64.5, corners 22.5.
struct BrandMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(BrandMark.gradient)
            KeyholeDisc()
                .fill(.white, style: FillStyle(eoFill: true))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// #DA653A → #D04800 → #9B3314, from (0.2, 0) to (0.8, 1).
    static let gradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0xDA / 255, green: 0x65 / 255, blue: 0x3A / 255), location: 0),
            .init(color: Color(red: 0xD0 / 255, green: 0x48 / 255, blue: 0x00 / 255), location: 0.45),
            .init(color: Color(red: 0x9B / 255, green: 0x33 / 255, blue: 0x14 / 255), location: 1),
        ],
        startPoint: UnitPoint(x: 0.2, y: 0), endPoint: UnitPoint(x: 0.8, y: 1))
}

/// The white disc with the keyhole cut out (fill it even-odd), scaled from the 100-unit box to its frame.
struct KeyholeDisc: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 100
        var path = Path()
        path.addEllipse(in: CGRect(x: 21, y: 21, width: 58, height: 58))
        let head = CGPoint(x: 50, y: 43)
        path.move(to: CGPoint(x: 46.2, y: 50.6))
        path.addLine(to: CGPoint(x: 43.5, y: 64.5))
        path.addLine(to: CGPoint(x: 56.5, y: 64.5))
        path.addLine(to: CGPoint(x: 53.8, y: 50.6))
        // Over the top of the head, from the stem's right edge back to its left.
        path.addArc(
            center: head, radius: 8.5, startAngle: .radians(atan2(50.6 - 43, 53.8 - 50)),
            endAngle: .radians(atan2(50.6 - 43, 46.2 - 50)), clockwise: true)
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: unit, y: unit).translatedBy(x: rect.minX / unit, y: rect.minY / unit))
    }
}

/// The icon on brand rings, by how much room the screen has.
enum RingsSize {
    case lg, md, sm, xs

    var box: CGFloat {
        switch self {
        case .lg: 208
        case .md: 160
        case .sm: 112
        case .xs: 80
        }
    }

    var inner: CGFloat {
        switch self {
        case .lg: 28
        case .md: 20
        case .sm: 14
        case .xs: 10
        }
    }

    var mark: CGFloat {
        switch self {
        case .lg: 104
        case .md: 80
        case .sm: 56
        case .xs: 44
        }
    }
}

/// The seal on the icon's corner: the brand's ring, a green tick for something done, red for something stopped.
enum SealTone {
    case brand, success, danger
}

/// The hero of Qeet ID's welcoming and result screens: the icon on two soft brand rings, with an optional seal (an
/// icon, drawn in the seal's foreground) on its lower corner. The seal is 0.6 of the icon, its centre a tenth of the
/// icon in from the corner, at every size, so it never hides the keyhole.
struct MarkRings<Seal: View>: View {
    let size: RingsSize
    var sealTone: SealTone = .brand
    @ViewBuilder let seal: () -> Seal
    var hasSeal = true

    var body: some View {
        ZStack {
            Circle().fill(QeetrixColor.bgBrandSubtle.opacity(0.6))
            Circle().fill(QeetrixColor.bgBrandSubtle).padding(size.inner)
            BrandMark(size: size.mark)
            if hasSeal {
                let side = (size.mark * 0.6).rounded()
                ZStack {
                    Circle().fill(sealBackground)
                    Circle().strokeBorder(sealRing, lineWidth: 2)
                    seal()
                        .foregroundStyle(sealForeground)
                        .frame(width: side * 0.52, height: side * 0.52)
                }
                .frame(width: side, height: side)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .offset(x: size.mark * 0.4, y: size.mark * 0.4)
            }
        }
        .frame(width: size.box, height: size.box)
        .accessibilityHidden(true)
    }

    private var sealBackground: QeetrixColor {
        switch sealTone {
        case .brand: .surfaceRaised
        case .success: .bgSuccessBold
        case .danger: .bgDangerBold
        }
    }

    private var sealRing: QeetrixColor {
        switch sealTone {
        case .brand: .borderBrand
        case .success, .danger: .surfaceRaised
        }
    }

    private var sealForeground: QeetrixColor {
        switch sealTone {
        case .brand: .iconBrand
        case .success, .danger: .iconOnBold
        }
    }
}

extension MarkRings where Seal == EmptyView {
    /// The icon on its rings, with no seal.
    init(size: RingsSize) {
        self.init(size: size, seal: { EmptyView() }, hasSeal: false)
    }
}

extension View {
    /// The soft brand wash behind a hero, edge to edge under the status bar, fading into the page.
    func brandWash() -> some View {
        background {
            ZStack {
                Rectangle().fill(QeetrixColor.surfaceCanvas)
                // The tint in the scheme's own brand colour, faded out by the middle of the screen.
                Rectangle()
                    .fill(QeetrixColor.bgBrandSubtle)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center))
            }
            .ignoresSafeArea()
        }
    }

    /// The soft brand panel a picture sits on (a notification, a computer and a phone): the brand tint, fading down.
    func brandPanel() -> some View {
        background {
            RoundedRectangle(cornerRadius: QeetrixRadius.surface)
                .fill(QeetrixColor.bgBrandSubtle)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom))
        }
    }
}
