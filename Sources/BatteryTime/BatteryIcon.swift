import AppKit
import BatteryCore

enum BatteryIcon {
    private static let bolt = croppedSystemSymbol("bolt.fill")
    private static let plug = croppedSystemSymbol("powerplug.fill")

    static func image(for snapshot: BatterySnapshot, appearance: NSAppearance? = nil) -> NSImage {
        let charging = snapshot.powerSymbol == .bolt
        var foreground = NSColor.black
        if charging {
            // The lightning has two explicit colors, so the surrounding battery
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
                    let border: CGFloat = 0.75
                    for index in 0..<24 {
                        let angle = CGFloat(index) * .pi * 2 / 24
                        bolt.draw(in: target.offsetBy(dx: cos(angle) * border, dy: sin(angle) * border))
                    }
                    drawWhite(bolt, in: target)
                }
            case .plug:
                if let plug {
                    // SF Symbols' plug points right; the menu-bar plug points up.
                    NSGraphicsContext.saveGraphicsState()
                    let transform = NSAffineTransform()
                    transform.translateX(by: bounds.midX, yBy: bounds.midY)
                    transform.rotate(byDegrees: 90)
                    transform.concat()
                    let height: CGFloat = 10.5
                    let width = height * plug.size.height / plug.size.width
                    plug.draw(in: NSRect(x: -height / 2, y: -width / 2, width: height, height: width),
                              from: .zero, operation: .destinationOut, fraction: 1,
                              respectFlipped: false, hints: nil)
                    NSGraphicsContext.restoreGraphicsState()
                }
            }
            return true
        }
        image.isTemplate = !charging && snapshot.tint == .normal
        return image
    }

    private static func drawWhite(_ symbol: NSImage, in target: NSRect) {
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
