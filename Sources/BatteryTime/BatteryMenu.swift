import AppKit
import BatteryCore

/// Two readable data rows, with a charging action only when it is available.
final class BatteryMenu: NSObject {
    let menu = NSMenu()
    private let rows = [BatteryMenuRow(), BatteryMenuRow()]
    private let chargeItem = NSMenuItem()
    private var chargeAction: (() -> Void)?

    func setChargeAction(title: String?, enabled: Bool = true, onClick: @escaping () -> Void) {
        guard let title else {
            while menu.items.count > 2 { menu.removeItem(at: 2) }
            chargeAction = nil
            return
        }
        if menu.items.count == 2 {
            menu.addItem(.separator())
            menu.addItem(chargeItem)
        }
        chargeItem.title = title
        chargeItem.isEnabled = enabled
        chargeAction = onClick
    }

    override init() {
        super.init()
        menu.autoenablesItems = false
        chargeItem.target = self
        chargeItem.action = #selector(chargeToFull)
        for row in rows {
            let item = NSMenuItem()
            item.isEnabled = false
            item.view = row
            menu.addItem(item)
        }
    }

    @objc private func chargeToFull() { chargeAction?() }

    func update(snapshot: BatterySnapshot, text: BatteryText) {
        rows[0].setContent(label: text.chargeLabel, value: text.chargeValue(snapshot: snapshot))
        rows[1].setContent(label: text.remainingLabel, value: text.remainingValue(snapshot: snapshot))
        let labelWidth = ceil(rows.map { $0.labelField.fittingSize.width }.max() ?? 0)
        let valueWidth = ceil(rows.map { $0.valueField.fittingSize.width }.max() ?? 0)
        for (item, row) in zip(menu.items, rows) {
            row.arrange(labelWidth: labelWidth, valueWidth: valueWidth)
            item.title = row.labelField.stringValue + ": " + row.valueField.stringValue
            item.setAccessibilityLabel(item.title)
        }
    }
}

final class BatteryMenuRow: NSView {
    let labelField = NSTextField(labelWithString: "")
    let valueField = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        labelField.font = .menuFont(ofSize: 13)
        valueField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        for field in [labelField, valueField] {
            field.textColor = .labelColor
            field.isSelectable = false
            field.lineBreakMode = .byClipping
            field.maximumNumberOfLines = 1
            addSubview(field)
        }
        valueField.alignment = .right
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setContent(label: String, value: String) {
        labelField.stringValue = label
        valueField.stringValue = value
    }

    func arrange(labelWidth: CGFloat, valueWidth: CGFloat) {
        let padding: CGFloat = 12
        let gap: CGFloat = 14
        let height: CGFloat = 24
        frame.size = NSSize(width: padding * 2 + labelWidth + gap + valueWidth, height: height)
        for (field, x, width) in [(labelField, padding, labelWidth),
                                  (valueField, padding + labelWidth + gap, valueWidth)] {
            let fieldHeight = ceil(field.fittingSize.height)
            field.frame = NSRect(x: x, y: floor((height - fieldHeight) / 2), width: width, height: fieldHeight)
        }
    }
}
