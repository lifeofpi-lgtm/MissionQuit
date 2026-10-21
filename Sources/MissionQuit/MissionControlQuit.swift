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
        // Unretained: this is a global constant, and taking a +1 on every call over-releases it.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
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

    /// macOS 27 moved Mission Control from the Dock into WindowManager, and the
    /// Dock's own window now covers the whole screen at all times, so the old
    /// Dock check fired everywhere.
    private static let usesWindowManager = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27

    /// Mission Control puts a window over an entire screen, owned by WindowManager
    /// on macOS 27+ or by the Dock (unnamed, alongside its "Dock" window) before
    /// that. Window names need Screen Recording permission and usually read as
    /// nil, so the decision rests on owner and bounds only.
    func isMissionControlActive() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let owner = Self.usesWindowManager ? "WindowManager" : "Dock"
        let screenFrames = NSScreen.screens.map { cgRect(for: $0) }

        for win in windowList {
            guard win[kCGWindowOwnerName as String] as? String == owner else { continue }
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

    /// `point` is in CoreGraphics global coordinates (top-left origin of the primary display).
    func findApp(at point: CGPoint) -> NSRunningApplication? {
        let pid = Self.usesWindowManager ? thumbnailOwnerPid(at: point) : hitTestPid(at: point)
        guard let pid, pid > 0, let app = NSRunningApplication(processIdentifier: pid) else { return nil }

        // Never quit the Dock, ourselves, or background-only processes.
        guard app.bundleIdentifier != "com.apple.dock",
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.activationPolicy == .regular else { return nil }

        return app
    }

    /// macOS 27+: thumbnails are WindowManager buttons under an "mc.display" group,
    /// and each carries the real CGWindowID in a "wid" attribute. Asking WindowManager
    /// directly means a hit-test that falls through to the live windows behind the
    /// overlay (seen while Mission Control animates) can never pick the wrong app.
    private func thumbnailOwnerPid(at point: CGPoint) -> pid_t? {
        guard let wmPid = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.WindowManager").first?.processIdentifier else { return nil }
        let wm = AXUIElementCreateApplication(wmPid)

        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(wm, Float(point.x), Float(point.y), &element) == .success,
              let button = element,
              stringAttribute(button, kAXRoleAttribute) == kAXButtonRole,
              let parent = elementAttribute(button, kAXParentAttribute),
              stringAttribute(parent, kAXIdentifierAttribute) == "mc.display" else { return nil }

        var wid: CFTypeRef?
        guard AXUIElementCopyAttributeValue(button, "wid" as CFString, &wid) == .success,
              let windowID = (wid as? NSNumber)?.uint32Value,
              let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]])?.first,
              let ownerPid = info[kCGWindowOwnerPID as String] as? pid_t else { return nil }
        return ownerPid
    }

    /// Before macOS 27 the system-wide hit-test resolved straight to the app behind the thumbnail.
    private func hitTestPid(at point: CGPoint) -> pid_t? {
        var element: AXUIElement?
        var pid: pid_t = 0
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success,
              let element, AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    private func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value as? String
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

    // A fresh event reports the cursor in CG coordinates, so there is no AppKit
    // flip to get wrong on secondary displays.
    if let cursor = CGEvent(source: nil)?.location, let app = monitor.findApp(at: cursor) {
        monitor.lastQuitTime = now
        app.terminate()
        DispatchQueue.main.async { monitor.onQuit?(app) }
    }
    return nil
}
