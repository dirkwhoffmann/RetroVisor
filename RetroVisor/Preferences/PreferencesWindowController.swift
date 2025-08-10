// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class PreferencesWindowController: NSWindowController {

    /*
    static let shared = PreferencesWindowController()

    private init() {

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let splitVC = storyboard.instantiateController(withIdentifier: "PreferencesSplitViewController") as! PreferencesSplitViewController
        let window = NSWindow(contentViewController: splitVC)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 800, height: 500))
        super.init(window: window)
    }
    */

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func show() {
        self.showWindow(nil)
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
