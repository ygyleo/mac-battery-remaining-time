import BatteryCore
import Foundation

enum ChargingMode: Equatable { case optimized, limit }

struct ChargingOffer: Equatable {
    let mode: ChargingMode
    let expectedLimit: Int?
}

struct ChargingState {
    let obcOverrideAllowed: Bool
    let manualLimit: Int?
}

protocol ChargingService {
    func readState() throws -> ChargingState
    func request(_ mode: ChargingMode, expectedLimit: Int?) throws
}

enum ChargeToFullPresentation: Equatable {
    case hidden, available(ChargingMode), requesting, requested
}

final class ChargeToFullController {
    private(set) var presentation: ChargeToFullPresentation = .hidden
    private(set) var error: Error?
    var offer: ChargingOffer? { offered.map { ChargingOffer(mode: $0.mode, expectedLimit: $0.limit) } }
    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?
    private let service: ChargingService
    private let readBattery: () -> BatterySnapshot
    private let queue = DispatchQueue(label: "io.github.ygyleo.BatteryTime.charging", qos: .userInitiated)
    private var generation = 0
    private var busy = false
    private var offered: Eligibility?
    private var accepted: Eligibility?

    /// Public methods and callbacks run on the main thread. readBattery must be
    /// safe on either thread; service queries and writes run on a serial queue.
    init(service: ChargingService, readBattery: @escaping () -> BatterySnapshot) {
        self.service = service
        self.readBattery = readBattery
    }

    /// Called when opening the menu, rather than polling the private service.
    func refresh() {
        guard !busy else { return }
        generation += 1
        let current = generation
        let service = service
        let readBattery = readBattery
        queue.async { [weak self] in
            let result = Result { try Eligibility.resolve(service.readState(), battery: readBattery()) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == current else { return }
                switch result {
                case .success(let eligibility):
                    self.offered = eligibility
                    if eligibility != self.accepted { self.accepted = nil }
                    if let eligibility {
                        self.presentation = self.accepted == eligibility ? .requested : .available(eligibility.mode)
                    } else {
                        self.presentation = .hidden
                    }
                case .failure:
                    self.offered = nil
                    self.presentation = .hidden
                }
                self.onChange?()
            }
        }
    }

    /// A single explicit click is the only path that can send a charging write.
    func request(expectedOffer: ChargingOffer? = nil) {
        guard !busy else { return }
        if let expectedOffer, expectedOffer != offer {
            generation += 1
            error = ChargingActionError.stateChanged
            offered = nil
            presentation = .hidden
            onChange?()
            onError?(ChargingActionError.stateChanged)
            return
        }
        guard case .available = presentation, let expected = offered else { return }
        busy = true
        generation += 1
        let current = generation
        error = nil
        presentation = .requesting
        onChange?()
        let service = service
        let readBattery = readBattery
        queue.async { [weak self] in
            let result = Result {
                // Query first, then read the physical battery again: unplugging
                // or starting charging during the service call invalidates it.
                let state = try service.readState()
                guard Eligibility.resolve(state, battery: readBattery()) == expected else {
                    throw ChargingActionError.stateChanged
                }
                try service.request(expected.mode, expectedLimit: expected.limit)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == current else { return }
                self.busy = false
                switch result {
                case .success:
                    self.accepted = expected
                    self.presentation = .requested
                    self.onChange?()
                case .failure(let error):
                    self.error = error
                    self.offered = nil
                    self.presentation = .hidden
                    self.onChange?()
                    self.onError?(error)
                }
            }
        }
    }

    /// Power notifications only invalidate an existing action. They never query
    /// PowerUI, and a changed battery cannot create a new charging request.
    func batteryDidChange() {
        guard !busy else { return }
        let eligibility = offered ?? accepted ?? Eligibility(mode: .optimized, limit: nil)
        guard !eligibility.matchesBattery(readBattery()) else { return }
        generation += 1
        offered = nil
        accepted = nil
        presentation = .hidden
        onChange?()
    }

    private struct Eligibility: Equatable {
        let mode: ChargingMode
        let limit: Int?

        func matchesBattery(_ battery: BatterySnapshot) -> Bool {
            guard let percent = battery.percent, (0..<100).contains(percent),
                  battery.isOnAC, !battery.isCharging, !battery.isCharged else { return false }
            return limit.map { percent >= $0 } ?? true
        }

        static func resolve(_ state: ChargingState, battery: BatterySnapshot) -> Eligibility? {
            let eligibility: Eligibility
            if let limit = state.manualLimit {
                guard (80..<100).contains(limit) else { return nil }
                eligibility = Eligibility(mode: .limit, limit: limit)
            } else if state.obcOverrideAllowed {
                eligibility = Eligibility(mode: .optimized, limit: nil)
            } else {
                return nil
            }
            return eligibility.matchesBattery(battery) ? eligibility : nil
        }
    }
}

enum ChargingActionError: Error { case stateChanged }
