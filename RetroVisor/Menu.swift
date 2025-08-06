// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

extension AppDelegate {

    //
    // Status Bar Menu
    //
    
    func createStatusBarMenu() {

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "RetroVisorTemplate")!
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(
            title: "Live Dragging",
            action: #selector(liveDraggingAction(_:)),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Restart Screen Capturer",
            action: #selector(restartScreenCapturer(_:)),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit \(Bundle.main.appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        ))

        statusItem.menu = menu
    }

    @objc func restartScreenCapturer(_ sender: Any?) {
        print("🔁 Restart Screen Capturer clicked")
        // Your restart logic goes here
    }

    @objc func liveDraggingAction(_ sender: Any?) {
        print("🔁 liveDraggingAction")
    }
}
