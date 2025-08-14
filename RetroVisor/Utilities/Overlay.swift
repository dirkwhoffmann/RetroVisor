// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import AppKit

final class Overlay {

    private weak var window: NSWindow?
    private var overlayContainer: NSView?
    private var clickHandler: (() -> Void)?

    init(window: NSWindow, iconName: String, clickHandler: (() -> Void)? = nil) {
        self.window = window
        self.clickHandler = clickHandler
        showOverlay(iconName: iconName)
    }

    deinit {
        removeOverlay()
    }

    private func showOverlay(iconName: String) {
        guard let contentView = window?.contentView else { return }
        guard let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) else { return }

        // Full-size transparent background container
        let container = NSView(frame: contentView.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor

        // Pause icon
        let imageView = ClickableImageView()
        imageView.image = image
        imageView.contentTintColor = .white.withAlphaComponent(0.6)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clickHandler = { [weak self] in
            self?.clickHandler?()
        }

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        // Resize icon dynamically when window resizes
        imageView.sizeUpdateHandler = { [weak imageView, weak container] in
            guard let container = container else { return }
            let minSide = min(container.bounds.width, container.bounds.height)
            imageView?.symbolConfiguration = .init(pointSize: minSide / 2, weight: .regular)
        }
        imageView.sizeUpdateHandler?() // trigger initial size

        contentView.addSubview(container, positioned: .above, relativeTo: nil)
        overlayContainer = container
    }

    func removeOverlay() {
        overlayContainer?.removeFromSuperview()
        overlayContainer = nil
    }
}

private final class ClickableImageView: NSImageView {

    var clickHandler: (() -> Void)?
    var sizeUpdateHandler: (() -> Void)?

    override func layout() {
        super.layout()
        sizeUpdateHandler?()
    }

    override func mouseDown(with event: NSEvent) {
        clickHandler?()
    }
}
