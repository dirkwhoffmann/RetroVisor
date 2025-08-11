// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class GeneralPreferencesViewController: NSViewController {

    @IBOutlet weak var fullCaptureButton: NSButton!
    @IBOutlet weak var areaCaptureButton: NSButton!

    var app: AppDelegate { NSApp.delegate as! AppDelegate }
    var streamer: Streamer? { app.streamer }

    override func viewDidLoad() {

        refresh()
    }

    func refresh() {

        fullCaptureButton.state = streamer?.captureMode == .entire ? .on : .off
        areaCaptureButton.state = streamer?.captureMode == .cutout ? .on : .off
    }

    @IBAction func fullCaptureButton(_ sender: NSButton) {

        streamer?.captureMode = sender.state == .on ? .entire : .cutout
        refresh()
    }

    @IBAction func areaCaptureButton(_ sender: NSButton) {

        streamer?.captureMode = sender.state == .on ? .cutout : .entire
        refresh()
    }
}
