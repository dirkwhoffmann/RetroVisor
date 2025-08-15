// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa
import MetalKit
import MetalPerformanceShaders

class ViewController: NSViewController {

    @IBOutlet weak var metalView: MetalView!

    var trackingWindow: TrackingWindow? { view.window as? TrackingWindow }
}
