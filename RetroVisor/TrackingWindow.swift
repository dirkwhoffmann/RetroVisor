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

protocol TrackingWindowDelegate {

    func windowDidStartDrag(_ window: TrackingWindow)
    func windowDidDrag(_ window: TrackingWindow, frame: NSRect)
    func windowDidStopDrag(_ window: TrackingWindow)
    func windowDidStartResize(_ window: TrackingWindow)
    func windowDidResize(_ window: TrackingWindow, frame: NSRect)
    func windowDidStopResize(_ window: TrackingWindow)
    func windowWasDoubleClicked(_ window: TrackingWindow)
}

extension TrackingWindowDelegate {

    func windowDidStartDrag(_ window: TrackingWindow) {}
    func windowDidDrag(_ window: TrackingWindow, frame: NSRect) {}
    func windowDidStopDrag(_ window: TrackingWindow) {}
    func windowDidStartResize(_ window: TrackingWindow) {}
    func windowDidResize(_ window: TrackingWindow, frame: NSRect) {}
    func windowDidStopResize(_ window: TrackingWindow) {}
    func windowWasDoubleClicked(_ window: TrackingWindow) {}
}

class TrackingWindow: NSWindow, NSWindowDelegate {

    // The window delegate
    var trackingDelegate: TrackingWindowDelegate?

    // Enables window dragging by clicking anywhere inside the window
    var dragAnywhere: Bool = true

    // Enables debug output to the console
    var debug: Bool = false

    // The live-tracked window position (updated more frequently than `frame`)
    private var trackedFrame: NSRect = .zero

    var liveFrame: NSRect {

        var result = trackedFrame
        if let screen = self.screen {
            result.origin.y = min(result.origin.y, screen.visibleFrame.maxY - result.height)
        }
        return result
    }

    // Indicates if a drag operation is ongoing
    private(set) var isDragging: Bool = false

    // Indicates if a resize operation is ongoing
    private(set) var isResizing: Bool = false

    // Window position at the beginning of a drag or resize event
    private(set) var initialWindowOrigin: NSPoint?

    // Mouse position at the beginning of a drag or resize event
    private(set) var initialMouseLocationAbs : NSPoint?
    private(set) var initialMouseLocationRel : NSPoint?
    private(set) var initialMouseLocationNrm : NSPoint?

    // Timer to determine the end of a resize operation
    private var resizeDebounceTimer: Timer?


    //
    // Functions
    //

    override func awakeFromNib() {

        super.awakeFromNib()
        delegate = self
    }

    private func recordLocations() {

        // Get the window origin
        initialWindowOrigin = frame.origin

        // Get mouse location in screen coordinates
        initialMouseLocationAbs = NSEvent.mouseLocation

        // Convert to window coordinates with the origin at the bottom-left
        initialMouseLocationRel = self.convertPoint(fromScreen: initialMouseLocationAbs!)

        // Normalize the coordinate
        initialMouseLocationNrm = NSPoint(x: initialMouseLocationRel!.x / frame.width,
                                          y: initialMouseLocationRel!.y / frame.height)

    }

    func windowDidResize(_ notification: Notification) {

        trackedFrame = frame
        if debug { print("windowDidResize(\(self))") }
        trackingDelegate?.windowDidResize(self, frame: trackedFrame)
    }

    override func sendEvent(_ event: NSEvent) {

        super.sendEvent(event)

        switch event.type {

        case .leftMouseDown:

            if event.clickCount == 2 {

                if debug { print("windowWasDoubleClicked(\(self))") }
                trackingDelegate?.windowWasDoubleClicked(self)

            } else {

                // Record the window's origin and the mouse coordinate
                recordLocations()

                // Perform a drag operation in 'dragAnywhere' mode
                if (dragAnywhere) { self.performDrag(with: event) }
            }

        case .leftMouseDragged:

            if !isDragging {

                isDragging = true
                if debug { print("windowDidStartDrag(\(self))") }
                trackingDelegate?.windowDidStartDrag(self)
            }

            if let initialLocation = initialMouseLocationAbs,
               let initialOrigin = initialWindowOrigin {

                // Determine the new origin
                let location = NSEvent.mouseLocation
                var newOrigin = NSPoint(x: initialOrigin.x + location.x - initialLocation.x,
                                        y: initialOrigin.y + location.y - initialLocation.y)

                // Snap to pixel grid (optional)
                newOrigin.x = floor(newOrigin.x) // round?
                newOrigin.y = floor(newOrigin.y) // round?

                if newOrigin != trackedFrame.origin {

                    trackedFrame = NSRect(origin: newOrigin, size: self.frame.size)
                    if debug { print("windowDidDrag(\(self), frame: \(liveFrame))") }
                    trackingDelegate?.windowDidDrag(self, frame: liveFrame)
                }
            }

        case .leftMouseUp:

            if isDragging {

                isDragging = false
                // clearLocations()
                if debug { print("windowDidStopDrag(\(self))") }
                trackingDelegate?.windowDidStopDrag(self)
            }

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

            if let self = self {

                self.isResizing = false
                if debug { print("windowDidStopResize(\(self))") }
                trackingDelegate?.windowDidStopResize(self)
            }
        }

        if (isResizing) {

            recordLocations()
            trackedFrame = frame
        }
    }
}
