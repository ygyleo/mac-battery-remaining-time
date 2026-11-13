import AppKit
import BatteryCore
import CoreServices
import notify
import XCTest
@testable import BatteryAppSupport

final class BatteryAppTests: XCTestCase {
    func testChargingBoltKeepsWhiteFillBlackBorderAndExtendsPastBattery() {
        let image = BatteryIcon.image(for: BatterySnapshot(percent: 74, isOnAC: true, isCharging: true),
                                      appearance: NSAppearance(named: .darkAqua))
        XCTAssertFalse(image.isTemplate, "Template tinting would erase the white fill and black border")
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 50, pixelsHigh: 36,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: 50, height: 36))
        NSGraphicsContext.restoreGraphicsState()
        var whiteOutsideBattery = 0
        var blackBorder = 0
        for y in 0..<36 {
            for x in 0..<50 {
                let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                guard color.alphaComponent > 0.9 else { continue }
                if color.redComponent > 0.95 && color.greenComponent > 0.95 && color.blueComponent > 0.95,
                   y < 6 || y >= 30 { whiteOutsideBattery += 1 }
                if color.redComponent < 0.1 && color.greenComponent < 0.1 && color.blueComponent < 0.1 {
                    blackBorder += 1
                }
            }
        }
        XCTAssertGreaterThan(whiteOutsideBattery, 0)
        XCTAssertGreaterThan(blackBorder, 0)
    }

    func testChargingNotificationUpdatesSymbolWithoutCapacityOrEstimateChange() {
        let notificationName = "io.github.ygyleo.BatteryTime.tests.\(UUID().uuidString)"
        var reading = BatterySnapshot(percent: 74, isOnAC: true)
        let monitor = BatteryMonitor(readSnapshot: { reading }, notificationName: notificationName)
        XCTAssertEqual(monitor.snapshot.powerSymbol, .plug)
        let changed = expectation(description: "Charging-only change refreshes immediately")
        monitor.onChange = { snapshot in
            XCTAssertEqual(snapshot.powerSymbol, .bolt)
            XCTAssertEqual(snapshot.percent, 74)
            changed.fulfill()
        }
        // Repeated identical readings must not redraw the status item.
        monitor.refresh()
        reading = BatterySnapshot(percent: 74, isOnAC: true, isCharging: true)
        XCTAssertEqual(notify_post(notificationName), UInt32(NOTIFY_STATUS_OK))
        wait(for: [changed], timeout: 2)
        XCTAssertEqual(monitor.snapshot.powerSymbol, .bolt)
    }

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
