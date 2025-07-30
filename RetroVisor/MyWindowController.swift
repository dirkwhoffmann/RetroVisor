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

            unfreeze()

            Task {
                // Setup the recorder
                await recorder.setup(receiver: self)
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

extension MyWindowController: SCStreamOutput {

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {

        print("🎥 Frame received at: \(Date())")
        // myview!.updateImage(from: sampleBuffer, cropRectPixels: rect)
        DispatchQueue.main.async {
            if let view = self.window?.contentView as? GlassView {
                view.displaySampleBuffer(sampleBuffer)
            } else {
                print("View not found")
            }
        }
    }
}
