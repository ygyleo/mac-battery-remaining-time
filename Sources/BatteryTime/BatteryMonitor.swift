import AppKit
import BatteryCore
import notify
import IOKit.ps

final class BatteryMonitor {
    private(set) var snapshot = BatterySnapshot.unavailable
    var onChange: ((BatterySnapshot) -> Void)?
    private let readSnapshot: () -> BatterySnapshot
    private var notificationToken: Int32?
    private var refreshQueued = false
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(readSnapshot: @escaping () -> BatterySnapshot = BatteryMonitor.readSystemSnapshot,
         notificationName: String = kIOPSNotifyAnyPowerSource) {
        self.readSnapshot = readSnapshot
        refresh()
        // The time/percentage notification alone can miss charging pause/resume.
        // Observe all power-source attributes, coalescing bursts on the main queue.
        var token: Int32 = 0
        if notify_register_dispatch(notificationName, &token, .main, { [weak self] _ in
            self?.queueRefresh()
        }) == NOTIFY_STATUS_OK {
            notificationToken = token
        }
        // Low-frequency fallback in case notification delivery is unavailable.
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 10
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        publish(readSnapshot())
    }

    private func queueRefresh() {
        guard !refreshQueued else { return }
        refreshQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshQueued = false
            self?.refresh()
        }
    }

    static func readSystemSnapshot() -> BatterySnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unavailable
        }
        let descriptions = sources.compactMap { source -> [String: Any]? in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }
        let seconds = IOPSGetTimeRemainingEstimate()
        let minutes = seconds.isFinite && seconds > 0 && seconds < Double(Int.max)
            ? max(1, Int(seconds / 60)) : nil
        return BatteryParser.parse(descriptions, fallbackMinutes: minutes)
    }

    private func publish(_ value: BatterySnapshot) {
        guard value != snapshot else { return }
        snapshot = value
        onChange?(value)
    }

    deinit {
        timer?.invalidate()
        if let notificationToken { notify_cancel(notificationToken) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
}
