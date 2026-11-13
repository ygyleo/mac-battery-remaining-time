import AppKit
import BatteryCore
import CoreServices
import XCTest
@testable import BatteryAppSupport

final class BatteryAppTests: XCTestCase {
    func testTimeVisibilityDefaultsOnAndPersistsAnExplicitOff() {
        let suite = "BatteryTimeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        XCTAssertTrue(preferences.showTimeInMenuBar)
        preferences.showTimeInMenuBar = false
        XCTAssertFalse(Preferences(defaults: defaults).showTimeInMenuBar)
        preferences.showTimeInMenuBar = true
        XCTAssertTrue(Preferences(defaults: defaults).showTimeInMenuBar)
    }

    func testChineseMenuHasOnlyTwoReadableCompactDataRows() {
        let batteryMenu = BatteryMenu()
        batteryMenu.update(snapshot: BatterySnapshot(percent: 75), text: BatteryText(language: .chinese))
        XCTAssertEqual(batteryMenu.menu.items.count, 2)
        XCTAssertTrue(batteryMenu.menu.items.allSatisfy { $0.action == nil && !$0.isSeparatorItem })
        let rows = batteryMenu.menu.items.compactMap { $0.view as? BatteryMenuRow }
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.frame.width < 220 && $0.frame.height <= 26 })
        XCTAssertEqual(rows[0].valueField.stringValue, "75%")
        XCTAssertEqual(rows[1].valueField.stringValue, "估算中…")
        for row in rows {
            XCTAssertEqual(row.labelField.textColor, .labelColor)
            XCTAssertGreaterThanOrEqual(row.valueField.frame.minX - row.labelField.frame.maxX, 12)
        }
    }

    func testEnglishChargeStatusFitsWithoutOverlappingOrTruncation() {
        let batteryMenu = BatteryMenu()
        batteryMenu.update(snapshot: BatterySnapshot(percent: 42, isOnAC: true),
                           text: BatteryText(language: .english))
        for item in batteryMenu.menu.items {
            let row = item.view as! BatteryMenuRow
            XCTAssertGreaterThanOrEqual(row.valueField.frame.width, row.valueField.fittingSize.width.rounded(.up))
            XCTAssertGreaterThanOrEqual(row.valueField.frame.minX - row.labelField.frame.maxX, 12)
            XCTAssertLessThan(row.frame.width, 340)
        }
    }

    func testManualLaunchShowsSettingsButLoginLaunchStaysInMenuBar() {
        XCTAssertTrue(LaunchContext.shouldOpenSettings(for: nil))
        let manual = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass),
                                           eventID: AEEventID(kAEOpenApplication),
                                           targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                           transactionID: AETransactionID(kAnyTransactionID))
        XCTAssertTrue(LaunchContext.shouldOpenSettings(for: manual))
        manual.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)), forKeyword: AEKeyword(keyAEPropData))
        XCTAssertFalse(LaunchContext.shouldOpenSettings(for: manual))
        manual.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsServiceItem)), forKeyword: AEKeyword(keyAEPropData))
        XCTAssertFalse(LaunchContext.shouldOpenSettings(for: manual))
    }
}
