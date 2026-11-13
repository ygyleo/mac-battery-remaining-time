import AppKit
import BatteryCore

enum BatteryIcon {
    static func image(for snapshot: BatterySnapshot) -> NSImage {
        let hasColor = snapshot.tint != .normal
        let image = NSImage(size: NSSize(width: 27, height: 14), flipped: false) { rect in
            let color: NSColor
            switch snapshot.tint {
            case .normal: color = .black
            case .yellow: color = .systemYellow
            case .red: color = .systemRed
            }
            color.setStroke()
            let body = NSBezierPath(roundedRect: NSRect(x: 0.75, y: 1.5, width: 23, height: 11), xRadius: 2.5, yRadius: 2.5)
            body.lineWidth = 1.2
            body.stroke()
            color.withAlphaComponent(0.65).setFill()
            NSBezierPath(roundedRect: NSRect(x: 24.7, y: 4.5, width: 1.8, height: 5), xRadius: 0.9, yRadius: 0.9).fill()
            if snapshot.isOnAC {
                // A small plug inside the native-proportioned battery silhouette.
                color.setFill()
                NSBezierPath(roundedRect: NSRect(x: 9, y: 4, width: 7, height: 4.5), xRadius: 1.5, yRadius: 1.5).fill()
                NSBezierPath(rect: NSRect(x: 10, y: 8, width: 1.5, height: 2.5)).fill()
                NSBezierPath(rect: NSRect(x: 13.5, y: 8, width: 1.5, height: 2.5)).fill()
                NSBezierPath(rect: NSRect(x: 11.8, y: 2.6, width: 1.5, height: 2.4)).fill()
            } else if let percent = snapshot.percent, percent > 0 {
                color.setFill()
                let width = max(1.3, 19 * CGFloat(percent) / 100)
                NSBezierPath(roundedRect: NSRect(x: 2.75, y: 3.5, width: width, height: 7), xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = !hasColor
        return image
    }
}
