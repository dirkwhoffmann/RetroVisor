// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

@MainActor
extension AppDelegate : NSMenuItemValidation {

    //
    // Status Bar Menu
    //
    
    func createStatusBarMenu() {

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "RetroVisorTemplate")!
        }

        let menu = NSMenu()

        let freeze = NSMenuItem(
            title: "Freeze",
            action: #selector(freezeAction(_:)),
            keyEquivalent: ""
        )
        freeze.target = self

        let liveDragging = NSMenuItem(
            title: "Live Dragging",
            action: #selector(liveDraggingAction(_:)),
            keyEquivalent: ""
        )
        liveDragging.target = self

        let restart = NSMenuItem(
            title: "Restart Screen Recorder",
            action: #selector(restartScreenRecorder(_:)),
            keyEquivalent: ""
        )
        restart.target = self

        let quit = NSMenuItem(
            title: "Quit \(Bundle.main.appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )

        menu.addItem(freeze)
        menu.addItem(restart)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(liveDragging)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {

        switch menuItem.action {

        case #selector(AppDelegate.freezeAction(_:)):
            menuItem.title = windowController?.isFrozen == true ? "Unfreeze" : "Freeze"
            return true

        case #selector(AppDelegate.liveDraggingAction(_:)):
            menuItem.state = recorder?.responsive == true ? .on : .off
            return true

        default:
            return true
        }
    }

    @objc func freezeAction(_ sender: Any?) {

        if let controller = windowController {
            controller.isFrozen ? controller.unfreeze() : controller.freeze()
        }
    }

    @objc func liveDraggingAction(_ sender: Any?) {

        recorder?.responsive.toggle()
    }

    @objc func restartScreenRecorder(_ sender: Any?) {

        recorder?.relaunch()
    }
}
