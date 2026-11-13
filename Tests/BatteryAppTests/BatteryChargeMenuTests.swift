import AppKit
import BatteryCore
import XCTest
@testable import BatteryAppSupport

final class BatteryChargeMenuTests: XCTestCase {
    func testConditionalChargeActionCanBeInvokedAndRemovedWithoutAddingSettings() {
        _ = NSApplication.shared
        let menu = BatteryMenu()
        menu.update(snapshot: BatterySnapshot(percent: 80, isOnAC: true),
                    text: BatteryText(language: .chinese))
        var calls = 0
        menu.setChargeAction(title: "立即充满", onClick: { calls += 1 })
        XCTAssertEqual(menu.menu.items.count, 4)
        guard let action = menu.menu.items.last, action.action != nil else {
            return XCTFail("The charging action must be available below the two readings")
        }
        menu.menu.performActionForItem(at: 3)
        XCTAssertEqual(calls, 1)
        menu.setChargeAction(title: "已请求充满", enabled: false, onClick: { calls += 1 })
        XCTAssertFalse(action.isEnabled)
        menu.setChargeAction(title: nil, onClick: {})
        XCTAssertEqual(menu.menu.items.count, 2)
        XCTAssertTrue(menu.menu.items.allSatisfy { $0.view is BatteryMenuRow })
    }
}
