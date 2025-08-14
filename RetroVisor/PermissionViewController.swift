// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class PermissionViewController: NSViewController {

    @IBOutlet weak var permissionIcon: NSImageView!
    @IBOutlet weak var titleText: NSTextField!
    @IBOutlet weak var captureText: NSTextField!

    override func viewDidLoad() {

        captureText.stringValue = "🛑 Screen Capture Permissions"
    }
}
