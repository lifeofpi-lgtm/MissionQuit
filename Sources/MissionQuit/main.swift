import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
