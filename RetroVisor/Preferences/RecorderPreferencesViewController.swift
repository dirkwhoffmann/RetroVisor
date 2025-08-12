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
    var streamer: Streamer? { app.streamer }
    var recorder: Recorder? { app.recorder }
    var metalView: MetalView? { app.windowController?.metalView }

    // Video settings
    @IBOutlet weak var videoTypeButton: NSPopUpButton!
    @IBOutlet weak var videoCodecButton: NSPopUpButton!
    @IBOutlet weak var videoResultionButton: NSPopUpButton!
    @IBOutlet weak var videoWidthField: NSTextField!
    @IBOutlet weak var videoHeightField: NSTextField!
    @IBOutlet weak var videoSizeLabel: NSTextField!
    @IBOutlet weak var videoBitRateButton: NSPopUpButton!
    @IBOutlet weak var videoBitRateField: NSTextField!
    @IBOutlet weak var videoQualityButton: NSPopUpButton!
    @IBOutlet weak var videoQualityField: NSTextField!

    // Audio settings
    @IBOutlet weak var audioFormatButton: NSPopUpButton!
    @IBOutlet weak var audioFormatLabel: NSTextField!
    @IBOutlet weak var audioSampleRateLabel: NSTextField!
    @IBOutlet weak var audioSampleRateButton: NSPopUpButton!
    @IBOutlet weak var audioSampleRateField: NSTextField!
    @IBOutlet weak var audioBitRateLabel: NSTextField!
    @IBOutlet weak var audioBitRateButton: NSPopUpButton!
    @IBOutlet weak var audioBitRateField: NSTextField!

    override func viewDidLoad() {

        refresh()
    }

    func refresh() {

        refreshVideo()
        refreshAudio()
    }

    func refreshVideo() {

        guard let settings = recorder?.settings else { return }

        if !videoTypeButton.selectItem(withTag: settings.videoType.rawValue) {
            fatalError()
        }
        if !videoCodecButton.selectItem(withTag: settings.codec.rawValue) {
            fatalError()
        }
        if !videoResultionButton.selectItem(withTag: settings.size.shadowed ? 0 : 1) {
            fatalError()
        }
        if !videoBitRateButton.selectItem(withTag: settings.bitRate.shadowed ? 0 : 1) {
            fatalError()
        }
        if !videoQualityButton.selectItem(withTag: settings.quality.shadowed ? 0 : 1) {
            fatalError()
        }

        videoWidthField.integerValue = Int(settings.size.rawValue.width)
        videoWidthField.isHidden = settings.size.shadowed
        videoSizeLabel.isHidden = settings.size.shadowed

        videoHeightField.integerValue = Int(settings.size.rawValue.height)
        videoHeightField.isHidden = settings.size.shadowed

        videoBitRateField.integerValue = Int(settings.bitRate.rawValue)
        videoBitRateField.isHidden = settings.bitRate.shadowed

        videoQualityField.integerValue = Int(settings.quality.rawValue)
        videoQualityField.isHidden = settings.quality.shadowed

        if let size = settings.size.value {
            let resolution = RecorderSettings.VideoResolution.from(size: size)
            videoResultionButton.item(at: 1)?.title = resolution.description
        } else {
            videoResultionButton.item(at: 1)?.title = "Custom"
        }
    }

    func refreshAudio() {

        guard let settings = recorder?.settings else { return }

        let noAudio = settings.audioFormat == .none

        if !audioFormatButton.selectItem(withTag: settings.audioFormat.rawValue) {
            fatalError()
        }
        if !audioSampleRateButton.selectItem(withTag: settings.audioSampleRate.shadowed ? 0 : 1) {
            fatalError()
        }
        if !audioBitRateButton.selectItem(withTag: settings.audioBitRate.shadowed ? 0 : 1) {
            fatalError()
        }

        audioSampleRateLabel.isHidden = noAudio
        audioSampleRateButton.isHidden = noAudio
        audioSampleRateField.integerValue = Int(settings.audioSampleRate.rawValue)
        audioSampleRateField.isHidden = settings.audioSampleRate.shadowed || noAudio

        audioBitRateLabel.isHidden = noAudio
        audioBitRateButton.isHidden = noAudio
        audioBitRateField.integerValue = Int(settings.audioBitRate.rawValue)
        audioBitRateField.isHidden = settings.audioBitRate.shadowed || noAudio
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

    @IBAction func videoResolutionAction(_ sender: NSPopUpButton) {

        recorder?.settings.size.shadowed = sender.selectedTag() == 0
        refresh()
    }

    @IBAction func videoWidthAction(_ sender: NSTextField) {

        recorder?.settings.size.rawValue.width = CGFloat(sender.integerValue)
        refresh()
    }

    @IBAction func videoHeightAction(_ sender: NSTextField) {

        recorder?.settings.size.rawValue.height = CGFloat(sender.integerValue)
        refresh()
    }

    @IBAction func videoBitRateAction(_ sender: NSPopUpButton) {

        recorder?.settings.bitRate.shadowed = sender.selectedTag() == 0
        refresh()
    }

    @IBAction func videoBitrateValueAction(_ sender: NSTextField) {

        recorder?.settings.bitRate.rawValue = sender.integerValue
        refresh()
    }

    @IBAction func videoQualityAction(_ sender: NSPopUpButton) {

        recorder?.settings.quality.shadowed = sender.selectedTag() == 0
        refresh()
    }

    @IBAction func videoQualityValueAction(_ sender: NSTextField) {

        recorder?.settings.quality.rawValue = CGFloat(sender.floatValue)
        refresh()
    }

    @IBAction func audioFormatAction(_ sender: NSPopUpButton) {

        let format = RecorderSettings.AudioFormat(rawValue: sender.selectedTag())!
        recorder?.settings.audioFormat = format
        refresh()
    }

    @IBAction func audioSampleRateAction(_ sender: NSPopUpButton) {

        recorder?.settings.audioSampleRate.shadowed = sender.selectedTag() == 0
        refresh()
    }

    @IBAction func audioSampleRateValueAction(_ sender: NSTextField) {

        recorder?.settings.audioSampleRate.rawValue = sender.integerValue
        refresh()
    }
    @IBAction func audioBitRateAction(_ sender: NSPopUpButton) {

        recorder?.settings.audioBitRate.shadowed = sender.selectedTag() == 0
        refresh()
    }

    @IBAction func audioBitRateValueAction(_ sender: NSTextField) {

        recorder?.settings.audioBitRate.rawValue = sender.integerValue
        refresh()
    }

    @IBAction func profileAction(_ sender: NSPopUpButton) {

        switch (sender.selectedTag()) {
        case 0: recorder?.settings = RecorderSettings.Preset.systemDefault.settings
        case 1: recorder?.settings = RecorderSettings.Preset.youtube1080p.settings
        case 2: recorder?.settings = RecorderSettings.Preset.youtube4k.settings
        case 3: recorder?.settings = RecorderSettings.Preset.proResHQ.settings
        case 4: recorder?.settings = RecorderSettings.Preset.smallFile.settings
        default: break
        }
        refresh()
    }
}
