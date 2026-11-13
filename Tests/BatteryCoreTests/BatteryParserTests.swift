import XCTest
@testable import BatteryCore

final class BatteryParserTests: XCTestCase {
    private func battery(_ overrides: [String: Any] = [:]) -> [String: Any] {
        ["Type": "InternalBattery", "Is Present": true,
         "Current Capacity": 50, "Max Capacity": 100,
         "Power Source State": "Battery Power", "Is Charging": false,
         "Is Charged": false, "Time to Empty": 135, "Time to Full Charge": -1]
            .merging(overrides) { _, new in new }
    }

    func testUsesInternalBatteryAndCapacityRatioInsteadOfUPS() {
        let ups = battery(["Type": "UPS", "Current Capacity": 1])
        let result = BatteryParser.parse([ups, battery(["Current Capacity": 3000, "Max Capacity": 4000])])
        XCTAssertEqual(result.percent, 75)
        XCTAssertEqual(result.minutesRemaining, 135)
        XCTAssertFalse(result.isOnAC)
    }

    func testSkipsAbsentBatteryAndReturnsUnavailableWithoutInternalBattery() {
        XCTAssertEqual(BatteryParser.parse([battery(["Is Present": false])]), .unavailable)
        XCTAssertEqual(BatteryParser.parse([battery(["Type": "UPS"])]), .unavailable)
        XCTAssertEqual(BatteryParser.parse([]), .unavailable)
    }

    func testACStateDiscardsStaleDischargeEstimateAndUsesChargeTime() {
        let result = BatteryParser.parse([battery(["Power Source State": "AC Power", "Is Charging": true,
                                                    "Time to Full Charge": 45])], fallbackMinutes: 600)
        XCTAssertTrue(result.isOnAC)
        XCTAssertTrue(result.isCharging)
        XCTAssertEqual(result.minutesToFull, 45)
        XCTAssertNil(result.minutesRemaining)
    }

    func testBatteryStateDiscardsStaleChargeTime() {
        let result = BatteryParser.parse([battery(["Time to Full Charge": 45])])
        XCTAssertNil(result.minutesToFull)
    }

    func testUnknownAndZeroEstimateUsePositiveFallbackWithoutShowingZero() {
        for estimate in [-1, 0] {
            let result = BatteryParser.parse([battery(["Time to Empty": estimate])], fallbackMinutes: 200)
            XCTAssertEqual(result.minutesRemaining, 200)
            XCTAssertNil(BatteryParser.parse([battery(["Time to Empty": estimate])]).minutesRemaining)
        }
        XCTAssertNil(BatteryParser.parse([battery(["Time to Empty": -1])], fallbackMinutes: -1).minutesRemaining)
    }

    func testRejectsInvalidCapacityWithoutCrashing() {
        for invalid in [0.0, -1.0, Double.infinity, Double.nan, Double.greatestFiniteMagnitude] {
            XCTAssertNil(BatteryParser.parse([battery(["Max Capacity": invalid])]).percent)
        }
        for invalid in [true, "50", -1, Double.infinity, Double.nan] as [Any] {
            XCTAssertNil(BatteryParser.parse([battery(["Current Capacity": invalid])]).percent)
        }
    }

    func testCapacityIsRoundedAndClampedForTransientOverCapacityReading() {
        XCTAssertEqual(BatteryParser.parse([battery(["Current Capacity": 2, "Max Capacity": 3])]).percent, 67)
        XCTAssertEqual(BatteryParser.parse([battery(["Current Capacity": 101])]).percent, 100)
        XCTAssertEqual(BatteryParser.parse([battery(["Current Capacity": 0])]).percent, 0)
    }

    func testInvalidTimeDoesNotTrapOrBecomeAValidEstimate() {
        for invalid in [true, "90", Double.infinity, Double.nan, Double.greatestFiniteMagnitude] as [Any] {
            XCTAssertNil(BatteryParser.parse([battery(["Time to Empty": invalid])]).minutesRemaining)
        }
    }

    func testCriticalAndLowBatteryBoundariesAndACOverride() {
        XCTAssertEqual(BatterySnapshot(percent: 10).tint, .red)
        XCTAssertEqual(BatterySnapshot(percent: 11).tint, .yellow)
        XCTAssertEqual(BatterySnapshot(percent: 20).tint, .yellow)
        XCTAssertEqual(BatterySnapshot(percent: 21).tint, .normal)
        XCTAssertEqual(BatterySnapshot(percent: 5, isOnAC: true).tint, .normal)
        XCTAssertEqual(BatterySnapshot.unavailable.tint, .normal)
    }
}
