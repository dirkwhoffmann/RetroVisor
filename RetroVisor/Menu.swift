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

    func updateStatusBarMenuIcon(recording: Bool) {

        if let button = statusItem.button {
            button.image = NSImage(named: recording ? "RecordingTemplate" : "RetroVisorTemplate")!
        }
    }

    func createStatusBarMenu() {

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusBarMenuIcon(recording: false)

        let menu = NSMenu()

        let freeze = NSMenuItem(
            title: "Freeze Effect Window",
            action: #selector(freezeAction(_:)),
            keyEquivalent: ""
        )
        freeze.target = self

        let record = NSMenuItem(
            title: "Stop recording",
            action: #selector(recorderAction(_:)),
            keyEquivalent: ""
        )
        record.target = self

        let restart = NSMenuItem(
            title: "Restart Stream Capturer",
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
        menu.addItem(record)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(restart)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {

        switch menuItem.action {

        case #selector(AppDelegate.freezeAction(_:)):

            if windowController?.isFrozen == true {
                menuItem.title = "Unfreeze Effect Window"
            } else {
                menuItem.title = "Freeze Effect Window"
            }
            return true

        case #selector(AppDelegate.recorderAction(_:)):

            if recorder?.isRecording == true {
                menuItem.title = "Stop Recording"
            } else {
                menuItem.title = "Start Recording"
            }
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

    @objc func restartScreenRecorder(_ sender: Any?) {

        recorder?.relaunch()
    }

    @objc func recorderAction(_ sender: Any?) {

        guard let recorder = recorder else { return }
        guard let texture = windowController?.metalView?.outTexture else { return }

        if recorder.isRecording {
            recorder.stopRecording { }
        } else {
            recorder.startRecording(width: texture.width, height: texture.height)
        }
    }

}
