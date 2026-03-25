import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var monitor: MissionControlQuit!
    private var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "⌘Q"
        }

        statusItem.menu = buildMenu()

        // Start the event tap
        monitor = MissionControlQuit()
        monitor.start()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About MissionQuit", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MissionQuit", action: #selector(quitApp), keyEquivalent: ""))
        return menu
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
        statusItem.menu = buildMenu()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
