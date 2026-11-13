import ChargingBridge
import Foundation
import XCTest

private class FakeChargeClient: NSObject {
    var allowed = true
    var enabled: UInt = 1
    var limit: UInt8 = 80
    var readError: NSError?
    var requestError: NSError?
    var optimizedRequests = 0
    var limitRequests = 0

    @objc(smartChargingUIState:chargeLimit:chargingOverrideAllowed:withError:)
    func state(_ state: UnsafeMutablePointer<UInt>, limit: UnsafeMutablePointer<UInt>,
               allowed: UnsafeMutablePointer<ObjCBool>, error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        state.pointee = 3
        limit.pointee = UInt(self.limit)
        allowed.pointee = ObjCBool(self.allowed)
        error?.pointee = readError
        return readError == nil
    }
    @objc func isMCLSupported() -> Bool { true }
    @objc(isMCLCurrentlyEnabled:)
    func isMCLCurrentlyEnabled(_ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> UInt { enabled }
    @objc(getMCLLimitWithError:)
    func getMCLLimit(_ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> UInt8 { limit }
    @objc(temporarilyEnableCharging:)
    func enableCharging(_ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        optimizedRequests += 1; error?.pointee = requestError; return requestError == nil
    }
    @objc(temporarilyDisableMCL:)
    func disableLimit(_ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        limitRequests += 1; error?.pointee = requestError; return requestError == nil
    }
}

private class WrongABIClient: NSObject {
    @objc(smartChargingUIState:chargeLimit:chargingOverrideAllowed:withError:)
    func state(_ state: NSString, limit: NSString, allowed: NSString, error: NSString) -> Int { 1 }
    @objc(temporarilyEnableCharging:)
    func enableCharging(_ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        XCTFail("A mismatched ABI must never be called"); return true
    }
}

private class LegacyChargeClient: NSObject {
    var engaged = true
    var requests = 0
    @objc(isOBCEngaged:asDesktopDevice:chargingOverrideAllowed:withError:)
    func state(_ engaged: UnsafeMutablePointer<ObjCBool>, desktop: UnsafeMutablePointer<ObjCBool>,
               allowed: UnsafeMutablePointer<ObjCBool>, error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        engaged.pointee = ObjCBool(self.engaged)
        desktop.pointee = false
        allowed.pointee = true
        return true
    }
    @objc(temporarilyEnableCharging:)
    func enableCharging(_ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        requests += 1; return true
    }
}

final class ChargingBridgeTests: XCTestCase {
    func testReadsStateWithoutSendingAnAction() throws {
        let fake = FakeChargeClient()
        let state = try BTChargingClient(client: fake).readState()
        XCTAssertTrue(state.supportsOptimizedCharging)
        XCTAssertTrue(state.supportsManualLimit)
        XCTAssertTrue(state.optimizedOverrideAllowed)
        XCTAssertTrue(state.manualLimitEnabled)
        XCTAssertEqual(state.manualLimit, 80)
        XCTAssertEqual(fake.optimizedRequests + fake.limitRequests, 0)
    }
    func testOptimizedRequestSendsExactlyOneNativeAction() throws {
        let fake = FakeChargeClient(); fake.enabled = 0
        try BTChargingClient(client: fake).request(mode: .optimized, expectedLimit: 0)
        XCTAssertEqual(fake.optimizedRequests, 1)
        XCTAssertEqual(fake.limitRequests, 0)
    }
    func testManualLimitActivatedAfterReadRejectsOptimizedRequest() throws {
        let fake = FakeChargeClient(); fake.enabled = 0
        let bridge = BTChargingClient(client: fake)
        XCTAssertFalse(try bridge.readState().manualLimitEnabled)
        fake.enabled = 1
        XCTAssertThrowsError(try bridge.request(mode: .optimized, expectedLimit: 0))
        XCTAssertEqual(fake.optimizedRequests + fake.limitRequests, 0)
    }
    func testManualLimitDoesNotRequireOBCOverrideFlag() throws {
        let fake = FakeChargeClient(); fake.allowed = false
        try BTChargingClient(client: fake).request(mode: .limit, expectedLimit: 80)
        XCTAssertEqual(fake.limitRequests, 1)
        XCTAssertEqual(fake.optimizedRequests, 0)
    }
    func testChangedLimitAndInactiveOBCRejectStaleAction() throws {
        let fake = FakeChargeClient(); let bridge = BTChargingClient(client: fake)
        _ = try bridge.readState()
        fake.limit = 90; fake.allowed = false
        XCTAssertThrowsError(try bridge.request(mode: .limit, expectedLimit: 80))
        XCTAssertThrowsError(try bridge.request(mode: .optimized, expectedLimit: 0))
        XCTAssertEqual(fake.limitRequests + fake.optimizedRequests, 0)
    }
    func testUnknownManualLimitStateDoesNotPermitAnAction() {
        let fake = FakeChargeClient(); fake.enabled = 2
        XCTAssertThrowsError(try BTChargingClient(client: fake).request(mode: .limit, expectedLimit: 80))
        XCTAssertEqual(fake.limitRequests, 0)
    }
    func testMissingAndWrongABIMethodsFailClosed() {
        XCTAssertThrowsError(try BTChargingClient(client: NSObject()).readState())
        XCTAssertThrowsError(try BTChargingClient(client: WrongABIClient()).readState())
    }
    func testReadErrorsArePreservedAndPreventWrites() {
        let fake = FakeChargeClient(); fake.readError = NSError(domain: "test.read", code: 42)
        XCTAssertThrowsError(try BTChargingClient(client: fake).request(mode: .optimized, expectedLimit: 0)) {
            XCTAssertEqual(($0 as NSError).domain, "test.read")
            XCTAssertEqual(($0 as NSError).code, 42)
        }
        XCTAssertEqual(fake.limitRequests + fake.optimizedRequests, 0)
    }
    func testActionErrorIsPreservedWithoutRetry() {
        let fake = FakeChargeClient(); fake.enabled = 0
        fake.requestError = NSError(domain: "test.write", code: 43)
        XCTAssertThrowsError(try BTChargingClient(client: fake).request(mode: .optimized, expectedLimit: 0)) {
            XCTAssertEqual(($0 as NSError).domain, "test.write")
        }
        XCTAssertEqual(fake.optimizedRequests, 1)
    }
    func testLegacyOBCQueryRequiresEngagementAndDoesNotNeedMCL() throws {
        let fake = LegacyChargeClient(); let bridge = BTChargingClient(client: fake)
        let state = try bridge.readState()
        XCTAssertTrue(state.supportsOptimizedCharging)
        XCTAssertFalse(state.supportsManualLimit)
        try bridge.request(mode: .optimized, expectedLimit: 0)
        XCTAssertEqual(fake.requests, 1)
        fake.engaged = false
        XCTAssertThrowsError(try bridge.request(mode: .optimized, expectedLimit: 0))
        XCTAssertEqual(fake.requests, 1)
    }
}
