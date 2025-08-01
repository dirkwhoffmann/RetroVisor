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

class GlassWindow: TrackingWindow {

    var myWindowController: MyWindowController? {
        return windowController as? MyWindowController
    }

    func windowDidLoad() {
        print("Hallo. windowDidLoad")
    }

    /*
    override func mouseDown(with event: NSEvent) {

        super.mouseDown(with: event)
        
        if event.clickCount == 2 {

            // Double click
            myWindowController?.freeze()

        } else {

            // Single click
            self.performDrag(with: event)
        }

        //  if let screen = self.screen {
            let mouseLocation = NSEvent.mouseLocation
            initialMouseLocation = mouseLocation
            initialWindowOrigin = self.frame.origin
        // }
    }
     */

    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero

    /*
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)

        let currentMouseLocation = NSEvent.mouseLocation

        let dx = currentMouseLocation.x - initialMouseLocation.x
        let dy = currentMouseLocation.y - initialMouseLocation.y

        let newOrigin = NSPoint(x: initialWindowOrigin.x + dx,
                                y: initialWindowOrigin.y + dy)

        if newOrigin != self.frame.origin {
            self.setFrameOrigin(newOrigin)
            windowDidMoveContinuously(to: newOrigin)
        }
    }
     */
    
    private func windowDidMoveContinuously(to origin: NSPoint) {
        // print("Live moved to: \(origin)")
        // let roundedOrigin = NSPoint(x: round(origin.x), y: round(origin.y))

        myWindowController?.scheduleDebouncedUpdate(frame: NSRect(origin: origin, size: frame.size))
        // Hier kannst du z. B. SCStream-Konfiguration aktualisieren
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
