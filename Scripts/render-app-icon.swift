#!/usr/bin/env swift
// Renders the app icon (QeetID/Resources/Assets.xcassets/AppIcon.appiconset) from the brand's geometry: a white disc
// with a keyhole cut out, on the Qeet orange gradient (#DA653A → #D04800 → #9B3314), in a 100-unit box. iOS masks
// the square itself. Light and dark are the same, as every Qeet app icon stays orange; tinted is the white mark on
// black, which iOS tints.
//
//     swift Scripts/render-app-icon.swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let folder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("QeetID/Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// The keyhole disc in the 100-unit box: disc r 29 at (50, 50); the keyhole's head r 8.5 at (50, 43), its stem to y 64.5.
func mark() -> CGPath {
    let path = CGMutablePath()
    path.addEllipse(in: CGRect(x: 21, y: 21, width: 58, height: 58))
    // The keyhole, as the brand's path draws it: M46.2 50.6 L43.5 64.5 H56.5 L53.8 50.6 A8.5 8.5 0 1 0 46.2 50.6 Z.
    let head = CGPoint(x: 50, y: 43)
    let start = atan2(50.6 - head.y, 53.8 - head.x)
    let end = atan2(50.6 - head.y, 46.2 - head.x)
    path.move(to: CGPoint(x: 46.2, y: 50.6))
    path.addLine(to: CGPoint(x: 43.5, y: 64.5))
    path.addLine(to: CGPoint(x: 56.5, y: 64.5))
    path.addLine(to: CGPoint(x: 53.8, y: 50.6))
    // The large arc over the top, from the stem's right edge back to its left (counter-clockwise on screen).
    path.addArc(center: head, radius: 8.5, startAngle: start, endAngle: end, clockwise: true)
    path.closeSubpath()
    return path
}

func render(_ name: String, gradient: Bool) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard
        let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fatalError("no context") }
    // Top-left origin, 100 units across, as the SVG.
    context.translateBy(x: 0, y: CGFloat(side))
    context.scaleBy(x: CGFloat(side) / 100, y: -CGFloat(side) / 100)
    if gradient {
        let colors = [color(0xDA653A), color(0xD04800), color(0x9B3314)] as CFArray
        let fill = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1])!
        context.drawLinearGradient(
            fill, start: CGPoint(x: 20, y: 0), end: CGPoint(x: 80, y: 100),
            // Pad past both ends, as the SVG gradient does, so the corners take the end colours.
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    } else {
        context.setFillColor(color(0x000000))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    context.addPath(mark())
    context.setFillColor(color(0xFFFFFF))
    context.fillPath(using: .evenOdd)
    let image = context.makeImage()!
    let url = folder.appendingPathComponent(name)
    guard let out = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("can't write \(url.path)")
    }
    CGImageDestinationAddImage(out, image, nil)
    guard CGImageDestinationFinalize(out) else { fatalError("can't write \(url.path)") }
    print("wrote \(url.lastPathComponent)")
}

// The disc is filled; the keyhole's head, the stem and the gap between them are cut out.
let check = mark()
precondition(check.contains(CGPoint(x: 50, y: 25), using: .evenOdd), "the disc above the keyhole is filled")
precondition(check.contains(CGPoint(x: 30, y: 50), using: .evenOdd), "the disc beside the keyhole is filled")
for hole in [CGPoint(x: 50, y: 36), CGPoint(x: 50, y: 43), CGPoint(x: 50, y: 52), CGPoint(x: 50, y: 63)] {
    precondition(!check.contains(hole, using: .evenOdd), "the keyhole is cut out at \(hole)")
}

try render("app-icon-1024.png", gradient: true)
try render("app-icon-dark-1024.png", gradient: true)
try render("app-icon-tinted-1024.png", gradient: false)
