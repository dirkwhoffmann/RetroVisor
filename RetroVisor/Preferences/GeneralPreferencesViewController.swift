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
    
    var streamer: Streamer? { app.streamer }
    var metalView: MetalView? { app.windowController?.metalView }
    
    // Capture Engine
    @IBOutlet weak var fpsButton: NSPopUpButton!
    @IBOutlet weak var fpsField: NSTextField!
    @IBOutlet weak var queueSlider: NSSlider!
    @IBOutlet weak var queueLabel: NSTextField!
    @IBOutlet weak var captureModeButton: NSPopUpButton!
    
    // Resampler
    @IBOutlet weak var resampleButton: NSPopUpButton!
    @IBOutlet weak var resampleXSlider: NSSlider!
    @IBOutlet weak var resampleYSlider: NSSlider!

    // Texture Debugger
    @IBOutlet weak var debugButton: NSPopUpButton!
    @IBOutlet weak var debugModeButton: NSPopUpButton!
    @IBOutlet weak var debugXSlider: NSSlider!
    @IBOutlet weak var debugYSlider: NSSlider!

    override func viewDidLoad() {
        
        fpsButton.toolTip =
        "Sets the number of frames per second the app aims to capture. The actual frame rate may be lower depending on system performance. In automatic mode, the system uses the maximum supported frame rate."
        
        queueSlider.toolTip =
        "Defines how many video frames are buffered before processing. A longer queue improves stability and reduces the risk of drop-outs, but can increase latency. A shorter queue lowers latency but may cause glitches if the system cannot process data in time."
        
        /*
        captureModeButton.toolTip =
        "Configures the recorder to capture the entire screen or only the portion under the effect window. Capturing the entire screen is more resource-intensive but allows for smooth, real-time updates during window drag and resize operations. Recommended for modern systems."
        */
        
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
        guard let uniforms = metalView?.uniforms else { return }
        
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
        captureModeButton.toolTip = settings.captureMode.help
        
        // Resampler
        if !resampleButton.selectItem(withTag: Int(uniforms.resample)) {
            fatalError()
        }
        resampleXSlider.floatValue = uniforms.resampleXY.x * 1000.0
        resampleYSlider.floatValue = uniforms.resampleXY.y * 1000.0

        // Debugger
        if !debugButton.selectItem(withTag: Int(uniforms.debug)) {
            fatalError()
        }
        if !debugModeButton.selectItem(withTag: Int(uniforms.debugMode)) {
            fatalError()
        }
        resampleXSlider.floatValue = uniforms.debugXY.x * 1000.0
        resampleYSlider.floatValue = uniforms.debugXY.y * 1000.0
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
    
    @IBAction func resampleAction(_ sender: NSPopUpButton) {
    
        print("Resample mode: \(sender.selectedTag())")
        metalView!.uniforms.resample = Int32(sender.selectedTag())
    }

    @IBAction func resampleXAction(_ sender: NSSlider) {
        
        print("Down X: \(sender.floatValue)")
        metalView!.uniforms.resampleXY.x = sender.floatValue / 1000.0
    }

    @IBAction func resampleYAction(_ sender: NSSlider) {
        
        print("Down Y: \(sender.floatValue)")
        metalView!.uniforms.resampleXY.y = sender.floatValue / 1000.0
    }
    
    @IBAction func debugAction(_ sender: NSPopUpButton) {
    
        print("Debug: \(sender.selectedTag())")
        metalView!.uniforms.debug = Int32(sender.selectedTag())
    }

    @IBAction func debugModeAction(_ sender: NSPopUpButton) {
    
        print("Debug mode: \(sender.selectedTag())")
        metalView!.uniforms.debugMode = Int32(sender.selectedTag())
    }

    @IBAction func debugXAction(_ sender: NSSlider) {
        
        print("X: \(sender.floatValue)")
        metalView!.uniforms.debugXY.x = sender.floatValue / 1000.0
    }
    
    @IBAction func debugYAction(_ sender: NSSlider) {

        print("Y: \(sender.floatValue)")
        metalView!.uniforms.debugXY.y = sender.floatValue / 1000.0
    }
}
