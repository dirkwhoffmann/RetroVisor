import Cocoa


struct AuxBarItem {

    let image: NSImage          // The icon to display
    let height: CGFloat         // Button height
    let padding: CGFloat = 0.0  // Padding inside button
    let action: () -> Void      // Click handler

    var size: CGSize {
        CGSize(width: (image.size.width / image.size.height) * height, height: height)
    }
}

class AuxBarViewController: NSTitlebarAccessoryViewController {

    let debug = false
    var buttonBg: CGColor { debug ? NSColor.yellow.cgColor : NSColor.clear.cgColor }
    var contentBg: CGColor { debug ? NSColor.red.cgColor : NSColor.clear.cgColor }

    var items: [AuxBarItem] = []

    init(icons: [AuxBarItem], spacing: CGFloat = 6) {

        super.init(nibName: nil, bundle: nil)

        self.items = icons

        // Compute the content view's required width
        let totalWidth = icons.reduce(0) { $0 + $1.size.width } + CGFloat(icons.count) * spacing
        let maxHeight = icons.map { $0.size.height }.max() ?? 28

        // Create the content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: totalWidth, height: maxHeight))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = contentBg
        self.view = contentView

        var prev: NSButton? = nil

        for (index, icon) in icons.enumerated() {

            // Create a button
            let button = NSButton()
            button.tag = index
            button.imagePosition = .imageOnly
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.backgroundColor = buttonBg
            button.layer?.cornerRadius = 4
            button.action = #selector(buttonClicked(_:))
            button.target = self

            // Create an image view inside the button
            let imageView = NSImageView(image: icon.image)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown
            button.addSubview(imageView)

            let padding = 0.0 // icon.padding
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: button.topAnchor, constant: padding),
                imageView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -padding),
                imageView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: padding),
                imageView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -padding)
            ])

            button.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(button)

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: icon.size.width),
                button.heightAnchor.constraint(equalToConstant: icon.size.height),
                button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])

            if let prev = prev {
                button.leadingAnchor.constraint(equalTo: prev.trailingAnchor,
                                                constant: spacing).isActive = true
            } else {
                button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,
                                                constant: 0).isActive = true
            }

            prev = button
        }

        layoutAttribute = .trailing
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Button Action

    @objc private func buttonClicked(_ sender: NSButton) {

        if sender.tag >= 0 && sender.tag < items.count {
            items[sender.tag].action()
        } else {
            print("No icon found for tag \(sender.tag)")
        }
    }
}
