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

    override func viewDidLoad() {

        print("GeneralPreferencesViewController.viewDidLoad")
        refresh()
    }

    var appDelegate: AppDelegate { NSApp.delegate as! AppDelegate }
    var recorder: ScreenRecorder? { appDelegate.recorder }

    func refresh() {

        fullCaptureButton.state = recorder?.responsive == true ? .on : .off
        areaCaptureButton.state = recorder?.responsive == false ? .on : .off
    }

    @IBAction func fullCaptureButton(_ sender: NSButton) {

        recorder?.responsive = sender.state == .on
        refresh()
    }

    @IBAction func areaCaptureButton(_ sender: NSButton) {

        recorder?.responsive = sender.state == .off
        refresh()
    }
}
