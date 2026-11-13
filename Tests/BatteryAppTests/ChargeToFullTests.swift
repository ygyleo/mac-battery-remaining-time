import BatteryCore
import Foundation
import XCTest
@testable import BatteryAppSupport

final class ChargeToFullTests: XCTestCase {
    func testOnlyActualProtectionOffersActionAndRefreshNeverWrites() {
        let service = FakeChargingService()
        let battery = LockedBattery(BatterySnapshot(percent: 80, isOnAC: true))
        let controller = ChargeToFullController(service: service, readBattery: { battery.value })
        refresh(controller, expecting: .hidden)
        service.state = ChargingState(obcOverrideAllowed: true, manualLimit: nil)
        refresh(controller, expecting: .available(.optimized))
        service.state = ChargingState(obcOverrideAllowed: false, manualLimit: 80)
        refresh(controller, expecting: .available(.limit))
        for snapshot in [BatterySnapshot(), BatterySnapshot(percent: 80),
                         BatterySnapshot(percent: 100, isOnAC: true),
                         BatterySnapshot(percent: 80, isOnAC: true, isCharging: true),
                         BatterySnapshot(percent: 80, isOnAC: true, isCharged: true),
                         BatterySnapshot(percent: 79, isOnAC: true),
                         BatterySnapshot(percent: -1, isOnAC: true),
                         BatterySnapshot(percent: 101, isOnAC: true)] {
            battery.value = snapshot
            refresh(controller, expecting: .hidden)
        }
        XCTAssertEqual(service.requests.count, 0)
    }

    func testReadFailureHidesActionWithoutWritingOrShowingAnActionError() {
        let service = FakeChargingService()
        service.readError = TestError.failed
        let controller = ChargeToFullController(service: service, readBattery: { .init(percent: 80, isOnAC: true) })
        controller.onError = { _ in XCTFail("Passive reads must not present an alert") }
        refresh(controller, expecting: .hidden)
        XCTAssertTrue(service.requests.isEmpty)
    }

    func testChangedLimitRejectsStaleActionWithoutWriting() {
        let service = FakeChargingService()
        service.state = .init(obcOverrideAllowed: false, manualLimit: 80)
        let controller = ChargeToFullController(service: service, readBattery: { .init(percent: 95, isOnAC: true) })
        refresh(controller, expecting: .available(.limit))
        service.state = .init(obcOverrideAllowed: false, manualLimit: 90)
        let rejected = expectation(description: "Changed limit is rejected")
        controller.onError = { _ in rejected.fulfill() }
        controller.request()
        wait(for: [rejected], timeout: 2)
        XCTAssertTrue(service.requests.isEmpty)
        XCTAssertEqual(controller.presentation, .hidden)
    }

    func testBatteryIsReadAgainAfterServiceQueryBeforeWriting() {
        let service = FakeChargingService()
        service.state = .init(obcOverrideAllowed: true, manualLimit: nil)
        let battery = LockedBattery(.init(percent: 80, isOnAC: true))
        let controller = ChargeToFullController(service: service, readBattery: { battery.value })
        refresh(controller, expecting: .available(.optimized))
        service.beforeReadReturn = { battery.value = .init(percent: 80) }
        let rejected = expectation(description: "Unplugged battery is rejected")
        controller.onError = { _ in rejected.fulfill() }
        controller.request()
        wait(for: [rejected], timeout: 2)
        XCTAssertTrue(service.requests.isEmpty)
    }

    func testDuplicateClicksAndRefreshSendOnlyOneRequestUntilHoldEnds() {
        let service = FakeChargingService()
        service.state = .init(obcOverrideAllowed: true, manualLimit: nil)
        let battery = LockedBattery(.init(percent: 80, isOnAC: true))
        let controller = ChargeToFullController(service: service, readBattery: { battery.value })
        refresh(controller, expecting: .available(.optimized))
        let requested = expectation(description: "Request accepted")
        controller.onChange = {
            XCTAssertTrue(Thread.isMainThread)
            if controller.presentation == .requested { requested.fulfill() }
        }
        controller.request()
        controller.request()
        controller.refresh()
        wait(for: [requested], timeout: 2)
        refresh(controller, expecting: .requested)
        controller.request()
        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(service.requests.first?.0, .optimized)
        XCTAssertNil(service.requests.first?.1)
        battery.value = .init(percent: 80, isOnAC: true, isCharging: true)
        refresh(controller, expecting: .hidden)
    }

    func testManualLimitRequestRetainsExactShownLimit() {
        let service = FakeChargingService()
        service.state = .init(obcOverrideAllowed: false, manualLimit: 85)
        let controller = ChargeToFullController(service: service, readBattery: { .init(percent: 85, isOnAC: true) })
        refresh(controller, expecting: .available(.limit))
        let requested = expectation(description: "Limit request accepted")
        controller.onChange = { if controller.presentation == .requested { requested.fulfill() } }
        controller.request()
        wait(for: [requested], timeout: 2)
        XCTAssertEqual(service.requests.first?.0, .limit)
        XCTAssertEqual(service.requests.first?.1, 85)
    }

    func testRequestFailureReportsErrorWithoutClaimingSuccess() {
        let service = FakeChargingService()
        service.state = .init(obcOverrideAllowed: true, manualLimit: nil)
        service.requestError = TestError.failed
        let controller = ChargeToFullController(service: service, readBattery: { .init(percent: 80, isOnAC: true) })
        refresh(controller, expecting: .available(.optimized))
        let failed = expectation(description: "Write failure reported")
        controller.onError = { _ in failed.fulfill() }
        controller.request()
        wait(for: [failed], timeout: 2)
        XCTAssertEqual(controller.presentation, .hidden)
        XCTAssertEqual(service.requests.count, 1)
    }

    func testOfferCapturedBeforeConfirmationCannotSwitchToAnotherMode() {
        let service = FakeChargingService()
        service.state = .init(obcOverrideAllowed: true, manualLimit: nil)
        let controller = ChargeToFullController(service: service, readBattery: { .init(percent: 80, isOnAC: true) })
        refresh(controller, expecting: .available(.optimized))
        let clickedOffer = controller.offer!
        service.state = .init(obcOverrideAllowed: false, manualLimit: 80)
        refresh(controller, expecting: .available(.limit))
        let rejected = expectation(description: "Original click cannot change charging mode")
        controller.onError = { _ in rejected.fulfill() }
        controller.request(expectedOffer: clickedOffer)
        wait(for: [rejected], timeout: 2)
        XCTAssertTrue(service.requests.isEmpty)
        XCTAssertEqual(controller.presentation, .hidden)
    }

    func testNewerRefreshDiscardsAnOlderAsynchronousResult() {
        let service = FakeChargingService()
        service.state = .init(obcOverrideAllowed: true, manualLimit: nil)
        let controller = ChargeToFullController(service: service, readBattery: { .init(percent: 80, isOnAC: true) })
        let reading = expectation(description: "First read is in flight")
        let resume = DispatchSemaphore(value: 0)
        var reads = 0
        service.beforeReadReturn = {
            reads += 1
            if reads == 1 {
                reading.fulfill()
                XCTAssertEqual(resume.wait(timeout: .now() + 2), .success)
            }
        }
        controller.refresh()
        wait(for: [reading], timeout: 2)
        service.state = .init(obcOverrideAllowed: false, manualLimit: nil)
        let latest = expectation(description: "Only latest read is published")
        var changes = 0
        controller.onChange = { changes += 1; latest.fulfill() }
        controller.refresh()
        resume.signal()
        wait(for: [latest], timeout: 2)
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(controller.presentation, .hidden)
        XCTAssertTrue(service.requests.isEmpty)
    }

    func testBatteryNotificationInvalidatesWithoutQueryingChargingService() {
        let service = FakeChargingService()
        service.state = .init(obcOverrideAllowed: true, manualLimit: nil)
        let battery = LockedBattery(.init(percent: 80, isOnAC: true))
        let controller = ChargeToFullController(service: service, readBattery: { battery.value })
        refresh(controller, expecting: .available(.optimized))
        service.beforeReadReturn = { XCTFail("A power notification must not query PowerUI") }
        battery.value = .init(percent: 80, isOnAC: true, isCharging: true)
        controller.batteryDidChange()
        XCTAssertEqual(controller.presentation, .hidden)
        XCTAssertNil(controller.offer)
        XCTAssertTrue(service.requests.isEmpty)
    }

    private func refresh(_ controller: ChargeToFullController, expecting presentation: ChargeToFullPresentation,
                         file: StaticString = #filePath, line: UInt = #line) {
        let changed = expectation(description: "Refresh completed")
        controller.onChange = { changed.fulfill() }
        controller.refresh()
        wait(for: [changed], timeout: 2)
        XCTAssertEqual(controller.presentation, presentation, file: file, line: line)
        controller.onChange = nil
    }
}

private enum TestError: Error { case failed }

private final class LockedBattery {
    private let lock = NSLock()
    private var snapshot: BatterySnapshot
    init(_ snapshot: BatterySnapshot) { self.snapshot = snapshot }
    var value: BatterySnapshot {
        get { lock.lock(); defer { lock.unlock() }; return snapshot }
        set { lock.lock(); defer { lock.unlock() }; snapshot = newValue }
    }
}

private final class FakeChargingService: ChargingService {
    var state = ChargingState(obcOverrideAllowed: false, manualLimit: nil)
    var readError: Error?
    var requestError: Error?
    var beforeReadReturn: (() -> Void)?
    private(set) var requests: [(ChargingMode, Int?)] = []
    func readState() throws -> ChargingState {
        XCTAssertFalse(Thread.isMainThread)
        if let readError { throw readError }
        let result = state
        beforeReadReturn?()
        return result
    }
    func request(_ mode: ChargingMode, expectedLimit: Int?) throws {
        XCTAssertFalse(Thread.isMainThread)
        requests.append((mode, expectedLimit))
        if let requestError { throw requestError }
    }
}
