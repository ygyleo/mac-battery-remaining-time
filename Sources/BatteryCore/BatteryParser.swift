import Foundation
import CoreFoundation

/// Converts documented IOPowerSources values into a small, UI-independent snapshot.
public enum BatteryParser {
    public static func parse(_ descriptions: [[String: Any]], fallbackMinutes: Int? = nil) -> BatterySnapshot {
        guard let source = descriptions.first(where: {
            $0["Type"] as? String == "InternalBattery" && ($0["Is Present"] as? Bool != false)
        }) else { return .unavailable }

        let percent: Int?
        if let current = number(source["Current Capacity"]), current >= 0,
           let maximum = number(source["Max Capacity"]), maximum > 0 {
            percent = Int(min(100, max(0, current / maximum * 100)).rounded())
        } else {
            percent = nil
        }

        let isOnAC = source["Power Source State"] as? String == "AC Power"
        let isCharging = isOnAC && (source["Is Charging"] as? Bool == true)
        let isCharged = isOnAC && !isCharging &&
            ((source["Is Charged"] as? Bool == true) || percent == 100)
        let isOnBattery = source["Power Source State"] as? String == "Battery Power"
        let fallback = fallbackMinutes.flatMap { $0 > 0 ? $0 : nil }
        return BatterySnapshot(
            percent: percent,
            isOnAC: isOnAC,
            isCharging: isCharging,
            isCharged: isCharged,
            minutesRemaining: isOnBattery ? (minutes(source["Time to Empty"]) ?? fallback) : nil,
            minutesToFull: isCharging ? minutes(source["Time to Full Charge"]) : nil
        )
    }

    /// CFBoolean bridges to NSNumber too, but cannot be a capacity or duration.
    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
        let number = value.doubleValue
        guard number.isFinite, abs(number) < Double(Int.max) else { return nil }
        return number
    }

    private static func minutes(_ value: Any?) -> Int? {
        guard let number = number(value), number >= 1 else { return nil }
        return Int(number)
    }
}
