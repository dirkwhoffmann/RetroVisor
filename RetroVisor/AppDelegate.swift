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
var app: AppDelegate { NSApp.delegate as! AppDelegate }

@main @MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // Gateway to ScreenCaptureKit
    var streamer = Streamer()

    // Gateway to AVAssetWriter
    var recorder = Recorder()

    // Menu bar status item
    var statusItem: NSStatusItem?

    var windowController: WindowController? {
        return NSApplication.shared.windows.first?.windowController as? WindowController
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {

        windowController?.unfreeze()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {

        windowController?.unfreeze()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // TODO: MOVE TO SHADER LIBRARY INIT
        ShaderLibrary.shared.register(CRTEasyShader())
        ShaderLibrary.shared.register(Phosbite())
        ShaderLibrary.shared.register(ColorSplitShader())
        ShaderLibrary.shared.selectShader(at: 2)

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

        let sb = NSStoryboard(name: "Main", bundle: nil)
        if let wc = sb.instantiateController(withIdentifier: "PermissionWindow") as? NSWindowController {
            wc.showWindow(self)
        }
    }

    @IBAction func showPreferencesWindow(_ sender: Any?) {

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let wc = storyboard.instantiateController(withIdentifier: "PreferencesWindowController") as? NSWindowController {

            wc.window?.level = .floating
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
