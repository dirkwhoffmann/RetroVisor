// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import AppKit

class EffectWindow: TrackingWindow {

    // When the stream terminates, a large pause icon is drawn
    private var pauseOverlay: Overlay?

    // Set to true to display a REC icon in the upper right corner
    var onAir: Bool = false {

        didSet {
            if onAir != oldValue {

                // print("onAir = \(onAir)")

                let icons = [
                    BarIcon(
                        image: NSImage(named: "Recording")!,
                        height: 20
                    ) {
                        print("Rec clicked")
                    }
                ]

                removeAccessory(ofType: IconBarViewController.self)
                let iconBar = IconBarViewController(icons: onAir ? icons : [])
                addTitlebarAccessoryViewController(iconBar)
            }
        }
    }

    func showPauseOverlay(image: NSImage, clickHandler: (() -> Void)? = nil) {

        pauseOverlay = Overlay(window: self, image: image) {
            clickHandler?()
        }
    }
}
