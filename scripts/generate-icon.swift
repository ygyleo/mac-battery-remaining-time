#!/usr/bin/env swift
import AppKit
import Foundation

// A self-contained, vector-drawn icon. Run from anywhere; no downloaded assets.
let scriptURL = URL(fileURLWithPath: #filePath).standardizedFileURL
let root = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("Resources/Assets.xcassets")
let appIcon = assets.appendingPathComponent("AppIcon.appiconset")
let docs = root.appendingPathComponent("docs/assets")
let manager = FileManager.default
try manager.createDirectory(at: appIcon, withIntermediateDirectories: true)
try manager.createDirectory(at: docs, withIntermediateDirectories: true)

func drawIcon() {
    let background = NSBezierPath(roundedRect: NSRect(x: 88, y: 88, width: 848, height: 848),
                                  xRadius: 190, yRadius: 190)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
    background.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    background.addClip()
    NSGradient(starting: NSColor(calibratedWhite: 0.96, alpha: 1),
               ending: NSColor(calibratedWhite: 0.85, alpha: 1))!
        .draw(in: background.bounds, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.7).setStroke()
    background.lineWidth = 2
    background.stroke()

    let ink = NSColor(calibratedRed: 0.25, green: 0.27, blue: 0.29, alpha: 1)
    let battery = NSBezierPath(roundedRect: NSRect(x: 218, y: 349, width: 552, height: 326),
                               xRadius: 69, yRadius: 69)
    ink.setStroke()
    battery.lineWidth = 32
    battery.stroke()

    ink.setFill()
    NSBezierPath(roundedRect: NSRect(x: 797, y: 459, width: 28, height: 106),
                 xRadius: 14, yRadius: 14).fill()

    let clock = NSBezierPath(ovalIn: NSRect(x: 391, y: 410, width: 204, height: 204))
    clock.lineWidth = 22
    clock.stroke()
    let hands = NSBezierPath()
    hands.lineCapStyle = .round
    hands.lineJoinStyle = .round
    hands.lineWidth = 22
    hands.move(to: NSPoint(x: 493, y: 572))
    hands.line(to: NSPoint(x: 493, y: 512))
    hands.line(to: NSPoint(x: 536, y: 485))
    hands.stroke()
}

func writePNG(size: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size,
                                        pixelsHigh: size, bitsPerSample: 8,
                                        samplesPerPixel: 4, hasAlpha: true,
                                        isPlanar: false, colorSpaceName: .deviceRGB,
                                        bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create icon bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode icon PNG")
    }
    try data.write(to: url)
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try writePNG(size: points * scale, to: appIcon.appendingPathComponent(filename))
        images.append(["idiom": "mac", "size": "\(points)x\(points)",
                       "scale": "\(scale)x", "filename": filename])
    }
}
let metadata: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    .write(to: appIcon.appendingPathComponent("Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": ["author": "xcode", "version": 1]],
                           options: [.prettyPrinted, .sortedKeys])
    .write(to: assets.appendingPathComponent("Contents.json"))
try writePNG(size: 1024, to: docs.appendingPathComponent("icon.png"))
print("Generated macOS app icons and docs/assets/icon.png")
