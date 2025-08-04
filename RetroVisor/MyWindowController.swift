// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import ScreenCaptureKit

class MyWindowController: NSWindowController {

    var recorder = ScreenRecorder()
    var viewController : MyViewController? { return self.contentViewController as? MyViewController }
    var trackingWindow : TrackingWindow? { return window as? TrackingWindow }

    var liveMode: Bool = false
    var debounceTimer: Timer?

    // Source rectangle of the screen capturer
    var captureRect: CGRect?

    // Displayed texture cutout
    var textureRect: CGRect?

    func updateRects() {

        updateRects(area: .zero)
    }

    func updateRects(area: CGRect) {

        print("updateRects(\(area))")

        guard let display = recorder.display else { return }

        if liveMode == false {

            let newCaptureRect = display.frame
            let newTextureRect = recorder.viewRectInScreenPixels(view: window!.contentView!)!
            print("newCaptureRect = \(newCaptureRect)")
            print("newTextureRect = \(newTextureRect)")

            if captureRect != newCaptureRect {
                print("Need to restart server")
            }
            captureRect = newCaptureRect
            textureRect = newTextureRect
        }
    }

    override func windowDidLoad() {

        super.windowDidLoad()

        print("windowDidLoad")

        // Example customizations:
        if let window = self.window {

            window.isOpaque = false
            // window.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2)
            window.hasShadow = true
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.delegate = self
            unfreeze()

            // updateRects()

            Task {
                // Setup the recorder
                recorder.window = self.window
                await recorder.launch(receiver: self)
                let rect = recorder.viewRectInScreenPixels(view: window.contentView!)!
                viewController?.updateTextureRect(rect)
            }
        }
    }

    func freeze() {

        if let window = self.window {

            window.ignoresMouseEvents = true
            window.styleMask = [.titled, .nonactivatingPanel, .fullSizeContentView]
            window.backgroundColor = NSColor.gray.withAlphaComponent(0.2)
            window.contentView?.layer?.borderColor = NSColor.systemGray.cgColor
            window.contentView?.layer?.borderWidth = 0
            window.contentView?.layer?.cornerRadius = 10
        }
    }

    func unfreeze() {

        if let window = self.window {

            window.ignoresMouseEvents = false
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel, .fullSizeContentView]
            window.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2)
            window.contentView?.layer?.borderColor = NSColor.systemBlue.cgColor
            window.contentView?.layer?.borderWidth = 2
            window.contentView?.layer?.cornerRadius = 10
        }
    }
}

extension MyWindowController: TrackingWindowDelegate {

    func windowDidMove(_ notification: Notification) {
        // print("\(viewController?.frame ?? 0) windowDidMove: \(window?.frame ?? NSRect.zero)")
    }

    func windowDidStartResize(_ window: TrackingWindow) {
        print("windowDidStartResize")
        // viewController!.time = 1.0
        viewController!.intensity.target = 1.0
        viewController!.intensity.steps = 15
    }

    func windowDidStopResize(_ window: TrackingWindow) {
        print("windowDidStopResize \(window.frame) \(window.liveFrame)")
        // viewController!.time = 0.0
        viewController!.intensity.target = 0.0
        viewController!.intensity.steps = 15
        viewController!.updateIntermediateTexture(width: 1 * Int(window.frame.width), height: 1 * Int(window.frame.height))
    }

    func windowDidStartDrag(_ window: TrackingWindow) {
        print("Started dragging")
        // viewController!.time = 1.0
        viewController!.intensity.target = 1.0
        viewController!.intensity.steps = 25
    }

    func windowDidStopDrag(_ window: TrackingWindow) {
        print("Stopped dragging")
        // viewController!.time = 0.0
        viewController!.intensity.target = 0.0
        viewController!.intensity.steps = 25
    }

    func windowDidDrag(_ window: TrackingWindow, frame: NSRect) {
        // print("\(viewController?.frame ?? 0) Dragging: \(frame)")

        /*
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.S" // S = tenths of a second
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(viewController?.frame ?? 0) Dragging: \(frame)")

        // scheduleDebouncedUpdate(frame: frame)
        */
    }

    func windowWasDoubleClicked(_ window: TrackingWindow) {
        print("Double clicked:")
        freeze()
    }

    /*
    func windowDidResize(_ notification: Notification) {
        // print("resize")
        if let win = window as? GlassWindow {
            // win.liveFrame = NSRect(origin: window!.frame.origin, size: window!.frame.size)
        }
    }
    */

    func scheduleDebouncedUpdate(frame: NSRect? = nil) {

        if (recorder.responsive) {

            recorder.capture(receiver: self, view: self.window!.contentView!, frame: frame)
            if let textureRect = recorder.textureRect {
                viewController?.updateTextureRect(textureRect)
            }
            return
        }
        // Cancel existing timer
        debounceTimer?.invalidate()

        // Schedule new timer
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task {
                await self!.recorder.capture(receiver: self!, view: self!.window!.contentView!, frame: nil)
                await self!.viewController?.updateTextureRect(self!.recorder.textureRect!)
            }
        }
    }
}

extension MyWindowController: SCStreamOutput {

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {

        // print("🎥 Frame received at: \(Date())")

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Pass pixel buffer to view controller
        DispatchQueue.main.async { [weak self] in
            if let vc = self?.contentViewController as? MyViewController {
                vc.update(with: pixelBuffer)
            }
        }
    }
}
