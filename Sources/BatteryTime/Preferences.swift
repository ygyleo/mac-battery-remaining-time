import AppKit
import BatteryCore
import Combine
import ServiceManagement

final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }
    @Published var showTimeInMenuBar: Bool {
        didSet { defaults.set(showTimeInMenuBar, forKey: "showTimeInMenuBar") }
    }
    @Published private(set) var loginEnabled = false
    @Published private(set) var needsApproval = false
    @Published var loginError: String?
    private var activationObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showTimeInMenuBar = defaults.object(forKey: "showTimeInMenuBar") as? Bool ?? true
        if let value = defaults.string(forKey: "language"),
           let stored = AppLanguage(rawValue: value) {
            language = stored
        } else {
            language = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
        }
        refreshLoginStatus()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshLoginStatus() }
    }

    var text: BatteryText { BatteryText(language: language) }

    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        loginEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLoginStatus()
            if needsApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            refreshLoginStatus()
            loginError = error.localizedDescription
        }
    }

    deinit {
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    }
}
