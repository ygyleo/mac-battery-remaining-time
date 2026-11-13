import AppKit
import BatteryCore
import IOKit.ps

final class BatteryMonitor {
    private(set) var snapshot = BatterySnapshot.unavailable
    var onChange: ((BatterySnapshot) -> Void)?
    private var powerSource: CFRunLoopSource?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
        }, context)?.takeRetainedValue()
        if let powerSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes)
        }
        // Notifications cover source changes; this refreshes the displayed estimate.
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 10
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            publish(.unavailable)
            return
        }
        let descriptions = sources.compactMap { source -> [String: Any]? in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }
        let seconds = IOPSGetTimeRemainingEstimate()
        let minutes = seconds.isFinite && seconds > 0 && seconds < Double(Int.max)
            ? max(1, Int(seconds / 60)) : nil
        publish(BatteryParser.parse(descriptions, fallbackMinutes: minutes))
    }

    private func publish(_ value: BatterySnapshot) {
        snapshot = value
        onChange?(value)
    }

    deinit {
        timer?.invalidate()
        if let powerSource { CFRunLoopSourceInvalidate(powerSource) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
}
