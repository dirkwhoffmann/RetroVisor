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

    func windowDidStartDrag(_ window: NSWindow)
    func windowDidStopDrag(_ window: NSWindow)
}

class TrackingWindow: NSWindow {

    private var isDragging = false
    private var dragMonitor: Any?

    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)

        guard event.type == .leftMouseDragged || event.type == .leftMouseUp else { return }

        if event.type == .leftMouseDragged {

            if !isDragging {
                isDragging = true
                (delegate as? TrackingWindowDelegate)?.windowDidStartDrag(self)
            }
        } else if event.type == .leftMouseUp {

            if isDragging {
                isDragging = false
                (delegate as? TrackingWindowDelegate)?.windowDidStopDrag(self)
            }
        }
    }
}
