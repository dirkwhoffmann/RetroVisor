// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import ScreenCaptureKit

class ClickThroughView: NSView {

}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: TransparentWindow!
    var preview: Preview!

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {

        window.unfreeze()
        return true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        if let window = NSApplication.shared.windows.first {
                let frame = NSRect(x: 300, y: 300, width: 800, height: 600)
                window.setFrame(frame, display: true)
                window.makeKeyAndOrderFront(nil)
            }
        
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 800, height: 600)
        let windowSize = CGSize(width: 400, height: 300)
        let windowOrigin = CGPoint(
            x: (screenSize.width - windowSize.width) / 2,
            y: (screenSize.height - windowSize.height) / 2
        )

        let window = TransparentWindow(
            contentRect: NSRect(origin: windowOrigin, size: windowSize),
            styleMask: [],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2)
        window.hasShadow = true
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        preview = Preview(frame: window.contentView!.bounds)
        preview.wantsLayer = true
        preview.autoresizingMask = [.width, .height]
        window.myview = preview
        window.contentView = preview
        self.window = window
        window.delegate = self
        window.unfreeze()

        Task {
            await window.setup()
        }
    }
}

extension AppDelegate: NSWindowDelegate {

    func windowDidMove(_ notification: Notification) {
        print("windowDidMove")
        window.updateRect()
    }
    func windowDidResize(_ notification: Notification) {
        window.updateRect()
    }
}
