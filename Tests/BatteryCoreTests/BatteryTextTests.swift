import XCTest
@testable import BatteryCore

final class BatteryTextTests: XCTestCase {
    private let chinese = BatteryText(language: .chinese)
    private let english = BatteryText(language: .english)

    func testDischargeTimeIsCompactInMenuAndLocalizedInDetails() {
        let snapshot = BatterySnapshot(percent: 65, minutesRemaining: 135)
        XCTAssertEqual(chinese.statusTitle(snapshot: snapshot), "2:15")
        XCTAssertEqual(english.statusTitle(snapshot: snapshot), "2:15")
        XCTAssertEqual(chinese.remainingValue(snapshot: snapshot), "2小时15分钟")
        XCTAssertEqual(english.remainingValue(snapshot: snapshot), "2 hr 15 min")
        XCTAssertEqual(chinese.chargeValue(snapshot: snapshot), "65%")
    }

    func testZeroAndUnknownTimeNeverLookLikeZeroRuntime() {
        for minutes in [nil, 0, -1] as [Int?] {
            let snapshot = BatterySnapshot(percent: 50, minutesRemaining: minutes)
            XCTAssertEqual(chinese.remainingValue(snapshot: snapshot), "估算中…")
            XCTAssertEqual(english.remainingValue(snapshot: snapshot), "Estimating…")
        }
    }

    func testChargingTimeClearlyMeansTimeToFull() {
        let snapshot = BatterySnapshot(percent: 50, isOnAC: true, isCharging: true, minutesToFull: 45)
        XCTAssertEqual(chinese.remainingValue(snapshot: snapshot), "45分钟后充满")
        XCTAssertEqual(english.remainingValue(snapshot: snapshot), "45 min until full")
        XCTAssertEqual(chinese.statusTitle(snapshot: snapshot), "充满 0:45")
        XCTAssertEqual(english.statusTitle(snapshot: snapshot), "Full in 0:45")
    }

    func testChargingUnknownFullAndPausedAreDistinct() {
        let charging = BatterySnapshot(percent: 50, isOnAC: true, isCharging: true)
        let full = BatterySnapshot(percent: 100, isOnAC: true, isCharged: true)
        let paused = BatterySnapshot(percent: 80, isOnAC: true)
        XCTAssertEqual(chinese.remainingValue(snapshot: charging), "正在充电，估算中…")
        XCTAssertEqual(english.remainingValue(snapshot: charging), "Charging, estimating…")
        XCTAssertEqual(chinese.remainingValue(snapshot: full), "已充满")
        XCTAssertEqual(english.remainingValue(snapshot: full), "Fully charged")
        XCTAssertEqual(chinese.remainingValue(snapshot: paused), "已接电，未充电")
        XCTAssertEqual(english.remainingValue(snapshot: paused), "Plugged in, not charging")
    }

    func testUnavailableBatteryDoesNotClaimAnEstimate() {
        XCTAssertEqual(chinese.statusTitle(snapshot: .unavailable), "—")
        XCTAssertEqual(english.chargeValue(snapshot: .unavailable), "—")
        XCTAssertEqual(chinese.remainingValue(snapshot: .unavailable), "不可用")
        XCTAssertEqual(english.remainingValue(snapshot: .unavailable), "Unavailable")
    }

    func testWholeHourAndSubHourFormattingDoesNotAddZeroComponents() {
        XCTAssertEqual(english.remainingValue(snapshot: .init(percent: 50, minutesRemaining: 120)), "2 hr")
        XCTAssertEqual(chinese.remainingValue(snapshot: .init(percent: 50, minutesRemaining: 59)), "59分钟")
    }
}
