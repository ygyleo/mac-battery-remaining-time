import Foundation

public struct BatteryText {
    public let language: AppLanguage
    public init(language: AppLanguage) { self.language = language }
    public func statusTitle(snapshot: BatterySnapshot) -> String {
        if snapshot.isOnAC {
            if snapshot.isCharged { return localized("已充满", "Full") }
            if snapshot.isCharging {
                guard let minutes = positive(snapshot.minutesToFull) else {
                    return localized("充电中…", "Charging…")
                }
                return localized("充满 \(compact(minutes))", "Full in \(compact(minutes))")
            }
            return localized("已接电", "On AC")
        }
        if let minutes = positive(snapshot.minutesRemaining) { return compact(minutes) }
        return snapshot.percent == nil ? "—" : localized("估算中…", "Estimating…")
    }

    public func remainingValue(snapshot: BatterySnapshot) -> String {
        if snapshot.isOnAC {
            if snapshot.isCharged { return localized("已充满", "Fully charged") }
            if snapshot.isCharging {
                guard let minutes = positive(snapshot.minutesToFull) else {
                    return localized("正在充电，估算中…", "Charging, estimating…")
                }
                return localized("\(duration(minutes))后充满", "\(duration(minutes)) until full")
            }
            return localized("已接电，未充电", "Plugged in, not charging")
        }
        if let minutes = positive(snapshot.minutesRemaining) { return duration(minutes) }
        return snapshot.percent == nil ? localized("不可用", "Unavailable") : localized("估算中…", "Estimating…")
    }

    public func chargeValue(snapshot: BatterySnapshot) -> String {
        snapshot.percent.map { "\($0)%" } ?? "—"
    }

    private func positive(_ minutes: Int?) -> Int? {
        minutes.flatMap { $0 > 0 ? $0 : nil }
    }

    private func compact(_ minutes: Int) -> String {
        "\(minutes / 60):" + String(format: "%02d", minutes % 60)
    }

    private func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remaining = minutes % 60
        var parts: [String] = []
        if hours > 0 { parts.append(localized("\(hours)小时", "\(hours) hr")) }
        if remaining > 0 { parts.append(localized("\(remaining)分钟", "\(remaining) min")) }
        return parts.joined(separator: language == .chinese ? "" : " ")
    }

    public var chargeLabel: String { localized("电池剩余电量", "Battery charge") }
    public var remainingLabel: String { localized("电池剩余时间", "Battery time remaining") }
    public var settings: String { localized("设置…", "Settings…") }
    public var quit: String { localized("退出", "Quit") }
    public var languageLabel: String { localized("语言", "Language") }
    public var launchAtLoginLabel: String { localized("开机自启动", "Launch at login") }
    public var showTimeInMenuBarLabel: String { localized("在菜单栏显示剩余时间", "Show time in menu bar") }
    public var settingsTitle: String { localized("设置", "Settings") }
    public var chargeToFull: String { localized("立即充满", "Charge to Full Now") }
    public var requestingCharge: String { localized("正在请求…", "Requesting…") }
    public var chargeRequested: String { localized("已请求充满", "Full charge requested") }
    public var chargeRequestFailed: String { localized("未能请求立即充满", "Could not request a full charge") }
    public var chargeRequestFailureMessage: String {
        localized("充电状态可能已变化，或 macOS 未接受请求。请重新打开菜单再试，也可以使用系统电池菜单中的“立即充满”。",
                  "The charging state may have changed, or macOS did not accept the request. Reopen the menu to try again, or use Charge to Full Now in the system battery menu.")
    }
    public var manualLimitMessage: String {
        localized("这将调用 macOS 的充电上限操作。某些系统版本会将上限保留为 100%；充满后，你可能需要在系统设置中恢复原上限。",
                  "This uses the macOS charge-limit action. Some system versions leave the limit at 100%; you may need to restore your previous limit in System Settings after charging.")
    }
    public var cancel: String { localized("取消", "Cancel") }
    public var ok: String { localized("好", "OK") }
    public var loginApprovalMessage: String { localized("请在系统设置的登录项中允许 Battery Time。", "Allow Battery Time in System Settings → Login Items.") }
    public var loginErrorTitle: String { localized("无法更改开机自启动", "Could not change launch at login") }

    private func localized(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }
}
