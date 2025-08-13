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

    let recordingOn = NSImage(named: "recordingOn")!
    let recordingOff = NSImage(named: "recordingOff")!

    private var overlayView: NSImageView?

    func updateOverlay(recording: Bool) {

        showOverlay(image: recording ? recordingOn : nil)
    }

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

    func showPauseOverlay(image: NSImage?) {

        guard let contentView = contentView else { return }

        let overlay = PauseOverlayView(frame: contentView.bounds, image: image) {
            app.streamer.relaunch()
        }

        contentView.addSubview(overlay)
    }
}

class PauseOverlayView: NSView {

    var resumeHandler: (() -> Void)?

    init(frame: NSRect, image: NSImage?, resumeHandler: @escaping () -> Void) {

        self.resumeHandler = resumeHandler
        super.init(frame: frame)
        setup(image: image)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /*
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
     */
    private func setup(image: NSImage?) {

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor

        let minSide = min(bounds.width, bounds.height)
        let symbolSize = minSide / 2  // half the window size

        // Create pause symbol using SF Symbols
        let imageView = NSImageView()
        if let pauseImage = image {
            imageView.image = pauseImage
            imageView.symbolConfiguration = .init(pointSize: symbolSize, weight: .regular)
            imageView.contentTintColor = .white.withAlphaComponent(0.6)
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        // Center the pause symbol
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        autoresizingMask = [.width, .height]

        // Make entire overlay clickable
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(clickGesture)
    }

    @objc private func handleClick() {
        removeFromSuperview()
        resumeHandler?()
    }
}

