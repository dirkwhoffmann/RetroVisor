// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

@main @MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!

    var appDelegate: AppDelegate { NSApp.delegate as! AppDelegate }

    // Customizable shader parameters
    var crtUniforms = CrtUniforms.defaults

    var windowController: WindowController? {
        return NSApplication.shared.windows.first?.windowController as? WindowController
    }
    var recorder: Streamer? {
        return windowController?.streamer
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {

        windowController?.unfreeze()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {

        windowController?.unfreeze()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        Task {

            if await Streamer.canRecord {

                showEffectWindow()

            } else {

                showPermissionWindow()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func showEffectWindow() {

        let sb = NSStoryboard(name: "Main", bundle: nil)
        if let wc = sb.instantiateController(withIdentifier: "EffectWindow") as? NSWindowController {
            createStatusBarMenu()
            wc.window?.setContentSize(NSSize(width: 800, height: 600))
            wc.window?.center()
            wc.showWindow(self)
        }
    }

    func showPermissionWindow() {

        print("No permissions")
        let sb = NSStoryboard(name: "Main", bundle: nil)
        if let wc = sb.instantiateController(withIdentifier: "PermissionWindow") as? NSWindowController {
            wc.window?.setContentSize(NSSize(width: 800, height: 600))
            wc.window?.center()
            wc.showWindow(self)
        }
    }

    @IBAction func showPreferencesWindow(_ sender: Any?) {

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let wc = storyboard.instantiateController(withIdentifier: "PreferencesWindowController") as? NSWindowController {
            wc.showWindow(self)
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

}

extension Bundle {

    var appName: String {
        object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
    }
}
