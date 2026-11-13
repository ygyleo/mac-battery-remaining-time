import AppKit
import BatteryCore

enum BatteryIcon {
    static func image(for snapshot: BatterySnapshot) -> NSImage {
        let symbolName: String?
        switch snapshot.powerSymbol {
        case .none: symbolName = nil
        case .bolt: symbolName = "bolt.fill"
        case .plug: symbolName = "powerplug.fill"
        }
        let symbol = symbolName.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        let image = NSImage(size: NSSize(width: 25, height: 14), flipped: false) { _ in
            let color: NSColor
            switch snapshot.tint {
            case .normal: color = .black
            case .yellow: color = .systemYellow
            case .red: color = .systemRed
            }

            // Match the filled silhouette of the macOS menu-bar battery. The
            // translucent portion is the empty charge, including while on AC.
            let bounds = NSRect(x: 0, y: 1, width: 22.5, height: 12)
            let body = NSBezierPath(roundedRect: bounds, xRadius: 3.5, yRadius: 3.5)
            color.withAlphaComponent(0.4).setFill()
            body.fill()
            NSBezierPath(roundedRect: NSRect(x: 23.3, y: 4.5, width: 1.5, height: 5),
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
            if let symbol {
                // Knock the system glyph out of the battery, preserving the
                // charge boundary and contrast on light and dark menu bars.
                let height: CGFloat = snapshot.powerSymbol == .bolt ? 10 : 8
                let width = height * symbol.size.width / symbol.size.height
                let target = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                                    width: width, height: height)
                symbol.draw(in: target, from: .zero, operation: .destinationOut, fraction: 1,
                            respectFlipped: false, hints: nil)
            }
            return true
        }
        image.isTemplate = snapshot.tint == .normal
        return image
    }
}
