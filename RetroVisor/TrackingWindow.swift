// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import AppKit

protocol TrackingWindowDelegate: NSWindowDelegate {

    func windowDidStartDrag(_ window: TrackingWindow)
    func windowDidStopDrag(_ window: TrackingWindow)
    func windowDidDrag(_ window: TrackingWindow, frame: NSRect)
    func windowWasDoubleClicked(_ window: TrackingWindow)
}

class TrackingWindow: NSWindow {

    private var isDragging = false
    private var lastMouseLocation: NSPoint?
    private var initialWindowOrigin: NSPoint?

    override func sendEvent(_ event: NSEvent) {

        super.sendEvent(event)

        switch event.type {

        case .leftMouseDown:

            if event.clickCount == 2 {
                (delegate as? TrackingWindowDelegate)?.windowWasDoubleClicked(self)
            } else {
                lastMouseLocation = event.locationInWindow
                initialWindowOrigin = self.frame.origin
            }

        case .leftMouseDragged:

            if !isDragging {
                isDragging = true
                (delegate as? TrackingWindowDelegate)?.windowDidStartDrag(self)
            }

            if let lastLocation = lastMouseLocation,
               let startOrigin = initialWindowOrigin {

                let currentLocation = event.locationInWindow
                let delta = NSPoint(x: currentLocation.x - lastLocation.x,
                                    y: currentLocation.y - lastLocation.y)

                // Update window position (in screen coordinates)
                var newOrigin = startOrigin
                newOrigin.x += delta.x
                newOrigin.y += delta.y

                // Snap to pixel grid (optional, avoids subpixel fuzziness)
                newOrigin.x = round(newOrigin.x)
                newOrigin.y = round(newOrigin.y)
                // self.setFrameOrigin(newOrigin)

                // Compute new frame
                let newFrame = NSRect(origin: newOrigin, size: self.frame.size)

                (delegate as? TrackingWindowDelegate)?.windowDidDrag(self, frame: newFrame)
            }

        case .leftMouseUp:
            
            if isDragging {
                isDragging = false
                (delegate as? TrackingWindowDelegate)?.windowDidStopDrag(self)
            }

            lastMouseLocation = nil
            initialWindowOrigin = nil

        default:
            break;
        }
    }
}
