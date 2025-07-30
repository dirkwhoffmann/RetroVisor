// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import AVFoundation

class GlassWindow: NSWindow {

    func windowDidLoad() {
        print("Hallo. windowDidLoad")
    }
}

class GlassView: NSView {

    let videoLayer = AVSampleBufferDisplayLayer()

    override func makeBackingLayer() -> CALayer {
        return videoLayer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        videoLayer.videoGravity = .resizeAspectFill
    }

    func displaySampleBuffer(_ buffer: CMSampleBuffer) {
        if videoLayer.isReadyForMoreMediaData {
            videoLayer.enqueue(buffer)
        }
    }
}
