// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import ScreenCaptureKit

class MyWindowController: NSWindowController  {

    var viewController : MyViewController? { return self.contentViewController as? MyViewController }
    var trackingWindow : TrackingWindow? { return window as? TrackingWindow }

    // The screen recorder
    var recorder = Capturer()

    // Indicates if the window is click-through
    var isFrozen: Bool { return window?.ignoresMouseEvents ?? false }

    override func windowDidLoad() {

        super.windowDidLoad()

        let window = self.window as! TrackingWindow

        // Setup the window
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.trackingDelegate = self
        unfreeze()

        // Setup the recorder
        recorder.delegate = self
        recorder.window = trackingWindow
        recorder.relaunch()
    }

    func freeze() {

        let window = self.window as! TrackingWindow

        window.ignoresMouseEvents = true
        window.styleMask = [.titled, .nonactivatingPanel, .fullSizeContentView]
        window.contentView?.layer?.borderColor = NSColor.systemGray.cgColor
        window.contentView?.layer?.borderWidth = 0
        window.contentView?.layer?.cornerRadius = 10
    }

    func unfreeze() {

        let window = self.window as! TrackingWindow

        window.ignoresMouseEvents = false
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel, .fullSizeContentView]
        window.contentView?.layer?.borderColor = NSColor.systemRed.cgColor
        window.contentView?.layer?.borderWidth = 2
        window.contentView?.layer?.cornerRadius = 10
    }
}

extension MyWindowController: TrackingWindowDelegate {

    func windowDidStartResize(_ window: TrackingWindow) {

        viewController!.intensity.target = 1.0
        viewController!.intensity.steps = 15
    }

    func windowDidStopResize(_ window: TrackingWindow) {

        viewController!.intensity.target = 0.0
        viewController!.intensity.steps = 15
        viewController!.updateIntermediateTexture(width: 1 * Int(window.frame.width), height: 1 * Int(window.frame.height))

        print("windowDidStopResize")
        if recorder.updateRects() { recorder.relaunch() }

        /*
        if !recorder.responsive {
            recorder.capture(window: window)
        }
        */
    }

    func windowDidStartDrag(_ window: TrackingWindow) {

        viewController!.intensity.target = 1.0
        viewController!.intensity.steps = 25
    }

    func windowDidStopDrag(_ window: TrackingWindow) {

        viewController!.intensity.target = 0.0
        viewController!.intensity.steps = 25

        print("windowDidStopDrag")
        if recorder.updateRects() { recorder.relaunch() }

        print("window: \(window.frame)")
        print("sourceRect: \(recorder.sourceRect!)")
        print("captureRect: \(recorder.captureRect!)")
        print("textureRect: \(recorder.textureRect!)")

        print("display: \(recorder.display!.frame)")
        print("screen: \(window.screen!.frame) * \(window.screen!.backingScaleFactor)")
    }

    func windowWasDoubleClicked(_ window: TrackingWindow) {

        freeze()
    }

    func windowDidChangeScreen(_ window: TrackingWindow) {

        recorder.relaunch()
    }
}

extension MyWindowController: CapturerDelegate {

    func textureRectDidChange(rect: CGRect) {

        viewController?.updateTextureRect(rect)
    }
    func captureRectDidChange(rect: CGRect) {

        print("captureRectDidChange \(rect)")
    }

    func recorderDidStart() {

        print("recorderDidRestart")
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        /*
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("Captured buffer size: \(width)x\(height)")
        */

        // Process the pixel buffer in the view controller
        DispatchQueue.main.async { [weak self] in
            if let vc = self?.contentViewController as? MyViewController {
                vc.update(with: pixelBuffer)
            }
        }
    }
}

extension MyWindowController: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {

        switch menuItem.action {

        case #selector(MyWindowController.freezeAction(_:)):
            menuItem.title = isFrozen ? "Unfreeze" : "Freeze"
            return true

        default:
            return true
        }
    }
    
    @IBAction func freezeAction(_ sender: Any!) {

        isFrozen ? unfreeze() : freeze()
    }
}
