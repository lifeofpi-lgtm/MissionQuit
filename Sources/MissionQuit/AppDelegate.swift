import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = MissionControlQuit()
    private var permissionTimer: Timer?

    private var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "⌘Q"

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        monitor.onQuit = { [weak self] app in
            self?.flashStatusItem(for: app)
        }

        MissionControlQuit.requestAccessibility()
        startMonitorWhenTrusted()
    }

    /// The system prompt can't tell us when the user flips the toggle, so poll
    /// until Accessibility is granted, then create the tap and stop polling.
    private func startMonitorWhenTrusted() {
        if monitor.start() {
            permissionTimer?.invalidate()
            permissionTimer = nil
            statusItem.button?.appearsDisabled = false
            return
        }
        statusItem.button?.appearsDisabled = true
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.startMonitorWhenTrusted()
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if monitor.isRunning {
            let item = NSMenuItem(title: "Active: ⌘Q in Mission Control quits the hovered app", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let item = NSMenuItem(title: "Accessibility permission needed", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            let open = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            open.target = self
            menu.addItem(open)
        }

        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        let about = NSMenuItem(title: "About MissionQuit", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit MissionQuit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func openAccessibilitySettings() {
        MissionControlQuit.requestAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Failed to toggle launch at login: \(error)")
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Feedback

    /// Brief confirmation in the menu bar so a quit from Mission Control
    /// doesn't feel like nothing happened.
    private func flashStatusItem(for app: NSRunningApplication) {
        guard let button = statusItem.button else { return }
        button.title = "✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            button.title = "⌘Q"
        }
    }
}
