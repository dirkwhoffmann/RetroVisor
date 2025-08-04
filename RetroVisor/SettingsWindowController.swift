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
    var value: Float
    let range: ClosedRange<Double>
    let step: Float
    let help: String?
}

let shaderSettings: [ShaderSetting] = [

    ShaderSetting(
        name: "Brightness Boost",
        key: "BRIGHT_BOOST",
        value: 1.2,
        range: 0.0...2.0,
        step: 0.01,
        help: nil
    ),

    ShaderSetting(
        name: "Horizontal Sharpness",
        key: "SHARPNESS_H",
        value: 0.5,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Vertical Sharpness",
        key: "SHARPNESS_V",
        value: 1.0,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Dilation",
        key: "DILATION",
        value: 1.0,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Gamma Input",
        key: "GAMMA_INPUT",
        value: 2.0,
        range: 0.1...5.0,
        step: 0.1,
        help: nil
    ),

    ShaderSetting(
        name: "Gamma Output",
        key: "GAMMA_OUTPUT",
        value: 1.8,
        range: 0.1...5.0,
        step: 0.1,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Strength",
        key: "MASK_STRENGTH",
        value: 0.3,
        range: 0.0...1.0,
        step: 0.01,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Width",
        key: "MASK_DOT_WIDTH",
        value: 1.0,
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Height",
        key: "MASK_DOT_HEIGHT",
        value: 1.0,
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Stagger",
        key: "MASK_STAGGER",
        value: 0.0,
        range: 0.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Dot Mask Size",
        key: "MASK_SIZE",
        value: 1.0,
        range: 1.0...100.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Strength",
        key: "SCANLINE_STRENGTH",
        value: 1.0,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Minimum Beam Width",
        key: "SCANLINE_BEAM_WIDTH_MIN",
        value: 1.5,
        range: 0.5...5.0,
        step: 0.5,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Maximum Beam Width",
        key: "SCANLINE_BEAM_WIDTH_MAX",
        value: 1.5,
        range: 0.5...5.0,
        step: 0.5,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Minimum Brightness",
        key: "SCANLINE_BRIGHT_MIN",
        value: 0.35,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Maximum Brightness",
        key: "SCANLINE_BRIGHT_MAX",
        value: 0.35,
        range: 0.0...1.0,
        step: 0.05,
        help: nil
    ),

    ShaderSetting(
        name: "Scanline Cutoff",
        key: "SCANLINE_CUTOFF",
        value: 400.0,
        range: 1.0...1000.0,
        step: 1.0,
        help: nil
    ),

    ShaderSetting(
        name: "Lanczos Filter",
        key: "ENABLE_LANCZOS",
        value: 1.0,
        range: 0.0...1.0,
        step: 1.0,
        help: nil
    ),
]

class SettingsWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return shaderSettings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "settingsCell"), owner: self) as? ShaderSettingCell else { return nil }

        let item = shaderSettings[row]
        cell.optionLabel.stringValue = item.name
        cell.subLabel.stringValue = item.key
        cell.helpButtom.isHidden = item.help == nil
        cell.valueSlider.minValue = item.range.lowerBound
        cell.valueSlider.maxValue = item.range.upperBound
        cell.valueSlider.floatValue = Float(item.value)
        cell.valueLabel.stringValue = String(format: "%.2f", item.value)

        return cell
    }

}
