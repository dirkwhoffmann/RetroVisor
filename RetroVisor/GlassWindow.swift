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

    }
}
