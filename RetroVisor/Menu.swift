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
extension WindowController: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {

        switch menuItem.action {

        case #selector(WindowController.freezeAction(_:)):
            menuItem.title = isFrozen ? "Unfreeze" : "Freeze"
            return true

        default:
            return true
        }
    }

    @IBAction func freezeAction(_ sender: Any!) {

        isFrozen ? unfreeze() : freeze()
    }
}

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

        let stopRecording = NSMenuItem(
            title: "Stop recording",
            action: #selector(recorderAction(_:)),
            keyEquivalent: ""
        )
        stopRecording.target = self

        let quit = NSMenuItem(
            title: "Quit \(Bundle.main.appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )

        menu.addItem(freeze)
        menu.addItem(stopRecording)
        menu.addItem(NSMenuItem.separator())
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

        case #selector(AppDelegate.recorderAction(_:)):
            menuItem.title = recorder?.isRecording == true ? "Stop Recording" : "Start Recording"
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

    @objc func recorderAction(_ sender: Any?) {

        guard let recorder = recorder else { return }
        guard let texture = windowController?.viewController?.outTexture else { return }

        if recorder.isRecording {
            print("stopping recorder")
            recorder.stopRecording { }
        } else {
            print("starting recorder")
            recorder.startRecording(width: texture.width, height: texture.height)
        }
    }

}
