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
extension AppDelegate: NSMenuItemValidation {

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

    @IBAction func freezeAction(_ sender: NSMenuItem) {

        if let controller = windowController {
            if controller.isFrozen {
                controller.unfreeze()
            } else {
                controller.freeze()
            }
        }
    }

    @IBAction func backgroundAction(_ sender: NSMenuItem) {

        if let controller = windowController {
            controller.invisible.toggle()
        }
    }

    @IBAction func recorderAction(_ sender: NSMenuItem) {

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

    @IBAction func loadSettingsAction(_ sender: NSMenuItem) {
        
        let panel = NSOpenPanel()
        panel.title = "Load Settings"
        panel.allowedContentTypes = [.plainText]
        
        if panel.runModal() == .OK {
            
            if let url = panel.url {
                do {
                    try ShaderLibrary.shared.currentShader.loadSettings(url: url)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to load settings"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    @IBAction func saveSettingsAction(_ sender: NSMenuItem) {
        
        let panel = NSSavePanel()
        panel.title = "Save Settings"
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "settings.txt"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                let shader = ShaderLibrary.shared.currentShader
                try? shader.saveSettings(url: url)
            }
        }
    }

    @IBAction func resetZoom(_ sender: NSMenuItem) {

        if let metalView = windowController?.metalView {

            metalView.zoom = 1.0
            metalView.shift = [0, 0];
        }
    }

    @IBAction func zoomIn(_ sender: NSMenuItem) {

        if let metalView = windowController?.metalView {
            
            let oldCenter = metalView.map(coord: [0.5,0.5])
            metalView.zoom += 0.5
            let newCenter = metalView.map(coord: [0.5,0.5])
            metalView.shift += oldCenter - newCenter;
        }
    }

    @IBAction func zoomOut(_ sender: NSMenuItem) {

        if let metalView = windowController?.metalView {
            
            let oldCenter = metalView.map(coord: [0.5,0.5])
            metalView.zoom -= 0.5
            let newCenter = metalView.map(coord: [0.5,0.5])
            metalView.shift += oldCenter - newCenter;
        }
    }
}
