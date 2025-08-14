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

    // private let recordingOn = NSImage(named: "recordingOn")!
    // private let recordingOff = NSImage(named: "recordingOff")!

    private var pauseOverlay: Overlay?

    var onAir: Bool = false {

        didSet {
            if (onAir != oldValue) {

                print("onAir = \(onAir)")

                let icons = [
                    AuxBarItem(
                        image: NSImage(named: "Recording")!,
                        height: 20
                    ) {
                        print("Rec clicked")
                    }
                ]

                removeAccessory(ofType: AuxBarViewController.self)
                let auxBar = AuxBarViewController(icons: onAir ? icons : [])
                addTitlebarAccessoryViewController(auxBar)
            }
        }
    }

    func updateRecordingIcon(recording: Bool) {

        onAir = recording
        // showOverlay(image: recording ? recordingOn : nil)
    }

    /*
    func showOverlay(image: NSImage?, height: CGFloat = 18, margin: CGFloat = 5) {

        if overlayView?.image === image { return }
        guard let container = contentView else { return }

        // Remove old overlay
        overlayView?.removeFromSuperview()
        overlayView = nil

        // Add new overlay
        if image != nil {

            let imageView = NSImageView(image: image!)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(imageView, positioned: .above, relativeTo: nil)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: margin),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -margin),
                imageView.heightAnchor.constraint(equalToConstant: height),
                imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: image!.size.width / image!.size.height)
            ])

            overlayView = imageView
        }
    }
    */

    func showPauseOverlay(image: NSImage, clickHandler: (() -> Void)? = nil) {

        pauseOverlay = Overlay(window: self, image: image) {
            clickHandler?()
        }
    }
}
