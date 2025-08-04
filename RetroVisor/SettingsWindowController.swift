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
    // var value: Float
    let range: ClosedRange<Double>
    let step: Float
    let help: String?
}

var shaderSettings: [ShaderSetting] = [

    ShaderSetting(
        name: "Brightness Boost",
        key: "BRIGHT_BOOST",
        // value: 1.2,
        range: 0.0...2.0,
        step: 0.01,
        help: nil
    ),

    ShaderSetting(
        name: "Horizontal Sharpness",
        key: "SHARPNESS_H",
        // value: 0.5,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Vertical Sharpness",
        key: "SHARPNESS_V",
        // value: 1.0,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Dilation",
        key: "DILATION",
        // value: 1.0,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Gamma Input",
        key: "GAMMA_INPUT",
        // value: 2.0,
        range: 0.1...5.0,
        step: 0.1,
        help: nil
    ),

    ShaderSetting(
        name: "Gamma Output",
        key: "GAMMA_OUTPUT",
        // value: 1.8,
        range: 0.1...5.0,
        step: 0.1,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Strength",
        key: "MASK_STRENGTH",
        // value: 0.3,
        range: 0.0...1.0,
        step: 0.01,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Width",
        key: "MASK_DOT_WIDTH",
        // value: 1.0,
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Height",
        key: "MASK_DOT_HEIGHT",
        // value: 1.0,
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Stagger",
        key: "MASK_STAGGER",
        // value: 0.0,
        range: 0.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Size",
        key: "MASK_SIZE",
        // value: 1.0,
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Strength",
        key: "SCANLINE_STRENGTH",
        // value: 1.0,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Minimum Beam Width",
        key: "SCANLINE_BEAM_WIDTH_MIN",
        // value: 1.5,
        range: 0.5...5.0,
        step: 0.5,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Maximum Beam Width",
        key: "SCANLINE_BEAM_WIDTH_MAX",
        // value: 1.5,
        range: 0.5...5.0,
        step: 0.5,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Minimum Brightness",
        key: "SCANLINE_BRIGHT_MIN",
        // value: 0.35,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Maximum Brightness",
        key: "SCANLINE_BRIGHT_MAX",
        // value: 0.35,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Cutoff",
        key: "SCANLINE_CUTOFF",
        // value: 400.0,
        range: 1.0...1000.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Lanczos Filter",
        key: "ENABLE_LANCZOS",
        // value: 1.0,
        range: 0.0...1.0,
        step: 1.0,
        help: nil
    ),
]

class SettingsWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var tableView: NSTableView!

    var appDelegate: AppDelegate { NSApp.delegate as! AppDelegate }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
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

        print("key: \(key) value: \(value)")

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

        /*
        if let index = shaderSettings.firstIndex(where: { $0.key == key }) {
            shaderSettings[index].value = value
        }
        */
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return shaderSettings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "settingsCell"), owner: self) as? ShaderSettingCell else { return nil }

        let item = shaderSettings[row]
        let value = get(key: item.key)
        cell.optionLabel.stringValue = item.name
        cell.subLabel.stringValue = item.key
        cell.helpButtom.isHidden = item.help == nil
        cell.valueSlider.minValue = item.range.lowerBound
        cell.valueSlider.maxValue = item.range.upperBound
        cell.valueSlider.floatValue = value
        cell.valueLabel.stringValue = String(format: "%.2f", value)

        return cell
    }

}
