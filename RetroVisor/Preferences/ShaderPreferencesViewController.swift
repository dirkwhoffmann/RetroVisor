// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

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

    var shader: Shader { return ShaderLibrary.shared.currentShader }

    override func viewDidLoad() {

        // oldSettings = app.crtUniforms

        tableView.delegate = self
        tableView.dataSource = self

        refresh()
    }

    func refresh() {

        shaderSelector.selectItem(withTag: shader.id ?? 0) // Int(app.crtUniforms.ENABLE))
        tableView.reloadData()
    }

    // DEPRECATED
    func get(key: String) -> Float {

        return shader.get(key: key)
    }

    // DEPRECATED
    func set(key: String, value: Float) {

        shader.set(key: key, value: value)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {

        return shader.settings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "settingsCell"), owner: self) as? ShaderSettingCell else { return nil }

        cell.shaderSetting = shaderSettings[row]
        cell.value = get(key: shaderSettings[row].key)
        return cell
    }

    @IBAction func shaderSelectAction(_ sender: NSPopUpButton) {

        print("shaderSelectAction \(sender.selectedTag())")

        ShaderLibrary.shared.selectShader(at: sender.selectedTag())

        // app.crtUniforms.ENABLE = Int32(sender.selectedTag())
        refresh()
    }

    @IBAction func defaultsAction(_ sender: NSButton) {

        // app.crtUniforms.self = CrtUniforms.defaults
        refresh()
    }

    @IBAction func cancelAction(_ sender: NSButton) {

        // app.crtUniforms.self = oldSettings
        view.window?.close()
    }

    @IBAction func okAction(_ sender: NSButton) {

        view.window?.close()
    }
}
