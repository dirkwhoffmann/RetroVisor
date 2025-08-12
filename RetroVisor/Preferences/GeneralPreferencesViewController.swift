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

    var app: AppDelegate { NSApp.delegate as! AppDelegate }
    var streamer: Streamer? { app.streamer }

    @IBOutlet weak var fpsButton: NSPopUpButton!
    @IBOutlet weak var fpsField: NSTextField!
    @IBOutlet weak var fpsHelp: NSTextField!
    @IBOutlet weak var queueSlider: NSSlider!
    @IBOutlet weak var queueHelp: NSTextField!
    @IBOutlet weak var queueLabel: NSTextField!
    @IBOutlet weak var captureModeButton: NSPopUpButton!
    @IBOutlet weak var captureModeHelp: NSTextField!

    override func viewDidLoad() {

        refresh()
    }

    func refresh() {

        queueLabel.stringValue = "\(queueSlider.intValue) frames"
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
