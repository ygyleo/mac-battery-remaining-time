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
    public var loginApprovalMessage: String { localized("请在系统设置的登录项中允许 Battery Time。", "Allow Battery Time in System Settings → Login Items.") }
    public var loginErrorTitle: String { localized("无法更改开机自启动", "Could not change launch at login") }

    private func localized(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }
}
