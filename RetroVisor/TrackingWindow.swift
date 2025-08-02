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
    func windowDidStartResize(_ window: TrackingWindow)
    func windowDidStopResize(_ window: TrackingWindow)
    func windowDidDrag(_ window: TrackingWindow, frame: NSRect)
    func windowWasDoubleClicked(_ window: TrackingWindow)
}

class TrackingWindow: NSWindow {

    var liveFrame = NSRect.zero
    var dragAnywhere = true

    private var isDragging = false
    private var isResizing = false
    private var lastMouseLocation: NSPoint?
    private var lastMouseLocationRel: NSPoint?
    private var initialWindowOrigin: NSPoint?
    private var prevOrigin: NSPoint?
    private var resizeDebounceTimer: Timer?

    var normalizedMouseLocation: NSPoint? {
        return normalizedPoint(inWindow: lastMouseLocationRel ?? .zero)
    }

    override func sendEvent(_ event: NSEvent) {

        super.sendEvent(event)

        switch event.type {

        case .leftMouseDown:

            if event.clickCount == 2 {

                (delegate as? TrackingWindowDelegate)?.windowWasDoubleClicked(self)

            } else {

                lastMouseLocation = NSEvent.mouseLocation
                lastMouseLocationRel = event.locationInWindow
                initialWindowOrigin = self.frame.origin
                if (dragAnywhere) {
                    self.performDrag(with: event)
                }
            }

        case .leftMouseDragged:

            if !isDragging {
                isDragging = true
                (delegate as? TrackingWindowDelegate)?.windowDidStartDrag(self)
            }

            if let lastLocation = lastMouseLocation,
               let startOrigin = initialWindowOrigin {

                let currentLocation = NSEvent.mouseLocation // event.locationInWindow
                let delta = NSPoint(x: currentLocation.x - lastLocation.x,
                                    y: currentLocation.y - lastLocation.y)

                // Update window position (in screen coordinates)
                var newOrigin = startOrigin
                newOrigin.x += delta.x
                newOrigin.y += delta.y

                // Snap to pixel grid (optional, avoids subpixel fuzziness)
                /*
                 newOrigin.x = round(newOrigin.x)
                 newOrigin.y = round(newOrigin.y)
                 */
                newOrigin.x = floor(newOrigin.x)
                newOrigin.y = floor(newOrigin.y)

                liveFrame = NSRect(origin: newOrigin, size: self.frame.size)

                if newOrigin != prevOrigin {

                    prevOrigin = newOrigin
                    (delegate as? TrackingWindowDelegate)?.windowDidDrag(self, frame: liveFrame)
                }
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

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {

        super.setFrame(frameRect, display: flag)

        // Called frequently during live resizing
        if !isResizing {
            isResizing = true
            (delegate as? TrackingWindowDelegate)?.windowDidStartResize(self)
        }

        // Reset timer to detect resize end
        resizeDebounceTimer?.invalidate()
        resizeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.isResizing = false
            (delegate as? TrackingWindowDelegate)?.windowDidStopResize(self)
        }
    }
}

extension NSWindow {

    // Converts a point in window coordinates to normalized (0.0–1.0) space
    func normalizedPoint(inWindow point: NSPoint) -> CGPoint {

        if let contentSize = contentView?.bounds.size {
            print("contentSize = \(contentSize) point = \(point)")
            if contentSize.width > 0, contentSize.height > 0 {
                return CGPoint(x: max(0.0, min(1.0, point.x / contentSize.width)),
                               y: max(0.0, min(1.0, point.y / contentSize.height)))
            }
        }
        return .zero
    }
}
