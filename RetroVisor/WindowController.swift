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

class WindowController: NSWindowController  {

    var viewController : ViewController? { return self.contentViewController as? ViewController }
    var trackingWindow : TrackingWindow? { return window as? TrackingWindow }

    // The screen recorder
    var recorder = ScreenRecorder()

    // Indicates if the window is passive (click-through state)
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
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable,
            .nonactivatingPanel, .fullSizeContentView]
        window.contentView?.layer?.borderColor = NSColor.systemBlue.cgColor
        window.contentView?.layer?.borderWidth = 2
        window.contentView?.layer?.cornerRadius = 10
    }
}

extension WindowController: TrackingWindowDelegate {

    func windowDidStartResize(_ window: TrackingWindow) {

        viewController!.intensity.target = 1.0
        viewController!.intensity.steps = 15
    }

    func windowDidStopResize(_ window: TrackingWindow) {

        viewController!.intensity.target = 0.0
        viewController!.intensity.steps = 15
        viewController!.updateTextures(rect: window.frame)

        recorder.updateRects()
        recorder.relaunchIfNeeded()
    }

    func windowDidStartDrag(_ window: TrackingWindow) {

        viewController!.intensity.target = 1.0
        viewController!.intensity.steps = 25
    }

    func windowDidStopDrag(_ window: TrackingWindow) {

        viewController!.intensity.target = 0.0
        viewController!.intensity.steps = 25

        recorder.updateRects()
        recorder.relaunchIfNeeded()

        /*
        print("window: \(window.frame)")
        print("sourceRect: \(recorder.sourceRect ?? .null)")
        print("captureRect: \(recorder.captureRect ?? .null)")
        print("textureRect: \(recorder.textureRect ?? .null)")
        */
    }

    func windowWasDoubleClicked(_ window: TrackingWindow) {

        freeze()
    }

    func windowDidChangeScreen(_ window: TrackingWindow) {

        recorder.relaunch()
    }
}

extension WindowController: ScreenRecorderDelegate {

    func textureRectDidChange(rect: CGRect?) {

        viewController?.updateVertexBuffers(rect)
    }

    func recorderDidStart() {

        print("recorderDidRestart")
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {

        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {

            // Process the pixel buffer in the view controller
            DispatchQueue.main.async { [weak self] in
                if let vc = self?.contentViewController as? ViewController {
                    vc.update(with: pixelBuffer)
                }
            }
        }
    }
}
