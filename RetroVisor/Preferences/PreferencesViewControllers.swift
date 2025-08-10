import Cocoa

class GeneralPreferencesViewController: NSViewController {
    override func loadView() {
        self.view = NSView()
        let label = NSTextField(labelWithString: "General Preferences")
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

class VideoPreferencesViewController: NSViewController {
    override func loadView() {
        self.view = NSView()
        let label = NSTextField(labelWithString: "Video Preferences")
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

class AudioPreferencesViewController: NSViewController {
    override func loadView() {
        self.view = NSView()
        let label = NSTextField(labelWithString: "Audio Preferences")
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
