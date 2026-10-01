import Cocoa
import ApplicationServices

/// Intercepts ⌘Q while Mission Control is active and quits
/// the app whose window thumbnail is under the cursor.
final class MissionControlQuit {
    fileprivate var eventTap: CFMachPort?
    fileprivate var lastQuitTime: CFAbsoluteTime = 0
    fileprivate let systemWide = AXUIElementCreateSystemWide()

    /// Called on the main thread whenever an app is quit through Mission Control.
    var onQuit: ((NSRunningApplication) -> Void)?

    var isRunning: Bool { eventTap != nil }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt once and returns the current trust state.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Creates the event tap. Safe to call repeatedly; returns true once the tap exists.
    @discardableResult
    func start() -> Bool {
        if eventTap != nil { return true }
        guard Self.isTrusted else { return false }

        // The tap callback runs synchronously on the event stream. A slow AX
        // query would get the tap disabled by the system, so cap how long we
        // are willing to wait on the hit-test.
        AXUIElementSetMessagingTimeout(systemWide, 0.25)

        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    // MARK: - Mission Control detection

    /// At rest the Dock owns exactly one on-screen window, named "Dock", at layer 20.
    /// While Mission Control (or Exposé) is showing it adds unnamed windows that
    /// cover an entire screen. Checking the layer alone is wrong: the Dock's own
    /// window is already at layer 20, which made the old check fire all the time.
    func isMissionControlActive() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let screenFrames = NSScreen.screens.map { cgRect(for: $0) }

        for win in windowList {
            guard win[kCGWindowOwnerName as String] as? String == "Dock" else { continue }
            if let name = win[kCGWindowName as String] as? String, name == "Dock" { continue }
            guard let boundsDict = win[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            if screenFrames.contains(where: { $0.equalTo(bounds) }) {
                return true
            }
        }
        return false
    }

    /// AppKit screen frame converted to CoreGraphics coordinates (origin top-left of primary screen).
    private func cgRect(for screen: NSScreen) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let f = screen.frame
        return CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height)
    }

    // MARK: - Find app under cursor

    /// In Mission Control the accessibility hit-test resolves to the real
    /// application behind the thumbnail, so the owning pid is all we need.
    func findAppUnderCursor() -> NSRunningApplication? {
        let mouse = NSEvent.mouseLocation
        // Flip against the primary screen, not NSScreen.main, so secondary
        // monitors map correctly.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let point = CGPoint(x: mouse.x, y: primaryHeight - mouse.y)

        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)
        guard result == .success, let element = element else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid > 0,
              let app = NSRunningApplication(processIdentifier: pid) else { return nil }

        // Hovering Mission Control chrome (space labels, background) hits the Dock.
        // Never quit the Dock, ourselves, or background-only processes.
        guard app.bundleIdentifier != "com.apple.dock",
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.activationPolicy == .regular else { return nil }

        return app
    }
}

// MARK: - Event tap callback (C-convention)

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<MissionControlQuit>.fromOpaque(userInfo).takeUnretainedValue()

    // Re-enable if the tap gets disabled by the system
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = monitor.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    // ⌘Q → keycode 12 (Q) with Command as the only modifier.
    // Ignore lock/state bits so caps lock or fn don't break the match, but
    // leave ⌘⌥Q, ⌘⇧Q, etc. alone since apps bind those separately.
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let modifiers = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    guard keyCode == 12, modifiers == .maskCommand else {
        return Unmanaged.passUnretained(event)
    }

    guard monitor.isMissionControlActive() else {
        return Unmanaged.passUnretained(event)
    }

    // Inside Mission Control we own ⌘Q. Holding the key or pressing it twice
    // must not quit a second app, and if we can't tell what's under the cursor
    // it is safer to do nothing than to let ⌘Q reach the frontmost app.
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    let now = CFAbsoluteTimeGetCurrent()
    guard !isRepeat, now - monitor.lastQuitTime > 0.5 else {
        return nil
    }

    if let app = monitor.findAppUnderCursor() {
        monitor.lastQuitTime = now
        app.terminate()
        DispatchQueue.main.async { monitor.onQuit?(app) }
    }
    return nil
}
