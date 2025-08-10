import Cocoa

struct ShaderSetting {

    let name: String
    let key: String
    let range: ClosedRange<Double>?
    let step: Float
    let help: String?

    var formatString: String {
        return step < 0.1 ? "%.2f" : step < 1.0 ? "%.1f" : "%.0f"
    }
}

var shaderSettings: [ShaderSetting] = [

    ShaderSetting(
        name: "Brightness Boost",
        key: "BRIGHT_BOOST",
        range: 0.0...2.0,
        step: 0.01,
        help: nil
    ),

    ShaderSetting(
        name: "Horizontal Sharpness",
        key: "SHARPNESS_H",
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Vertical Sharpness",
        key: "SHARPNESS_V",
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Dilation",
        key: "DILATION",
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Gamma Input",
        key: "GAMMA_INPUT",
        range: 0.1...5.0,
        step: 0.1,
        help: nil
    ),

    ShaderSetting(
        name: "Gamma Output",
        key: "GAMMA_OUTPUT",
        range: 0.1...5.0,
        step: 0.1,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Strength",
        key: "MASK_STRENGTH",
        range: 0.0...1.0,
        step: 0.01,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Width",
        key: "MASK_DOT_WIDTH",
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Height",
        key: "MASK_DOT_HEIGHT",
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Stagger",
        key: "MASK_STAGGER",
        range: 0.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Size",
        key: "MASK_SIZE",
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Strength",
        key: "SCANLINE_STRENGTH",
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Minimum Beam Width",
        key: "SCANLINE_BEAM_WIDTH_MIN",
        range: 0.5...5.0,
        step: 0.5,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Maximum Beam Width",
        key: "SCANLINE_BEAM_WIDTH_MAX",
        range: 0.5...5.0,
        step: 0.5,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Minimum Brightness",
        key: "SCANLINE_BRIGHT_MIN",
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Maximum Brightness",
        key: "SCANLINE_BRIGHT_MAX",
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Cutoff",
        key: "SCANLINE_CUTOFF",
        range: 1.0...1000.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Lanczos Filter",
        key: "ENABLE_LANCZOS",
        range: nil,
        step: 1.0,
        help: nil
    ),
]

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

class ShaderPreferencesViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var tableView: NSTableView!

    var appDelegate: AppDelegate { NSApp.delegate as! AppDelegate }
    var oldSettings: CrtUniforms!

    override func viewDidLoad() {

        print("ShaderPreferencesViewController.viewDidLoad")
        oldSettings = appDelegate.crtUniforms
        tableView.delegate = self
        tableView.dataSource = self
        tableView.reloadData()
    }

    func get(key: String) -> Float {

        switch key {
        case "BRIGHT_BOOST": return appDelegate.crtUniforms.BRIGHT_BOOST
        case "DILATION": return appDelegate.crtUniforms.DILATION
        case "GAMMA_INPUT": return appDelegate.crtUniforms.GAMMA_INPUT
        case "GAMMA_OUTPUT": return appDelegate.crtUniforms.GAMMA_OUTPUT
        case "MASK_SIZE": return appDelegate.crtUniforms.MASK_SIZE
        case "MASK_STAGGER": return appDelegate.crtUniforms.MASK_STAGGER
        case "MASK_STRENGTH": return appDelegate.crtUniforms.MASK_STRENGTH
        case "MASK_DOT_WIDTH": return appDelegate.crtUniforms.MASK_DOT_WIDTH
        case "MASK_DOT_HEIGHT": return appDelegate.crtUniforms.MASK_DOT_HEIGHT
        case "SCANLINE_BEAM_WIDTH_MAX": return appDelegate.crtUniforms.SCANLINE_BEAM_WIDTH_MAX
        case "SCANLINE_BEAM_WIDTH_MIN": return appDelegate.crtUniforms.SCANLINE_BEAM_WIDTH_MIN
        case "SCANLINE_BRIGHT_MAX": return appDelegate.crtUniforms.SCANLINE_BRIGHT_MAX
        case "SCANLINE_BRIGHT_MIN": return appDelegate.crtUniforms.SCANLINE_BRIGHT_MIN
        case "SCANLINE_CUTOFF": return appDelegate.crtUniforms.SCANLINE_CUTOFF
        case "SCANLINE_STRENGTH": return appDelegate.crtUniforms.SCANLINE_STRENGTH
        case "SHARPNESS_H": return appDelegate.crtUniforms.SHARPNESS_H
        case "SHARPNESS_V": return appDelegate.crtUniforms.SHARPNESS_V
        case "ENABLE_LANCZOS": return Float(appDelegate.crtUniforms.ENABLE_LANCZOS)

        default:
            NSSound.beep()
            return 0
        }
    }

    func set(key: String, value: Float) {

        switch key {
        case "BRIGHT_BOOST": appDelegate.crtUniforms.BRIGHT_BOOST = value
        case "DILATION": appDelegate.crtUniforms.DILATION = value
        case "GAMMA_INPUT": appDelegate.crtUniforms.GAMMA_INPUT = value
        case "GAMMA_OUTPUT": appDelegate.crtUniforms.GAMMA_OUTPUT = value
        case "MASK_SIZE": appDelegate.crtUniforms.MASK_SIZE = value
        case "MASK_STAGGER": appDelegate.crtUniforms.MASK_STAGGER = value
        case "MASK_STRENGTH": appDelegate.crtUniforms.MASK_STRENGTH = value
        case "MASK_DOT_WIDTH": appDelegate.crtUniforms.MASK_DOT_WIDTH = value
        case "MASK_DOT_HEIGHT": appDelegate.crtUniforms.MASK_DOT_HEIGHT = value
        case "SCANLINE_BEAM_WIDTH_MAX": appDelegate.crtUniforms.SCANLINE_BEAM_WIDTH_MAX = value
        case "SCANLINE_BEAM_WIDTH_MIN": appDelegate.crtUniforms.SCANLINE_BEAM_WIDTH_MIN = value
        case "SCANLINE_BRIGHT_MAX": appDelegate.crtUniforms.SCANLINE_BRIGHT_MAX = value
        case "SCANLINE_BRIGHT_MIN": appDelegate.crtUniforms.SCANLINE_BRIGHT_MIN = value
        case "SCANLINE_CUTOFF": appDelegate.crtUniforms.SCANLINE_CUTOFF = value
        case "SCANLINE_STRENGTH": appDelegate.crtUniforms.SCANLINE_STRENGTH = value
        case "SHARPNESS_H": appDelegate.crtUniforms.SHARPNESS_H = value
        case "SHARPNESS_V": appDelegate.crtUniforms.SHARPNESS_V = value
        case "ENABLE_LANCZOS": appDelegate.crtUniforms.ENABLE_LANCZOS = Int32(value)

        default:
            NSSound.beep()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        print("numberOfRows = \(shaderSettings.count)")
        return shaderSettings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "settingsCell"), owner: self) as? ShaderSettingCell else { return nil }

        cell.shaderSetting = shaderSettings[row]
        cell.value = get(key: shaderSettings[row].key)
        return cell
    }

    @IBAction func defaultsAction(_ sender: NSButton) {

        appDelegate.crtUniforms.self = CrtUniforms.defaults
        tableView.reloadData()
    }

    @IBAction func cancelAction(_ sender: NSButton) {

        appDelegate.crtUniforms.self = oldSettings
        // window?.close()
    }

    @IBAction func okAction(_ sender: NSButton) {

        // window?.close()
    }
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
