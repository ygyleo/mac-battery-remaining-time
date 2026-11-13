import ChargingBridge

/// Private framework details stay outside the UI and its state machine.
final class SystemChargingService: ChargingService {
    private let client = BTChargingClient()

    func readState() throws -> ChargingState {
        let state = try client.readState()
        return ChargingState(
            obcOverrideAllowed: state.supportsOptimizedCharging && state.optimizedOverrideAllowed,
            manualLimit: state.supportsManualLimit && state.manualLimitEnabled ? Int(state.manualLimit) : nil
        )
    }

    func request(_ mode: ChargingMode, expectedLimit: Int?) throws {
        try client.request(mode: mode == .optimized ? .optimized : .limit,
                           expectedLimit: UInt(expectedLimit ?? 0))
    }
}
