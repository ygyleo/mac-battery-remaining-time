import Foundation

public enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans"
    case english = "en"
}

public enum BatteryTint: Equatable {
    case normal, yellow, red
}

public enum BatteryPowerSymbol: Equatable {
    case none, bolt, plug
}

public struct BatterySnapshot: Equatable {
    public let percent: Int?
    public let isOnAC: Bool
    public let isCharging: Bool
    public let isCharged: Bool
    public let minutesRemaining: Int?
    public let minutesToFull: Int?

    public init(percent: Int? = nil, isOnAC: Bool = false, isCharging: Bool = false,
                isCharged: Bool = false, minutesRemaining: Int? = nil, minutesToFull: Int? = nil) {
        self.percent = percent
        self.isOnAC = isOnAC
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.minutesRemaining = minutesRemaining
        self.minutesToFull = minutesToFull
    }

    public static let unavailable = BatterySnapshot()
    public var powerSymbol: BatteryPowerSymbol {
        guard isOnAC else { return .none }
        return isCharging ? .bolt : .plug
    }

    public var tint: BatteryTint {
        guard !isOnAC, let percent else { return .normal }
        if percent <= 10 { return .red }
        if percent <= 20 { return .yellow }
        return .normal
    }
}
