// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class RecorderPreferencesViewController: NSViewController {

    var app: AppDelegate { NSApp.delegate as! AppDelegate }
    var recorder: Recorder? { app.recorder }

    // Video settings
    @IBOutlet weak var videoTypeButton: NSPopUpButton!
    @IBOutlet weak var videoCodecButton: NSPopUpButton!
    @IBOutlet weak var videoFrameRateButton: NSPopUpButton!
    @IBOutlet weak var videoResultionButton: NSPopUpButton!
    @IBOutlet weak var videoWidthField: NSTextField!
    @IBOutlet weak var videoHeightField: NSTextField!
    @IBOutlet weak var videoBitRateButton: NSPopUpButton!
    @IBOutlet weak var videoBitRateField: NSTextField!

    // Audio settings
    @IBOutlet weak var audioFormatButton: NSPopUpButton!
    @IBOutlet weak var audioSampleRateButton: NSPopUpButton!
    @IBOutlet weak var audioBitRateButton: NSPopUpButton!
    @IBOutlet weak var audioBitRateField: NSTextField!

    func refresh() {

    }

    @IBAction func videoTypeAction(_ sender: NSPopUpButton) {

        let type = RecorderSettings.VideoType(rawValue: sender.selectedTag())!
        recorder?.settings.videoType = type
        refresh()
    }

    @IBAction func videoCodecAction(_ sender: NSPopUpButton) {

        let codec = RecorderSettings.VideoCodec(rawValue: sender.selectedTag())!
        recorder?.settings.codec = codec
        refresh()
    }
}
