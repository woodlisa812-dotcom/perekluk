import AppKit
import Foundation
import PereklukCore

setbuf(stdout, nil)

let delegate = AppDelegate()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
