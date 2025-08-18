// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class ShaderPreferencesViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var shaderSelector: NSPopUpButton!

    var shader: Shader { return ShaderLibrary.shared.currentShader }

    override func viewDidLoad() {

        // oldSettings = app.crtUniforms

        tableView.delegate = self
        tableView.dataSource = self

        // Add all available shaders to the shader selector popup
        shaderSelector.removeAllItems()

        for shader in ShaderLibrary.shared.shaders {

            let item = NSMenuItem(title: shader.name,
                                  action: nil,
                                  keyEquivalent: "")
            item.tag = shader.id ?? 0
            // item.isEnabled = true
            shaderSelector.menu?.addItem(item)
        }
        shaderSelector.selectItem(at: 0)

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

        cell.shaderSetting = shader.settings[row]
        cell.value = get(key: shader.settings[row].key)
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
