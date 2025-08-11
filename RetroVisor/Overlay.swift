import Cocoa

class Overlay {

    private weak var containerView: NSView?
    private var overlayView: NSView?

    init(over view: NSView) {
        self.containerView = view
    }

    func showOverlay(image: NSImage, height: CGFloat = 18, margin: CGFloat = 5) {

        guard let container = containerView, overlayView == nil else { return }

        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView, positioned: .above, relativeTo: nil)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: margin),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -margin),
            imageView.heightAnchor.constraint(equalToConstant: height),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: image.size.width / image.size.height)
        ])

        overlayView = imageView
    }

    func hideOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }

    var isVisible: Bool {
        return overlayView != nil
    }
}
