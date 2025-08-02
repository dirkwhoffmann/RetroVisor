// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import AppKit

/* TrackingWindow is a subclass of NSWindow that enhances the standard window
 * behavior by providing a more responsive delegation interface and improved
 * tracking capabilities. Key Features:
 *
 * 1. High-Frequency Movement Tracking
 *
 *    Unlike the default NSWindowDelegate method windowDidMove, which is called
 *    infrequently, `TrackingWindow` leverages mouse dragging events to track
 *    the window's position in near real-time. This is particularly useful when
 *    precise or continuous position updates are required.
 *
 * 2. Extended Delegate Protocol
 *
 *    TrackingWindow supports an extended delegate interface with additional
 *    callbacks such as windowDidStartDrag, windowDidDrag, and windowDidStopDrag,
 *    enabling fine-grained control and updates during window interaction.
 *
 * 3. Coordinate Conversion Utilities
 *
 *    The class provides helper methods for converting points between screen
 *    coordinates, window coordinates, and content view coordinates. These methods
 *    are useful for tasks such as mapping mouse positions or aligning UI elements.
 */

protocol TrackingWindowDelegate: NSWindowDelegate {

    func windowDidStartDrag(_ window: TrackingWindow)
    func windowDidStopDrag(_ window: TrackingWindow)
    func windowDidStartResize(_ window: TrackingWindow)
    func windowDidStopResize(_ window: TrackingWindow)
    func windowDidDrag(_ window: TrackingWindow, frame: NSRect)
    func windowWasDoubleClicked(_ window: TrackingWindow)
}

class TrackingWindow: NSWindow {

    // Enables window dragging by clicking anywhere inside the window
    var dragAnywhere: Bool = true

    // Enables debug output to the console
    var debug: Bool = true

    // The live-tracked window position (updated more frequently than `frame`)
    private(set) var liveFrame: NSRect = .zero

    // Indicates if a drag operation is ongoing
    private(set) var isDragging: Bool = false

    // Indicates if a resize operation is ongoing
    private(set) var isResizing: Bool = false

    // Mouse position at the beginning of a drag or resize event
    private(set) var initialMouseLocationAbs : NSPoint?
    private(set) var initialMouseLocationRel : NSPoint?
    private(set) var initialMouseLocationNrm : NSPoint?

    private var lastMouseLocation: NSPoint?
    private var lastMouseLocationRel: NSPoint?
    private var initialWindowOrigin: NSPoint?
    private var prevOrigin: NSPoint?
    private var resizeDebounceTimer: Timer?

    private var trackingDelegate : TrackingWindowDelegate? { delegate as? TrackingWindowDelegate }

    private func recordInitialMouseLocation() {

        // Get mouse location in screen coordinates
        initialMouseLocationAbs = NSEvent.mouseLocation

        // Convert to window coordinates with the origin at the bottom-left
        initialMouseLocationRel = self.convertPoint(fromScreen: initialMouseLocationAbs!)

        // Normalize the coordinate
        initialMouseLocationNrm = NSPoint(x: initialMouseLocationRel!.x / frame.width,
                                          y: initialMouseLocationRel!.y / frame.height)

    }

    override func sendEvent(_ event: NSEvent) {

        super.sendEvent(event)

        switch event.type {

        case .leftMouseDown:

            if event.clickCount == 2 {

                if debug { print("windowWasDoubleClicked(\(self))") }
                trackingDelegate?.windowWasDoubleClicked(self)

            } else {

                lastMouseLocation = NSEvent.mouseLocation
                lastMouseLocationRel = event.locationInWindow
                initialWindowOrigin = self.frame.origin
                recordInitialMouseLocation()

                if (dragAnywhere) {
                    self.performDrag(with: event)
                }
            }

        case .leftMouseDragged:

            if !isDragging {
                isDragging = true

                if debug { print("windowDidStartDrag(\(self))") }
                trackingDelegate?.windowDidStartDrag(self)
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
                    if debug { print("windowDidDrag(\(self), frame: \(liveFrame))") }
                    trackingDelegate?.windowDidDrag(self, frame: liveFrame)
                }
            }

        case .leftMouseUp:

            if isDragging {
                isDragging = false
                if debug { print("windowDidStopDrag(\(self))") }
                trackingDelegate?.windowDidStopDrag(self)
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
            if debug { print("windowDidStartResize(\(self))") }
            trackingDelegate?.windowDidStartResize(self)
        }

        // Reset timer to detect resize end
        resizeDebounceTimer?.invalidate()
        resizeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.isResizing = false
            if debug { print("windowDidStopResize(\(self))") }
            trackingDelegate?.windowDidStopResize(self)
        }

        if (isResizing) {

            recordInitialMouseLocation()
            liveFrame = frame
        }
    }
}

extension NSWindow {


}
