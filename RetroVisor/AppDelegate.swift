// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!

    // Window controller of the settings dialog
    var settingsWindowController: SettingsWindowController?

    // Customizable shader parameters
    var uniforms = CrtUniforms.defaults

    var windowController: MyWindowController? {
        return NSApplication.shared.windows.first?.windowController as? MyWindowController
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {

        windowController?.unfreeze()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {

        windowController?.unfreeze()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        if let window = NSApplication.shared.windows.first {
            let frame = NSRect(x: 300, y: 300, width: 800, height: 600)
            window.setFrame(frame, display: true)
            window.makeKeyAndOrderFront(nil)

            createStatusBarMenu()
        }
    }

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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @objc func restartScreenCapturer(_ sender: Any?) {
        print("🔁 Restart Screen Capturer clicked")
        // Your restart logic goes here
    }

    @objc func liveDraggingAction(_ sender: Any?) {
        print("🔁 liveDraggingAction")
    }

    @IBAction func showSettings(_ sender: Any?) {

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(windowNibName: "SettingsWindow")
        }
        settingsWindowController?.showWindow(self)
    }

}

extension Bundle {

    var appName: String {
        object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
    }
}
