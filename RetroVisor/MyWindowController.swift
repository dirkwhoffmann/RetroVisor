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
            window.styleMask = [.nonactivatingPanel, .fullSizeContentView]
            window.backgroundColor = NSColor.gray.withAlphaComponent(0.2)
            window.contentView?.layer?.borderColor = NSColor.systemGray.cgColor
            window.contentView?.layer?.borderWidth = 1
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

extension MyWindowController: NSWindowDelegate {

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {

        // print("windowWillResize \(frameSize)")
        let rect = recorder.viewRectInScreenPixels(view: window!.contentView!)!
        // print("x: \(rect.minX) y: \(rect.minY) x2: \(rect.maxX) y2: \(rect.maxY)")
        viewController?.updateTextureRect(rect)
        // isResizing = true
        return frameSize
    }

    func windowDidMove(_ notification: Notification) {
        scheduleDebouncedUpdate()
    }

    func windowDidResize(_ notification: Notification) {
        scheduleDebouncedUpdate()
    }

    private func scheduleDebouncedUpdate() {

        // Cancel existing timer
        debounceTimer?.invalidate()

        // Schedule new timer
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task {
                await self!.recorder.restart(receiver: self!)
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
