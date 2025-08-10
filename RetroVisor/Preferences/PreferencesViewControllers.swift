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

class ShaderPreferencesViewController: NSViewController {
    override func loadView() {
        self.view = NSView()
        let label = NSTextField(labelWithString: "Shader Preferences")
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

class RecorderPreferencesViewController: NSViewController {
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
