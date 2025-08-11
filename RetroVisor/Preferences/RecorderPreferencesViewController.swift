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

    override func viewDidLoad() {

        refresh()
    }

    func refresh() {

        guard let settings = recorder?.settings else { return }

        if !videoTypeButton.selectItem(withTag: settings.videoType.rawValue) {
            fatalError()
        }
        if !videoCodecButton.selectItem(withTag: settings.codec.rawValue) {
            fatalError()
        }
        if !videoFrameRateButton.selectItem(withTag: settings.frameRate ?? 0) {
            fatalError()
        }
        let size = NSSize(width: settings.width, height: settings.height)
        let resolution = RecorderSettings.VideoResolution.from(size: size)
        if !videoResultionButton.selectItem(withTag: resolution.rawValue) {
            fatalError()
        }
        videoWidthField.integerValue = settings.width
        videoHeightField.integerValue = settings.height
        if !videoFrameRateButton.selectItem(withTag: settings.frameRate ?? 0) {
            fatalError()
        }
        videoBitRateButton.selectItem(withTag: settings.bitRate == nil ? 0 : 1)
        videoBitRateField.integerValue = settings.bitRate ?? 0
        videoBitRateField.isHidden = settings.bitRate == nil

        if !audioFormatButton.selectItem(withTag: settings.audioFormat?.rawValue ?? -1) {
            fatalError()
        }
        if !audioSampleRateButton.selectItem(withTag: settings.audioSampleRate ?? 0) {
            fatalError()
        }
        audioBitRateButton.selectItem(withTag: settings.audioBitRate == nil ? 0 : 1)
        audioBitRateField.integerValue = settings.audioBitRate ?? 0
        audioBitRateField.isHidden = settings.audioBitRate == nil
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

    @IBAction func videoFrameRateAction(_ sender: NSPopUpButton) {

        let tag = sender.selectedTag()
        recorder?.settings.frameRate = tag == 0 ? nil : tag
        refresh()
    }

    @IBAction func videoResolutionAction(_ sender: NSPopUpButton) {

        let resolution = RecorderSettings.VideoResolution(rawValue: sender.selectedTag())!

        switch resolution {
        case .custom:
            recorder?.settings.width = videoWidthField.integerValue
            recorder?.settings.width = videoHeightField.integerValue
        case .hd, .fhd, .uhd:
            recorder?.settings.width = Int(resolution.size.width)
            recorder?.settings.height = Int(resolution.size.height)
        }
        refresh()
    }

    @IBAction func videoWidthAction(_ sender: NSTextField) {

        recorder?.settings.width = sender.integerValue
        refresh()
    }

    @IBAction func videoHeightAction(_ sender: NSTextField) {

        recorder?.settings.height = sender.integerValue
        refresh()
    }

    @IBAction func videoBitRateAction(_ sender: NSPopUpButton) {

        switch sender.selectedTag() {
        case 0: recorder?.settings.bitRate = nil
        default: recorder?.settings.bitRate = videoBitRateField.integerValue
        }
        refresh()
    }

    @IBAction func videoBpsAction(_ sender: NSTextField) {

        recorder?.settings.bitRate = sender.integerValue
        refresh()
    }

    @IBAction func audioFormatAction(_ sender: NSPopUpButton) {

        let format = RecorderSettings.AudioFormat(rawValue: sender.selectedTag())!
        recorder?.settings.audioFormat = format
        refresh()
    }

    @IBAction func audioSampleRateAction(_ sender: NSPopUpButton) {

        let tag = sender.selectedTag()
        recorder?.settings.frameRate = tag == 0 ? nil : tag
        refresh()
    }

    @IBAction func audioBitRateAction(_ sender: NSPopUpButton) {

        switch sender.selectedTag() {
        case 0: recorder?.settings.audioBitRate = nil
        default: recorder?.settings.audioBitRate = audioBitRateField.integerValue
        }
        refresh()
    }

    @IBAction func audioBpsAction(_ sender: NSTextField) {

        recorder?.settings.bitRate = sender.integerValue
        refresh()
    }
}
