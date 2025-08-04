//
//  SettingsWindowController.swift
//  RetroVisor
//
//  Created by Dirk Hoffmann on 04.08.25.
//

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

class SettingsWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var tableView: NSTableView!

    var appDelegate: AppDelegate { NSApp.delegate as! AppDelegate }
    var oldSettings: CrtUniforms!

    /*
    override func windowDidLoad() {

        super.windowDidLoad()
    }
    */

    override func showWindow(_ sender: Any?) {

        super.showWindow(sender)
        oldSettings = appDelegate.uniforms
        tableView.reloadData()
    }

    func get(key: String) -> Float {

        switch key {
        case "BRIGHT_BOOST": return appDelegate.uniforms.BRIGHT_BOOST
        case "DILATION": return appDelegate.uniforms.DILATION
        case "GAMMA_INPUT": return appDelegate.uniforms.GAMMA_INPUT
        case "GAMMA_OUTPUT": return appDelegate.uniforms.GAMMA_OUTPUT
        case "MASK_SIZE": return appDelegate.uniforms.MASK_SIZE
        case "MASK_STAGGER": return appDelegate.uniforms.MASK_STAGGER
        case "MASK_STRENGTH": return appDelegate.uniforms.MASK_STRENGTH
        case "MASK_DOT_WIDTH": return appDelegate.uniforms.MASK_DOT_WIDTH
        case "MASK_DOT_HEIGHT": return appDelegate.uniforms.MASK_DOT_HEIGHT
        case "SCANLINE_BEAM_WIDTH_MAX": return appDelegate.uniforms.SCANLINE_BEAM_WIDTH_MAX
        case "SCANLINE_BEAM_WIDTH_MIN": return appDelegate.uniforms.SCANLINE_BEAM_WIDTH_MIN
        case "SCANLINE_BRIGHT_MAX": return appDelegate.uniforms.SCANLINE_BRIGHT_MAX
        case "SCANLINE_BRIGHT_MIN": return appDelegate.uniforms.SCANLINE_BRIGHT_MIN
        case "SCANLINE_CUTOFF": return appDelegate.uniforms.SCANLINE_CUTOFF
        case "SCANLINE_STRENGTH": return appDelegate.uniforms.SCANLINE_STRENGTH
        case "SHARPNESS_H": return appDelegate.uniforms.SHARPNESS_H
        case "SHARPNESS_V": return appDelegate.uniforms.SHARPNESS_V
        case "ENABLE_LANCZOS": return Float(appDelegate.uniforms.ENABLE_LANCZOS)

        default:
            NSSound.beep()
            return 0
        }
    }

    func set(key: String, value: Float) {

        // print("key: \(key) value: \(value)")

        switch key {
        case "BRIGHT_BOOST": appDelegate.uniforms.BRIGHT_BOOST = value
        case "DILATION": appDelegate.uniforms.DILATION = value
        case "GAMMA_INPUT": appDelegate.uniforms.GAMMA_INPUT = value
        case "GAMMA_OUTPUT": appDelegate.uniforms.GAMMA_OUTPUT = value
        case "MASK_SIZE": appDelegate.uniforms.MASK_SIZE = value
        case "MASK_STAGGER": appDelegate.uniforms.MASK_STAGGER = value
        case "MASK_STRENGTH": appDelegate.uniforms.MASK_STRENGTH = value
        case "MASK_DOT_WIDTH": appDelegate.uniforms.MASK_DOT_WIDTH = value
        case "MASK_DOT_HEIGHT": appDelegate.uniforms.MASK_DOT_HEIGHT = value
        case "SCANLINE_BEAM_WIDTH_MAX": appDelegate.uniforms.SCANLINE_BEAM_WIDTH_MAX = value
        case "SCANLINE_BEAM_WIDTH_MIN": appDelegate.uniforms.SCANLINE_BEAM_WIDTH_MIN = value
        case "SCANLINE_BRIGHT_MAX": appDelegate.uniforms.SCANLINE_BRIGHT_MAX = value
        case "SCANLINE_BRIGHT_MIN": appDelegate.uniforms.SCANLINE_BRIGHT_MIN = value
        case "SCANLINE_CUTOFF": appDelegate.uniforms.SCANLINE_CUTOFF = value
        case "SCANLINE_STRENGTH": appDelegate.uniforms.SCANLINE_STRENGTH = value
        case "SHARPNESS_H": appDelegate.uniforms.SHARPNESS_H = value
        case "SHARPNESS_V": appDelegate.uniforms.SHARPNESS_V = value
        case "ENABLE_LANCZOS": appDelegate.uniforms.ENABLE_LANCZOS = Int32(value)

        default:
            NSSound.beep()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return shaderSettings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "settingsCell"), owner: self) as? ShaderSettingCell else { return nil }

        cell.shaderSetting = shaderSettings[row]
        cell.value = get(key: shaderSettings[row].key)
        return cell
    }

    @IBAction func defaultsAction(_ sender: NSButton) {

        appDelegate.uniforms.self = CrtUniforms.defaults
        tableView.reloadData()
    }

    @IBAction func cancelAction(_ sender: NSButton) {

        appDelegate.uniforms.self = oldSettings
        window?.close()
    }

    @IBAction func okAction(_ sender: NSButton) {

        window?.close()
    }

}
