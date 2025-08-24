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
            shaderSelector.menu?.addItem(item)
        }
        shaderSelector.selectItem(at: 0)

        refresh()
    }

    func refresh() {

        shaderSelector.selectItem(withTag: shader.id ?? 0) // Int(app.crtUniforms.ENABLE))
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {

        return shader.settings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "settingsCell"), owner: self) as? ShaderSettingCell else { return nil }

        cell.shaderSetting = shader.settings[0].children[row]
        cell.value = shader.get(key: shader.settings[0].children[row].key)
        return cell
    }

    @IBAction func shaderSelectAction(_ sender: NSPopUpButton) {

        print("shaderSelectAction \(sender.selectedTag())")

        ShaderLibrary.shared.selectShader(at: sender.selectedTag())
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

extension ShaderPreferencesViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {

        if let group = item as? ShaderSettingGroup {
            return group.children.count
        } else {
            return shader.settings.count
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {

        return item is ShaderSettingGroup
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {

        if let group = item as? ShaderSettingGroup {
            return group.children[index]
        } else {
            return shader.settings[index]
        }
    }
}

extension ShaderPreferencesViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

        if let group = item as? ShaderSettingGroup {

            let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GroupCell"), owner: self) as! NSTableCellView
            cell.textField?.stringValue = group.title
            return cell

        } else if let row = item as? ShaderSetting {

            let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RowCell"), owner: self) as! NSTableCellView
            cell.textField?.stringValue = row.name
            return cell
        }
        return nil
    }
}
