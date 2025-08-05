// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

/*
class ClickThroughView: NSView {

}
*/

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var uniforms = CrtUniforms.defaults
    
    var settingsWindowController: SettingsWindowController?

    var windowController: MyWindowController? {
        return NSApplication.shared.windows.first?.windowController as? MyWindowController
    }

    /*
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {

        windowController?.unfreeze()
        return true
    }
     */

    func applicationDidBecomeActive(_ notification: Notification) {

        windowController?.unfreeze()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        if let window = NSApplication.shared.windows.first {
            let frame = NSRect(x: 300, y: 300, width: 800, height: 600)
            window.setFrame(frame, display: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @IBAction func showSettings(_ sender: Any?) {

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(windowNibName: "SettingsWindow")
        }
        settingsWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true) // optional, bring to front
    }

}
