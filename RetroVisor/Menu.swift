// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import UniformTypeIdentifiers

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

        // Right now, we use the same icon regardless of the recording state
        if let button = statusItem?.button {
            button.image = NSImage(named: "RetroVisorTemplate")!
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

        let background = NSMenuItem(
            title: "Run in Background",
            action: #selector(backgroundAction(_:)),
            keyEquivalent: ""
        )
        freeze.target = self

        let record = NSMenuItem(
            title: "Start Recording",
            action: #selector(recorderAction(_:)),
            keyEquivalent: ""
        )
        record.target = self

        let quit = NSMenuItem(
            title: "Quit \(Bundle.main.appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )

        menu.addItem(freeze)
        menu.addItem(background)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(record)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quit)

        statusItem?.menu = menu
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

        case #selector(AppDelegate.backgroundAction(_:)):

            if windowController?.invisible == true {
                menuItem.title = "Run Effect Window in Foreground"
            } else {
                menuItem.title = "Run Effect Window in Background"
            }
            return true

        case #selector(AppDelegate.recorderAction(_:)):

            if recorder.isRecording == true {
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

    @objc func backgroundAction(_ sender: Any?) {

        if let controller = windowController {
            controller.invisible.toggle()
        }
    }

    @objc func recorderAction(_ sender: Any?) {

        guard let texture = windowController?.metalView?.outTexture else { return }

        if recorder.isRecording {

            recorder.stopRecording { }

        } else {

            // let type = recorder.settings.videoType.utType
            let panel = NSSavePanel()
            panel.title = "Save Recording"
            panel.allowedContentTypes = [recorder.settings.videoType.utType]
            panel.nameFieldStringValue = "Recording"

            if panel.runModal() == .OK {
                if let url = panel.url {
                    self.recorder.startRecording(to: url, width: texture.width, height: texture.height)
                }
            }
        }
    }
}
