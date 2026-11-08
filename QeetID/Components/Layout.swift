import Qeetrix
import SwiftUI

// The pieces the Qeet ID screens share, as the mockups lay them out, built from Qeetrix tokens and components where
// Qeetrix has no component for them.

// MARK: - Room on the screen

private struct ScreenHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 874
}

extension EnvironmentValues {
    /// The window's full height, safe areas included: the mockups size their phones by it (667, 700, 800).
    var screenHeight: CGFloat {
        get { self[ScreenHeightKey.self] }
        set { self[ScreenHeightKey.self] = newValue }
    }
}

extension View {
    /// Measures the window and hands its height down, so screens can tighten on a short iPhone. Apply at the root.
    func measuresScreenHeight() -> some View {
        modifier(ScreenHeightReader())
    }
}

private struct ScreenHeightReader: ViewModifier {
    @State private var height = ScreenHeightKey.defaultValue

    func body(content: Content) -> some View {
        content
            .environment(\.screenHeight, height)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            } action: {
                height = $0
            }
    }
}

/// How much room a screen has: a short iPhone (SE) tightens spacing and shrinks heroes, so the page fits unscrolled.
struct Room {
    let height: CGFloat
    var isShort: Bool { height < 700 }
    var isMedium: Bool { height <= 800 }
}

extension EnvironmentValues {
    var room: Room { Room(height: screenHeight) }
}

// MARK: - Bars

extension View {
    /// A screen's ruled inline bar: the title and, under it, a line (a step, a count, the time left).
    func screenBar(_ title: Text, subtitle: Text? = nil) -> some View {
        modifier(ScreenBar(title: title, subtitle: subtitle))
    }
}

private struct ScreenBar: ViewModifier {
    let title: Text
    let subtitle: Text?

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
            .toolbar {
                if let subtitle {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            title
                                .qeetrixTextStyle(.labelMd)
                                .foregroundStyle(QeetrixColor.textDefault)
                            subtitle
                                .qeetrixTextStyle(.bodySm)
                                .monospacedDigit()
                                .foregroundStyle(QeetrixColor.textSubtle)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Rectangle()
                    .fill(QeetrixColor.borderDefault)
                    .frame(height: QeetrixBorderWidth.default)
                    .accessibilityHidden(true)
            }
    }
}

// MARK: - Page pieces

/// A page's column: the phone's gutter, and the mockup's top and bottom room (tighter on a short iPhone).
struct PageColumn<Content: View>: View {
    @Environment(\.room) private var room
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: alignment, spacing: 0) { content }
            .padding(.horizontal, 20)
            .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
            .padding(.bottom, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A heading and its line, the way the mockups open a page.
struct PageTitle: View {
    @Environment(\.room) private var room
    let title: Text
    var line: Text?
    var centred = false

    var body: some View {
        VStack(alignment: centred ? .center : .leading, spacing: room.isShort ? 6 : QeetrixSpace.gapMd) {
            QeetrixHeading(title, level: 1, size: room.isShort ? .headingSm : .headingMd, align: centred ? .center : nil)
            if let line {
                QeetrixText(line, size: room.isShort ? .md : .lg, tone: .subtle, align: centred ? .center : nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
    }
}

/// A raised, ruled 4 pt panel (Qeetrix's card look) for facts, steps and details.
struct Panel<Content: View>: View {
    @Environment(\.room) private var room
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: room.isShort ? QeetrixSpace.gapSm : 10) { content }
            .padding(room.isShort ? 12 : QeetrixSpace.insetLg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QeetrixColor.surfaceRaised, in: RoundedRectangle(cornerRadius: QeetrixRadius.surface))
            .overlay {
                RoundedRectangle(cornerRadius: QeetrixRadius.surface)
                    .strokeBorder(QeetrixColor.borderDefault, lineWidth: QeetrixBorderWidth.default)
            }
    }
}

/// One promise, with a green tick on a fixed column; or a red cross for what stops.
struct Fact: View {
    @Environment(\.room) private var room
    let text: Text
    var stops = false

    init(_ text: Text, stops: Bool = false) {
        self.text = text
        self.stops = stops
    }

    init(_ key: LocalizedStringKey, stops: Bool = false) {
        self.init(Text(key), stops: stops)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: QeetrixSpace.gapMd) {
            QeetrixIcon(stops ? .x : .check, size: .sm, shape: .sharp)
                .foregroundStyle(stops ? QeetrixColor.iconDanger : QeetrixColor.iconSuccess)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            QeetrixText(text, size: room.isShort ? .sm : .md)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A small label above a group: the only uppercase text, as Qeetrix's group labels are. The capitals are drawn for the
/// locale; VoiceOver (and UI tests) get the words as written.
struct GroupLabel: View {
    let title: LocalizedStringResource
    @Environment(\.locale) private var locale

    init(_ title: LocalizedStringResource) { self.title = title }

    var body: some View {
        let written = String(localized: title)
        Text(verbatim: written.uppercased(with: locale))
            .qeetrixTextStyle(.labelCaps)
            .foregroundStyle(QeetrixColor.textSubtle)
            .accessibilityLabel(Text(verbatim: written))
            .accessibilityAddTraits(.isHeader)
    }
}

/// Numbered steps on a fixed column: a brand number tile, the step and a line under it.
struct NumberedSteps: View {
    @Environment(\.room) private var room
    let steps: [(title: Text, note: Text)]

    var body: some View {
        VStack(alignment: .leading, spacing: room.isShort ? QeetrixSpace.gapSm : QeetrixSpace.gapMd) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: QeetrixSpace.gapMd) {
                    Text(verbatim: QeetrixFormat.number(index + 1, locale: .current))
                        .qeetrixTextStyle(.labelSm)
                        .fontWeight(.semibold)
                        .foregroundStyle(QeetrixColor.textBrand)
                        .frame(width: 24, height: 24)
                        .background(QeetrixColor.bgBrandSubtle, in: RoundedRectangle(cornerRadius: QeetrixRadius.sm))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        step.title.qeetrixTextStyle(.labelMd).fontWeight(.semibold).foregroundStyle(QeetrixColor.textDefault)
                        step.note.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Results

/// How something ended (iPhone linked, Approved, Denied, Request ended, Update required): the icon with a seal on the
/// soft brand wash, the outcome and a line, then whatever follows (facts, a note), and the actions at the foot.
struct ResultScreen<Seal: View, Content: View>: View {
    @Environment(\.room) private var room
    let title: Text
    let line: Text
    var sealTone: SealTone = .brand
    @ViewBuilder let seal: () -> Seal
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MarkRings(size: room.isShort ? .sm : .md, sealTone: sealTone, seal: seal)
                PageTitle(title: title, line: line, centred: true)
                    .padding(.top, room.isShort ? QeetrixSpace.insetLg : QeetrixSpace.layoutSm)
                VStack(alignment: .leading, spacing: QeetrixSpace.gapLg) { content }
                    .padding(.top, room.isShort ? 20 : 28)
            }
            .padding(.horizontal, QeetrixSpace.insetXl)
            .padding(.vertical, QeetrixSpace.insetXl)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center) { length, _ in length }
        }
        .scrollBounceBehavior(.basedOnSize)
        .brandWash()
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// A result's facts, label and value on each ruled row (Browser · Chrome on macOS), in a raised 4 pt card.
struct ResultDetails: View {
    let rows: [(label: Text, value: Text)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { QeetrixSeparator() }
                HStack(alignment: .firstTextBaseline, spacing: QeetrixSpace.gapLg) {
                    row.label.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
                    Spacer(minLength: 0)
                    row.value
                        .qeetrixTextStyle(.labelMd)
                        .fontWeight(.semibold)
                        .foregroundStyle(QeetrixColor.textDefault)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, QeetrixSpace.insetLg)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
        .background(QeetrixColor.surfaceRaised, in: RoundedRectangle(cornerRadius: QeetrixRadius.surface))
        .overlay {
            RoundedRectangle(cornerRadius: QeetrixRadius.surface)
                .strokeBorder(QeetrixColor.borderDefault, lineWidth: QeetrixBorderWidth.default)
        }
    }
}

/// What happens next, or what to do, with an icon at its start: brand, or amber when it's a warning.
struct ResultNote<Icon: View>: View {
    let text: Text
    var warning = false
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            icon
                .foregroundStyle(warning ? QeetrixColor.iconWarning : QeetrixColor.iconBrand)
                .padding(.top, 1)
            text
                .qeetrixTextStyle(.bodySm)
                .foregroundStyle(QeetrixColor.textSubtle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Settings-style groups

/// A titled group of rows, as Accounts: the title in caps, then the rows full width and ruled.
struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupLabel(title)
                .padding(.horizontal, QeetrixSpace.insetLg)
                .padding(.bottom, QeetrixSpace.gapSm)
            VStack(spacing: 0) { content }
                .background(QeetrixColor.surfaceRaised)
                .overlay(alignment: .top) { QeetrixSeparator(tone: .default) }
                .overlay(alignment: .bottom) { QeetrixSeparator(tone: .default) }
        }
        .padding(.bottom, QeetrixSpace.layoutSm)
    }
}

/// The Qeetrix switch on its own, at the end of a settings row whose label says what it sets, as the mockup draws it.
/// Qeetrix's switch always draws its label beside the track and stretches across the row, so the row's label showed
/// twice; this keeps the track at its own width (switch.css, 32 pt) and gives VoiceOver the label instead.
struct RowSwitch: View {
    let label: Text
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) { EmptyView() }
            .toggleStyle(.qeetrixSwitch)
            // The switch's empty label column falls outside the track's width.
            .frame(width: 32, alignment: .leading)
            .accessibilityLabel(label)
    }
}

/// The rule between two rows of a `SettingsGroup`.
struct SettingsRule: View {
    var body: some View { QeetrixSeparator() }
}

/// What a settings row ends with when it opens something.
enum RowAccessory {
    case none
    /// Opens a screen in the app.
    case chevron
    /// Leaves the app (a web page, mail).
    case external
}

/// One setting: an optional mark at the start, the label and a line under it, and at the end a value, a control, or
/// a chevron when the row opens something (an arrow out when it leaves the app). A danger row is red, and last.
struct SettingsRow<Start: View, End: View>: View {
    let label: Text
    var detail: Text?
    var value: Text?
    var danger = false
    var accessory: RowAccessory = .none
    var action: (@MainActor () -> Void)?
    @ViewBuilder var start: Start
    @ViewBuilder var end: End

    var body: some View {
        if let action {
            Button(action: action) { row }
                .buttonStyle(.qeetrixListItem())
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: QeetrixSpace.gapMd) {
            start
            VStack(alignment: .leading, spacing: 2) {
                label
                    .qeetrixTextStyle(.bodyMd)
                    .fontWeight(Start.self != EmptyView.self && !danger ? .semibold : .regular)
                    .foregroundStyle(danger ? QeetrixColor.textDanger : QeetrixColor.textDefault)
                if let detail {
                    detail.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            if let value {
                value.qeetrixTextStyle(.bodySm).foregroundStyle(QeetrixColor.textSubtle)
            }
            end
            if action != nil && !danger {
                switch accessory {
                case .external:
                    QeetrixIcon(.externalLink, size: .sm, shape: .sharp, mirrorsInRightToLeft: true).foregroundStyle(
                        QeetrixColor.iconSubtle)
                case .chevron:
                    QeetrixIcon(.chevronRight, size: .sm, shape: .sharp).foregroundStyle(QeetrixColor.iconSubtle)
                case .none:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, QeetrixSpace.insetLg)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        // One element to read, unless it ends with a control (a switch, a button) that must stay reachable.
        .accessibilityElement(children: End.self == EmptyView.self ? .combine : .contain)
    }
}

extension SettingsRow where Start == EmptyView, End == EmptyView {
    init(
        _ label: Text, detail: Text? = nil, value: Text? = nil, danger: Bool = false, accessory: RowAccessory = .chevron,
        action: (@MainActor () -> Void)? = nil
    ) {
        self.init(
            label: label, detail: detail, value: value, danger: danger, accessory: accessory, action: action, start: { EmptyView() },
            end: { EmptyView() })
    }
}

extension SettingsRow where Start == EmptyView {
    init(
        _ label: Text, detail: Text? = nil, value: Text? = nil, danger: Bool = false, accessory: RowAccessory = .chevron,
        action: (@MainActor () -> Void)? = nil, @ViewBuilder end: () -> End
    ) {
        self.init(
            label: label, detail: detail, value: value, danger: danger, accessory: accessory, action: action, start: { EmptyView() },
            end: end)
    }
}
