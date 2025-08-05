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

    var viewController : MyViewController? { return self.contentViewController as? MyViewController }
    var trackingWindow : TrackingWindow? { return window as? TrackingWindow }

    // In live mode, the texture updates when dragging and resizing
    var liveMode: Bool = true

    var debounceTimer: Timer?

    // The screen recorder
    var recorder = ScreenRecorder()

    // Source rectangle of the screen capturer
    var captureRect: CGRect?

    // Displayed texture cutout
    var textureRect: CGRect?

    // Indicates if the window is click-through
    var isFrozen: Bool { return window?.ignoresMouseEvents ?? false }

    /*
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
     */

    override func windowDidLoad() {

        super.windowDidLoad()

        print("windowDidLoad")

        // Example customizations:
        if let window = self.window as? TrackingWindow {

            window.isOpaque = false
            window.hasShadow = true
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.trackingDelegate = self
            unfreeze()

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
            window.contentView?.layer?.borderColor = NSColor.systemGray.cgColor
            window.contentView?.layer?.borderWidth = 0
            window.contentView?.layer?.cornerRadius = 10
        }
    }

    func unfreeze() {

        if let window = self.window {

            window.ignoresMouseEvents = false
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel, .fullSizeContentView]
            window.contentView?.layer?.borderColor = NSColor.systemRed.cgColor
            window.contentView?.layer?.borderWidth = 2
            window.contentView?.layer?.cornerRadius = 10
        }
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
        if !recorder.responsive {
            recorder.capture(receiver: self, view: self.window!.contentView!, frame: window.frame)
        }
    }

    func windowDidStartDrag(_ window: TrackingWindow) {

        viewController!.intensity.target = 1.0
        viewController!.intensity.steps = 25
    }

    func windowDidStopDrag(_ window: TrackingWindow) {

        viewController!.intensity.target = 0.0
        viewController!.intensity.steps = 25

        print("windowDidStopDrag")
        if !recorder.responsive {

            /*
            guard let display = recorder.display else { return }
            let newCaptureRect = display.frame
            let newTextureRect = recorder.viewRectInScreenPixelsNew(view: window.contentView!)!
            print("newCaptureRect = \(newCaptureRect)")
            print("newTextureRect = \(newTextureRect)")
            */

            // let frame = window.frame
            // let theFrame = NSRect(x: frame.minX, y: frame.minY, width: frame.width * 2, height: frame.height * 2)
            // let the = recorder.viewRectInScreenPixels(view: window.contentView!)
            recorder.capture(receiver: self, view: self.window!.contentView!, frame: window.frame)
        }

    }

    func windowWasDoubleClicked(_ window: TrackingWindow) {

        freeze()
    }

    func capture(frame: NSRect? = nil) {

        if (recorder.responsive) {

            recorder.capture(receiver: self, view: self.window!.contentView!, frame: frame)
            if let textureRect = recorder.textureRect {
                viewController?.updateTextureRect(textureRect)
            }

        } else {

            // recorder.capture(receiver: self, view: self.window!.contentView!, frame: frame)
        }
        /*
        // Cancel existing timer
        debounceTimer?.invalidate()

        // Schedule new timer
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task {
                await self!.recorder.capture(receiver: self!, view: self!.window!.contentView!, frame: nil)
                await self!.viewController?.updateTextureRect(self!.recorder.textureRect!)
            }
        }
        */
    }
}

extension MyWindowController: SCStreamOutput {

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Pass pixel buffer to view controller
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
