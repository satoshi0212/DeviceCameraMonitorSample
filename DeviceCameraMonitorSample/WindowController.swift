import Foundation
import Cocoa

class WindowController: NSWindowController {

}

extension WindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(self)
    }
}
