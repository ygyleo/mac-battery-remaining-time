import AppKit
import BatteryCore
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let monitor = BatteryMonitor()
    private let preferences = Preferences()
    private let batteryMenu = BatteryMenu()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var preferencesSubscription: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?
    private let appQuitItem = NSMenuItem()
    private let windowMenuItem = NSMenuItem()
    private let closeWindowItem = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        let opensSettings = LaunchContext.shouldOpenSettings(for: NSAppleEventManager.shared().currentAppleEvent)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "BatteryTime"
        batteryMenu.menu.delegate = self
        statusItem.menu = batteryMenu.menu
        appearanceObservation = statusItem.button?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.update()
        }
        configureApplicationMenu()
        monitor.onChange = { [weak self] _ in self?.update() }
        preferencesSubscription = preferences.$language.combineLatest(preferences.$showTimeInMenuBar)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.update() }
        update()
        if opensSettings { showSettings() }
    }

    func menuWillOpen(_ menu: NSMenu) { monitor.refresh() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Battery Time")
        appQuitItem.target = NSApp
        appQuitItem.action = #selector(NSApplication.terminate(_:))
        appQuitItem.keyEquivalent = "q"
        applicationMenu.addItem(appQuitItem)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        let windowMenu = NSMenu()
        closeWindowItem.action = #selector(NSWindow.performClose(_:))
        closeWindowItem.keyEquivalent = "w"
        windowMenu.addItem(closeWindowItem)
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func update() {
        guard let button = statusItem?.button else { return }
        let snapshot = monitor.snapshot
        let text = preferences.text
        button.image = BatteryIcon.image(for: snapshot, appearance: button.effectiveAppearance)
        button.imagePosition = preferences.showTimeInMenuBar ? .imageLeading : .imageOnly
        button.title = preferences.showTimeInMenuBar ? " " + text.statusTitle(snapshot: snapshot) : ""
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let charge = text.chargeValue(snapshot: snapshot)
        let remaining = text.remainingValue(snapshot: snapshot)
        button.toolTip = "\(text.chargeLabel): \(charge)\n\(text.remainingLabel): \(remaining)"
        button.setAccessibilityLabel("Battery Time. \(text.chargeLabel): \(charge). \(text.remainingLabel): \(remaining)")
        batteryMenu.update(snapshot: snapshot, text: text)
        appQuitItem.title = text.quit + " Battery Time"
        windowMenuItem.title = preferences.language == .chinese ? "窗口" : "Window"
        closeWindowItem.title = preferences.language == .chinese ? "关闭窗口" : "Close Window"
        settingsWindow?.title = text.settingsTitle
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 188),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: SettingsView(preferences: preferences))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.title = preferences.text.settingsTitle
            window.center()
            settingsWindow = window
        }
        preferences.refreshLoginStatus()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
