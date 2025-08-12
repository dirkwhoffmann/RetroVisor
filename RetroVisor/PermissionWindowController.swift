// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class PermissionWindowController: NSWindowController  {

    override func windowDidLoad() {

        if let window = window {

            window.hasShadow = true
            window.titleVisibility = .hidden
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable,
                                .nonactivatingPanel, .fullSizeContentView]
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
