#!/usr/bin/env python3
"""Generates QeetID/Components/AppIcons.swift: the icons the screens need that Qeetrix for iOS doesn't have yet,
from @qeetrix/icons' sharp-outline SVGs, in the drawing format Qeetrix's own catalogue uses (absolute commands in the
24-unit grid, arcs and smooth curves expanded), so they draw exactly like a QeetrixIcon.

    Scripts/generate-app-icons.py <path to @qeetrix/icons/dist/svg/sharp-outline>

Each icon here is a gap recorded for Qeetrix for iOS; drop it once Qeetrix ships it.
"""
import math
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ICONS = [
    "arrow-left-right", "bell-ring", "bot-off", "clipboard-paste", "download", "globe", "laptop", "monitor",
    "rotate-ccw", "shield-alert", "sparkles",
]

OUT = pathlib.Path(__file__).resolve().parent.parent / "QeetID/Components/AppIcons.swift"


def fmt(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


TOKEN = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")


def arc_to_cubics(x1, y1, rx, ry, phi, large, sweep, x2, y2):
    """SVG arc (endpoint form) to cubic Béziers, each at most a quarter turn."""
    if rx == 0 or ry == 0:
        return [("line", x2, y2)]
    rx, ry = abs(rx), abs(ry)
    cphi, sphi = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = cphi * dx + sphi * dy, -sphi * dx + cphi * dy
    lam = (x1p ** 2) / (rx ** 2) + (y1p ** 2) / (ry ** 2)
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    coef = math.sqrt(max(0.0, num / den)) if den else 0.0
    if large == sweep:
        coef = -coef
    cxp, cyp = coef * rx * y1p / ry, -coef * ry * x1p / rx
    cx = cphi * cxp - sphi * cyp + (x1 + x2) / 2
    cy = sphi * cxp + cphi * cyp + (y1 + y2) / 2

    def angle(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    t1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    elif sweep and dt < 0:
        dt += 2 * math.pi
    segments = max(1, math.ceil(abs(dt) / (math.pi / 2) - 1e-9))
    step = dt / segments
    k = 4 / 3 * math.tan(step / 4)
    out = []
    t = t1
    for _ in range(segments):
        cos1, sin1 = math.cos(t), math.sin(t)
        cos2, sin2 = math.cos(t + step), math.sin(t + step)
        p1 = (cos1 - k * sin1, sin1 + k * cos1)
        p2 = (cos2 + k * sin2, sin2 - k * cos2)
        p3 = (cos2, sin2)

        def tr(p):
            px, py = p[0] * rx, p[1] * ry
            return cphi * px - sphi * py + cx, sphi * px + cphi * py + cy

        a, b, c = tr(p1), tr(p2), tr(p3)
        out.append(("cubic", a[0], a[1], b[0], b[1], c[0], c[1]))
        t += step
    return out


def path_commands(d):
    tokens = TOKEN.findall(d)
    i, cmd = 0, None
    x = y = sx = sy = 0.0
    last_ctrl = None  # (kind, x, y) of the previous curve's second control point
    out = []

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    while i < len(tokens):
        if re.match(r"[A-Za-z]", tokens[i]):
            cmd = tokens[i]
            i += 1
            if cmd in "Zz":
                out.append(("close",))
                x, y = sx, sy
                last_ctrl = None
                continue
        rel = cmd.islower()
        c = cmd.upper()
        ox, oy = (x, y) if rel else (0.0, 0.0)
        if c == "M":
            x, y = ox + num(), oy + num()
            sx, sy = x, y
            out.append(("move", x, y))
            cmd = "l" if rel else "L"
            last_ctrl = None
        elif c == "L":
            x, y = ox + num(), oy + num()
            out.append(("line", x, y))
            last_ctrl = None
        elif c == "H":
            x = (x if rel else 0.0) + num()
            out.append(("line", x, y))
            last_ctrl = None
        elif c == "V":
            y = (y if rel else 0.0) + num()
            out.append(("line", x, y))
            last_ctrl = None
        elif c == "C":
            c1x, c1y, c2x, c2y, ex, ey = ox + num(), oy + num(), ox + num(), oy + num(), ox + num(), oy + num()
            out.append(("cubic", c1x, c1y, c2x, c2y, ex, ey))
            x, y, last_ctrl = ex, ey, ("c", c2x, c2y)
        elif c == "S":
            c1x, c1y = (2 * x - last_ctrl[1], 2 * y - last_ctrl[2]) if last_ctrl and last_ctrl[0] == "c" else (x, y)
            c2x, c2y, ex, ey = ox + num(), oy + num(), ox + num(), oy + num()
            out.append(("cubic", c1x, c1y, c2x, c2y, ex, ey))
            x, y, last_ctrl = ex, ey, ("c", c2x, c2y)
        elif c == "Q":
            qx, qy, ex, ey = ox + num(), oy + num(), ox + num(), oy + num()
            out.append(("quad", qx, qy, ex, ey))
            x, y, last_ctrl = ex, ey, ("q", qx, qy)
        elif c == "T":
            qx, qy = (2 * x - last_ctrl[1], 2 * y - last_ctrl[2]) if last_ctrl and last_ctrl[0] == "q" else (x, y)
            ex, ey = ox + num(), oy + num()
            out.append(("quad", qx, qy, ex, ey))
            x, y, last_ctrl = ex, ey, ("q", qx, qy)
        elif c == "A":
            rx, ry, phi, large, sweep = num(), num(), num(), num(), num()
            ex, ey = ox + num(), oy + num()
            out.extend(arc_to_cubics(x, y, rx, ry, phi, int(large), int(sweep), ex, ey))
            x, y = ex, ey
            last_ctrl = None
        else:
            raise SystemExit(f"unsupported path command {cmd}")
    return out


def element_commands(el):
    tag = el.tag.split("}")[-1]
    a = el.attrib
    f = lambda k, d=0.0: float(a.get(k, d))
    if tag == "path":
        return path_commands(a["d"])
    if tag == "circle":
        r = f("r")
        return [("ellipse", f("cx") - r, f("cy") - r, 2 * r, 2 * r)]
    if tag == "ellipse":
        return [("ellipse", f("cx") - f("rx"), f("cy") - f("ry"), 2 * f("rx"), 2 * f("ry"))]
    if tag == "rect":
        rx = f("rx", a.get("ry", 0))
        ry = f("ry", a.get("rx", 0))
        return [("rect", f("x"), f("y"), f("width"), f("height"), rx, ry)]
    if tag == "line":
        return [("move", f("x1"), f("y1")), ("line", f("x2"), f("y2"))]
    if tag in ("polyline", "polygon"):
        pts = [float(v) for v in re.findall(r"-?\d*\.?\d+", a["points"])]
        cmds = [("move", pts[0], pts[1])] + [("line", pts[k], pts[k + 1]) for k in range(2, len(pts), 2)]
        return cmds + ([("close",)] if tag == "polygon" else [])
    return None


def swift_command(c):
    kind, *v = c
    n = ", ".join(fmt(x) for x in v)
    return {
        "move": f"p.move(to: CGPoint(x: {fmt(v[0])}, y: {fmt(v[1])}))" if kind == "move" else None,
        "line": f"p.addLine(to: CGPoint(x: {fmt(v[0])}, y: {fmt(v[1])}))" if kind == "line" else None,
        "quad": f"p.addQuadCurve(to: CGPoint(x: {fmt(v[2])}, y: {fmt(v[3])}), control: CGPoint(x: {fmt(v[0])}, y: {fmt(v[1])}))" if kind == "quad" else None,
        "cubic": (
            f"p.addCurve(to: CGPoint(x: {fmt(v[4])}, y: {fmt(v[5])}), control1: CGPoint(x: {fmt(v[0])}, y: {fmt(v[1])}), "
            f"control2: CGPoint(x: {fmt(v[2])}, y: {fmt(v[3])}))"
        ) if kind == "cubic" else None,
        "close": "p.closeSubpath()" if kind == "close" else None,
        "ellipse": f"p.addEllipse(in: CGRect(x: {fmt(v[0])}, y: {fmt(v[1])}, width: {fmt(v[2])}, height: {fmt(v[3])}))" if kind == "ellipse" else None,
        "rect": (
            f"p.addRoundedRect(in: CGRect(x: {fmt(v[0])}, y: {fmt(v[1])}, width: {fmt(v[2])}, height: {fmt(v[3])}), "
            f"cornerSize: CGSize(width: {fmt(v[4])}, height: {fmt(v[5])}))"
            if v[4] or v[5]
            else f"p.addRect(CGRect(x: {fmt(v[0])}, y: {fmt(v[1])}, width: {fmt(v[2])}, height: {fmt(v[3])}))"
        ) if kind == "rect" else None,
    }[kind]


def camel(name):
    head, *rest = name.split("-")
    return head + "".join(w.capitalize() for w in rest)


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    src = pathlib.Path(sys.argv[1])
    cases, drawings = [], []
    for name in ICONS:
        found = list(src.rglob(f"{name}.svg"))
        if not found:
            raise SystemExit(f"{name}.svg not found under {src}")
        root = ET.parse(found[0]).getroot()
        elements = []
        for el in root.iter():
            if el is root:
                continue
            cmds = element_commands(el)
            if cmds is None:
                continue
            filled = el.attrib.get("fill") == "currentColor"
            elements.append((cmds, filled))
        cases.append(f"    case {camel(name)}")
        body = []
        for cmds, filled in elements:
            lines = "\n".join(f"                    {swift_command(c)}" for c in cmds)
            body.append(
                f"            AppIconElement(filled: {'true' if filled else 'false'}) {{ p in\n{lines}\n            }},"
            )
        drawings.append(f"        case .{camel(name)}:\n            [\n" + "\n".join(body) + "\n            ]")
    swift = f'''// Generated by Scripts/generate-app-icons.py from @qeetrix/icons' sharp-outline SVGs. Do not edit.
// The icons the screens need that Qeetrix for iOS doesn't have yet; each is a gap recorded for Qeetrix.

import Qeetrix
import SwiftUI

/// An icon Qeetrix for iOS doesn't have yet, drawn from `@qeetrix/icons`' sharp outline.
enum AppIconName: CaseIterable, Sendable {{
{chr(10).join(cases)}
}}

/// One element of an app icon: its path in the 24-unit grid, stroked (or filled, for a dot).
struct AppIconElement: Sendable {{
    let filled: Bool
    let build: @Sendable (inout Path) -> Void

    init(filled: Bool, _ build: @escaping @Sendable (inout Path) -> Void) {{
        self.filled = filled
        self.build = build
    }}

    var path: Path {{
        var p = Path()
        build(&p)
        return p
    }}
}}

extension AppIconName {{
    /// The drawing, as `@qeetrix/icons` draws the sharp outline.
    var elements: [AppIconElement] {{
        switch self {{
{chr(10).join(drawings)}
        }}
    }}
}}

/// An app icon, drawn like a `QeetrixIcon` in the sharp shape: square caps, mitred joins, the regular stroke, in the
/// foreground style, scaling with Dynamic Type. Decorative unless given a label.
struct AppIcon: View {{
    let name: AppIconName
    var size: QeetrixIconSize = .md
    var label: Text?
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    init(_ name: AppIconName, size: QeetrixIconSize = .md, label: Text? = nil) {{
        self.name = name
        self.size = size
        self.label = label
    }}

    var body: some View {{
        let elements = name.elements
        let width = QeetrixIconStroke.regular.width
        let canvas = Canvas {{ context, size in
            let unit = min(size.width, size.height) / 24
            context.scaleBy(x: unit, y: unit)
            for element in elements {{
                if element.filled {{
                    context.fill(element.path, with: .foreground)
                }} else {{
                    context.stroke(
                        element.path, with: .foreground,
                        style: StrokeStyle(lineWidth: width, lineCap: .square, lineJoin: .miter, miterLimit: 4))
                }}
            }}
        }}
        .frame(width: size.points * scale, height: size.points * scale)
        if let label {{
            canvas.accessibilityElement().accessibilityLabel(label).accessibilityAddTraits(.isImage)
        }} else {{
            canvas.accessibilityHidden(true)
        }}
    }}
}}
'''
    OUT.write_text(swift)
    print(f"wrote {OUT} ({len(ICONS)} icons)")


if __name__ == "__main__":
    main()
