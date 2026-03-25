import Cocoa
import ApplicationServices

/// Intercepts ⌘Q while Mission Control is active and quits
/// the app whose window thumbnail is under the cursor.
class MissionControlQuit {
    fileprivate var eventTap: CFMachPort?

    func start() {
        // Prompt for Accessibility permission if needed
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            print("⚠️  Grant Accessibility permission in System Settings → Privacy & Security → Accessibility")
        }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ Failed to create event tap – is Accessibility permission granted?")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("✅ MissionQuit is running – ⌘Q in Mission Control will quit the hovered app")
    }

    // MARK: - Mission Control detection

    /// Checks if Mission Control is currently showing by looking for
    /// Dock-owned windows that only appear during Mission Control.
    func isMissionControlActive() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        for win in windowList {
            let owner = win[kCGWindowOwnerName as String] as? String
            let name = win[kCGWindowName as String] as? String
            let layer = win[kCGWindowLayer as String] as? Int

            if owner == "Dock" {
                if let layer = layer, layer >= 20 {
                    return true
                }
                if let name = name,
                   name.contains("Mission Control") || name.contains("Exposé") {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Find app under cursor

    /// Uses the Accessibility API to find which app's window thumbnail
    /// the cursor is hovering over in Mission Control.
    func findAppUnderCursor() -> NSRunningApplication? {
        let mouseLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        // Convert AppKit coords (origin bottom-left) to CG coords (origin top-left)
        let cgPoint = CGPoint(x: mouseLocation.x, y: screenHeight - mouseLocation.y)

        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            systemWide, Float(cgPoint.x), Float(cgPoint.y), &element
        )

        guard result == .success, let element = element else { return nil }

        // Walk up the AX hierarchy to find an element with a title
        if let app = appFromAXElement(element) {
            return app
        }

        return nil
    }

    /// Extracts a running application from an AX element by matching its
    /// title against running app names, walking up the hierarchy if needed.
    private func appFromAXElement(_ element: AXUIElement) -> NSRunningApplication? {
        var current: AXUIElement? = element
        var visited = 0

        while let el = current, visited < 10 {
            visited += 1

            // Check title attribute
            if let title = axStringAttribute(el, kAXTitleAttribute) {
                if let app = matchAppByName(title) {
                    return app
                }
            }

            // Check description
            if let desc = axStringAttribute(el, kAXDescriptionAttribute) {
                if let app = matchAppByName(desc) {
                    return app
                }
            }

            // Check value
            if let value = axStringAttribute(el, kAXValueAttribute) {
                if let app = matchAppByName(value) {
                    return app
                }
            }

            // Walk up to parent
            var parent: AnyObject?
            let err = AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent)
            if err == .success {
                current = (parent as! AXUIElement)
            } else {
                break
            }
        }

        return nil
    }

    private func axStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success else { return nil }
        return value as? String
    }

    private func matchAppByName(_ name: String) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular // only GUI apps
        }

        // Exact match on localized name
        if let app = apps.first(where: { $0.localizedName == name }) {
            return app
        }

        // Partial / case-insensitive match
        let lower = name.lowercased()
        if let app = apps.first(where: { ($0.localizedName?.lowercased() ?? "").contains(lower) }) {
            return app
        }
        if let app = apps.first(where: { lower.contains($0.localizedName?.lowercased() ?? "🚫") }) {
            return app
        }

        return nil
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

    // Only care about keyDown
    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // ⌘Q → keycode 12 (Q) + command flag
    guard keyCode == 12, flags.contains(.maskCommand) else {
        return Unmanaged.passUnretained(event)
    }

    // Only intercept when Mission Control is active
    guard monitor.isMissionControlActive() else {
        return Unmanaged.passUnretained(event)
    }

    // Find and quit the app under the cursor
    if let app = monitor.findAppUnderCursor() {
        print("🔴 Quitting \(app.localizedName ?? "unknown")")
        app.terminate()
        return nil // swallow the event
    }

    // Couldn't identify an app – let ⌘Q pass through
    return Unmanaged.passUnretained(event)
}
