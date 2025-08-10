import Cocoa

class GeneralPreferencesViewController: NSViewController {

    @IBOutlet weak var fullCaptureButton: NSButton!
    @IBOutlet weak var areaCaptureButton: NSButton!

    override func viewDidLoad() {

        print("GeneralPreferencesViewController.viewDidLoad")
        refresh()
    }

    var appDelegate: AppDelegate { NSApp.delegate as! AppDelegate }
    var recorder: ScreenRecorder? { appDelegate.recorder }

    func refresh() {

        fullCaptureButton.state = recorder?.responsive == true ? .on : .off
        areaCaptureButton.state = recorder?.responsive == false ? .on : .off
    }

    @IBAction func fullCaptureButton(_ sender: NSButton) {

        recorder?.responsive = sender.state == .on
        refresh()
    }

    @IBAction func areaCaptureButton(_ sender: NSButton) {

        recorder?.responsive = sender.state == .off
        refresh()
    }
}

class ShaderPreferencesViewController: NSViewController {
    /*
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
    */
}

class RecorderPreferencesViewController: NSViewController {
    /*
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
    */
}
