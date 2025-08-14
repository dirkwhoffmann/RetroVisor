// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class TrackingSliderCell: NSSliderCell {

    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?

    override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
        onDragStart?()
        return super.startTracking(at: startPoint, in: controlView)
    }

    // For macOS 12 and earlier:
    override func stopTracking(last lastPoint: NSPoint, current stopPoint: NSPoint, in controlView: NSView, mouseIsUp flag: Bool) {
        super.stopTracking(last: lastPoint, current: stopPoint, in: controlView, mouseIsUp: flag)
        onDragEnd?()
    }
}

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

        if let cell = queueSlider.cell as? TrackingSliderCell {

            cell.onDragEnd = { [weak self] in

                // Fired when the user stops operating the slider
                guard let self = self else { return }
                if queueSlider.integerValue != streamer?.settings.queueDepth {

                    streamer?.settings.queueDepth = queueSlider.integerValue
                    streamer?.relaunch()
                }
            }
        }

        refresh()
    }

    func refresh() {

        guard let settings = streamer?.settings else { return }

        // Frame rate
        if !fpsButton.selectItem(withTag: settings.fpsMode.rawValue) {
            fatalError()
        }
        fpsField.integerValue = settings.fps
        fpsField.isHidden = settings.fpsMode == .automatic

        // Queue depth
        queueSlider.integerValue = settings.queueDepth
        queueLabel.stringValue = "\(queueSlider.intValue) frames"
        if !captureModeButton.selectItem(withTag: settings.captureMode.rawValue) {
            fatalError()
        }

        // Capture mode
        captureModeHelp.stringValue = settings.captureMode.help
    }

    @IBAction func fpsModeAction(_ sender: NSPopUpButton) {

        let mode = StreamerSettings.FpsMode(rawValue: sender.selectedTag())!
        if mode != streamer?.settings.fpsMode {

            streamer?.settings.fpsMode = mode
            streamer?.relaunch()
        }
        refresh()
    }

    @IBAction func fpsValueAction(_ sender: NSTextField) {

        if streamer?.settings.fps != sender.integerValue {

            streamer?.settings.fps = sender.integerValue
            streamer?.relaunch()
        }
        refresh()
    }

    @IBAction func queueSliderAction(_ sender: NSSlider) {

        queueLabel.stringValue = "\(queueSlider.intValue) frames"
    }

    @IBAction func captureModeAction(_ sender: NSPopUpButton) {

        let mode = StreamerSettings.CaptureMode(rawValue: sender.selectedTag())!
        if mode != streamer?.settings.captureMode {

            streamer?.settings.captureMode = mode
            streamer?.relaunch()
        }
        refresh()
    }
}
