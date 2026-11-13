import AppKit
import BatteryCore
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = BatteryMonitor()
    private let preferences = Preferences()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let chargeItem = NSMenuItem()
    private let timeItem = NSMenuItem()
    private let settingsItem = NSMenuItem()
    private let quitItem = NSMenuItem()
    private var settingsWindow: NSWindow?
    private var languageSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Avoid duplicate status items if the app is launched a second time.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "BatteryTime"
        menu.autoenablesItems = false
        menu.delegate = self
        chargeItem.isEnabled = false
        timeItem.isEnabled = false
        settingsItem.target = self
        settingsItem.action = #selector(showSettings)
        settingsItem.keyEquivalent = ","
        quitItem.target = self
        quitItem.action = #selector(quit)
        quitItem.keyEquivalent = "q"
        [chargeItem, timeItem, .separator(), settingsItem, .separator(), quitItem].forEach(menu.addItem)
        statusItem.menu = menu
        monitor.onChange = { [weak self] _ in self?.update() }
        languageSubscription = preferences.$language.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.update()
        }
        update()
    }

    func menuWillOpen(_ menu: NSMenu) { monitor.refresh() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func update() {
        guard let button = statusItem?.button else { return }
        let snapshot = monitor.snapshot
        let text = preferences.text
        button.image = BatteryIcon.image(for: snapshot)
        button.imagePosition = .imageLeading
        button.title = " " + text.statusTitle(snapshot: snapshot)
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let charge = text.chargeValue(snapshot: snapshot)
        let remaining = text.remainingValue(snapshot: snapshot)
        button.toolTip = "\(text.chargeLabel): \(charge)\n\(text.remainingLabel): \(remaining)"
        button.setAccessibilityLabel("Battery Time. \(text.chargeLabel): \(charge). \(text.remainingLabel): \(remaining)")
        setDataRow(chargeItem, label: text.chargeLabel, value: charge)
        setDataRow(timeItem, label: text.remainingLabel, value: remaining)
        settingsItem.title = text.settings
        quitItem.title = text.quit
        settingsWindow?.title = text.settingsTitle
    }

    private func setDataRow(_ item: NSMenuItem, label: String, value: String) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 300)]
        let text = NSMutableAttributedString(string: label + "\t" + value, attributes: [
            .font: NSFont.menuFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ])
        text.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                          range: NSRange(location: (label as NSString).length + 1, length: (value as NSString).length))
        item.title = label + ": " + value
        item.attributedTitle = text
        item.setAccessibilityLabel(item.title)
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 148),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: SettingsView(preferences: preferences))
            window.isReleasedWhenClosed = false
            window.title = preferences.text.settingsTitle
            window.center()
            settingsWindow = window
        }
        preferences.refreshLoginStatus()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
