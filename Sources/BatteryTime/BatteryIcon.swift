import AppKit
import BatteryCore

enum BatteryIcon {
    private static let bolt = croppedSystemSymbol("bolt.fill")

    static func image(for snapshot: BatterySnapshot, appearance: NSAppearance? = nil) -> NSImage {
        let hasPowerBadge = snapshot.powerSymbol != .none
        var foreground = NSColor.black
        if hasPowerBadge {
            // Both power badges have two colors, so the surrounding battery
            // uses the status button's appearance instead of template tinting.
            (appearance ?? NSAppearance.currentDrawing()).performAsCurrentDrawingAppearance {
                foreground = NSColor.labelColor.usingColorSpace(.deviceRGB) ?? .black
            }
        }
        let image = NSImage(size: NSSize(width: 25, height: 18), flipped: false) { _ in
            let color: NSColor
            switch snapshot.tint {
            case .normal: color = foreground
            case .yellow: color = .systemYellow
            case .red: color = .systemRed
            }

            let bounds = NSRect(x: 0, y: 3, width: 22.5, height: 12)
            let body = NSBezierPath(roundedRect: bounds, xRadius: 3.5, yRadius: 3.5)
            color.withAlphaComponent(0.4).setFill()
            body.fill()
            NSBezierPath(roundedRect: NSRect(x: 23.3, y: 6.5, width: 1.5, height: 5),
                         xRadius: 0.75, yRadius: 0.75).fill()
            if let percent = snapshot.percent, percent > 0 {
                NSGraphicsContext.saveGraphicsState()
                body.addClip()
                color.setFill()
                let fraction = CGFloat(min(100, max(0, percent))) / 100
                NSBezierPath(rect: NSRect(x: bounds.minX, y: bounds.minY,
                                         width: bounds.width * fraction, height: bounds.height)).fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            switch snapshot.powerSymbol {
            case .none:
                break
            case .bolt:
                if let bolt {
                    // Native charging is a white bolt with a black border. Its
                    // silhouette extends above and below the battery body.
                    let height: CGFloat = 16
                    let width = height * bolt.size.width / bolt.size.height
                    let target = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                                        width: width, height: height)
                    drawOutlinedWhite(bolt, in: target, border: 0.75)
                }
            case .plug:
                // The menu-bar plug has shorter prongs and a narrower stem
                // than powerplug.fill. Its 14 pt core extends beyond the battery.
                let plug = nativePlugPath(in: NSRect(x: bounds.midX - 4.375,
                                                     y: bounds.midY - 7,
                                                     width: 8.75, height: 14))
                plug.lineWidth = 2
                plug.lineJoinStyle = .round
                NSColor.black.setStroke()
                plug.stroke()
                NSColor(deviceWhite: 234.0 / 255.0, alpha: 1).setFill()
                plug.fill()
            }
            return true
        }
        image.isTemplate = !hasPowerBadge && snapshot.tint == .normal
        return image
    }

    private static func nativePlugPath(in target: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: target.midX + x * target.width / 8.75,
                    y: target.minY + y * target.height / 14)
        }

        // Coordinates describe the visible fill, before the 1 pt outer border.
        path.move(to: point(-4.075, 11.5))
        path.line(to: point(-2.65, 11.5))
        path.line(to: point(-2.65, 13.85))
        path.curve(to: point(-2.5, 14), controlPoint1: point(-2.65, 13.95),
                   controlPoint2: point(-2.6, 14))
        path.line(to: point(-0.95, 14))
        path.curve(to: point(-0.8, 13.85), controlPoint1: point(-0.85, 14),
                   controlPoint2: point(-0.8, 13.95))
        path.line(to: point(-0.8, 11.5))
        path.line(to: point(0.8, 11.5))
        path.line(to: point(0.8, 13.85))
        path.curve(to: point(0.95, 14), controlPoint1: point(0.8, 13.95),
                   controlPoint2: point(0.85, 14))
        path.line(to: point(2.5, 14))
        path.curve(to: point(2.65, 13.85), controlPoint1: point(2.6, 14),
                   controlPoint2: point(2.65, 13.95))
        path.line(to: point(2.65, 11.5))
        path.line(to: point(4.075, 11.5))
        path.curve(to: point(4.375, 11.2), controlPoint1: point(4.275, 11.5),
                   controlPoint2: point(4.375, 11.4))
        path.line(to: point(4.375, 9))
        path.curve(to: point(1.25, 4.807), controlPoint1: point(4.375, 7.065),
                   controlPoint2: point(3.105, 5.36))
        path.line(to: point(1.25, 0.4))
        path.curve(to: point(0.85, 0), controlPoint1: point(1.25, 0.135),
                   controlPoint2: point(1.115, 0))
        path.line(to: point(-0.85, 0))
        path.curve(to: point(-1.25, 0.4), controlPoint1: point(-1.115, 0),
                   controlPoint2: point(-1.25, 0.135))
        path.line(to: point(-1.25, 4.807))
        path.curve(to: point(-4.375, 9), controlPoint1: point(-3.105, 5.36),
                   controlPoint2: point(-4.375, 7.065))
        path.line(to: point(-4.375, 11.2))
        path.curve(to: point(-4.075, 11.5), controlPoint1: point(-4.375, 11.4),
                   controlPoint2: point(-4.275, 11.5))
        path.close()
        return path
    }

    private static func drawOutlinedWhite(_ symbol: NSImage, in target: NSRect, border: CGFloat) {
        for index in 0..<24 {
            let angle = CGFloat(index) * .pi * 2 / 24
            symbol.draw(in: target.offsetBy(dx: cos(angle) * border, dy: sin(angle) * border))
        }
        let white = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSColor.white.setFill()
            rect.fill(using: .sourceIn)
            return true
        }
        white.draw(in: target)
    }

    /// System symbol images include typographic padding. Trim that padding once
    /// so the requested badge size describes its visible ink, not its layout box.
    private static func croppedSystemSymbol(_ name: String) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil),
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 128, pixelsHigh: 128,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB,
                                            bitmapFormat: [], bytesPerRow: 512, bitsPerPixel: 32) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let scale = 128 / max(symbol.size.width, symbol.size.height)
        symbol.draw(in: NSRect(x: 0, y: 0, width: symbol.size.width * scale,
                              height: symbol.size.height * scale))
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: 128, height: 128).fill(using: .sourceIn)
        NSGraphicsContext.restoreGraphicsState()
        guard let pixels = bitmap.bitmapData else { return nil }
        var minX = 128, minY = 128, maxX = -1, maxY = -1
        for y in 0..<128 {
            for x in 0..<128 where pixels[y * bitmap.bytesPerRow + x * 4 + 3] > 0 {
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let cropped = bitmap.cgImage?.cropping(to: CGRect(x: minX, y: minY,
                                                               width: maxX - minX + 1,
                                                               height: maxY - minY + 1)) else { return nil }
        let result = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        result.isTemplate = false
        return result
    }
}
