// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

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

class ShaderPreferencesViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var shaderSelector: NSPopUpButton!

    var app: AppDelegate { NSApp.delegate as! AppDelegate }
    var oldSettings: CrtUniforms!

    override func viewDidLoad() {

        oldSettings = app.crtUniforms

        tableView.delegate = self
        tableView.dataSource = self

        refresh()
    }

    func refresh() {

        shaderSelector.selectItem(withTag: Int(app.crtUniforms.ENABLE))
        tableView.reloadData()
    }

    func get(key: String) -> Float {

        switch key {
        case "ENABLE": return Float(app.crtUniforms.ENABLE)
        case "BRIGHT_BOOST": return app.crtUniforms.BRIGHT_BOOST
        case "DILATION": return app.crtUniforms.DILATION
        case "GAMMA_INPUT": return app.crtUniforms.GAMMA_INPUT
        case "GAMMA_OUTPUT": return app.crtUniforms.GAMMA_OUTPUT
        case "MASK_SIZE": return app.crtUniforms.MASK_SIZE
        case "MASK_STAGGER": return app.crtUniforms.MASK_STAGGER
        case "MASK_STRENGTH": return app.crtUniforms.MASK_STRENGTH
        case "MASK_DOT_WIDTH": return app.crtUniforms.MASK_DOT_WIDTH
        case "MASK_DOT_HEIGHT": return app.crtUniforms.MASK_DOT_HEIGHT
        case "SCANLINE_BEAM_WIDTH_MAX": return app.crtUniforms.SCANLINE_BEAM_WIDTH_MAX
        case "SCANLINE_BEAM_WIDTH_MIN": return app.crtUniforms.SCANLINE_BEAM_WIDTH_MIN
        case "SCANLINE_BRIGHT_MAX": return app.crtUniforms.SCANLINE_BRIGHT_MAX
        case "SCANLINE_BRIGHT_MIN": return app.crtUniforms.SCANLINE_BRIGHT_MIN
        case "SCANLINE_CUTOFF": return app.crtUniforms.SCANLINE_CUTOFF
        case "SCANLINE_STRENGTH": return app.crtUniforms.SCANLINE_STRENGTH
        case "SHARPNESS_H": return app.crtUniforms.SHARPNESS_H
        case "SHARPNESS_V": return app.crtUniforms.SHARPNESS_V
        case "ENABLE_LANCZOS": return Float(app.crtUniforms.ENABLE_LANCZOS)

        default:
            NSSound.beep()
            return 0
        }
    }

    func set(key: String, value: Float) {

        switch key {
        case "ENABLE": app.crtUniforms.ENABLE = Int32(value)
        case "BRIGHT_BOOST": app.crtUniforms.BRIGHT_BOOST = value
        case "DILATION": app.crtUniforms.DILATION = value
        case "GAMMA_INPUT": app.crtUniforms.GAMMA_INPUT = value
        case "GAMMA_OUTPUT": app.crtUniforms.GAMMA_OUTPUT = value
        case "MASK_SIZE": app.crtUniforms.MASK_SIZE = value
        case "MASK_STAGGER": app.crtUniforms.MASK_STAGGER = value
        case "MASK_STRENGTH": app.crtUniforms.MASK_STRENGTH = value
        case "MASK_DOT_WIDTH": app.crtUniforms.MASK_DOT_WIDTH = value
        case "MASK_DOT_HEIGHT": app.crtUniforms.MASK_DOT_HEIGHT = value
        case "SCANLINE_BEAM_WIDTH_MAX": app.crtUniforms.SCANLINE_BEAM_WIDTH_MAX = value
        case "SCANLINE_BEAM_WIDTH_MIN": app.crtUniforms.SCANLINE_BEAM_WIDTH_MIN = value
        case "SCANLINE_BRIGHT_MAX": app.crtUniforms.SCANLINE_BRIGHT_MAX = value
        case "SCANLINE_BRIGHT_MIN": app.crtUniforms.SCANLINE_BRIGHT_MIN = value
        case "SCANLINE_CUTOFF": app.crtUniforms.SCANLINE_CUTOFF = value
        case "SCANLINE_STRENGTH": app.crtUniforms.SCANLINE_STRENGTH = value
        case "SHARPNESS_H": app.crtUniforms.SHARPNESS_H = value
        case "SHARPNESS_V": app.crtUniforms.SHARPNESS_V = value
        case "ENABLE_LANCZOS": app.crtUniforms.ENABLE_LANCZOS = Int32(value)

        default:
            NSSound.beep()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {

        return app.crtUniforms.ENABLE == 0 ? 0 : shaderSettings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "settingsCell"), owner: self) as? ShaderSettingCell else { return nil }

        cell.shaderSetting = shaderSettings[row]
        cell.value = get(key: shaderSettings[row].key)
        return cell
    }

    @IBAction func shaderSelectAction(_ sender: NSPopUpButton) {

        app.crtUniforms.ENABLE = Int32(sender.selectedTag())
        refresh()
    }

    @IBAction func defaultsAction(_ sender: NSButton) {

        app.crtUniforms.self = CrtUniforms.defaults
        refresh()
    }

    @IBAction func cancelAction(_ sender: NSButton) {

        app.crtUniforms.self = oldSettings
        view.window?.close()
    }

    @IBAction func okAction(_ sender: NSButton) {

        view.window?.close()
    }
}
