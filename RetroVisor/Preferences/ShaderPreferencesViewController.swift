// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class MyOutlineView : NSOutlineView {

    var groups: [ShaderSettingGroup] {

        var result: [ShaderSettingGroup] = []
        if let ds = self.dataSource {
            let count = ds.outlineView?(self, numberOfChildrenOfItem: parent) ?? 0
            for i in 0..<count {
                if let child = ds.outlineView?(self, child: i, ofItem: parent) {
                    if let group = child as? ShaderSettingGroup {
                        result.append(group)
                    }
                }
            }
        }
        return result
    }

    /*
    func rowView(for group: ShaderSettingGroup) -> NSTableRowView? {

        let r = row(forItem: group)
        let rv = rowView(atRow: row(forItem: group), makeIfNecessary: false)
        return rv
    }

    func cellView(for group: ShaderSettingGroup) -> ShaderGroupCell? {

        let rowView = rowView(for: group)!
        for column in 0..<numberOfColumns {
            if let cellView = rowView.view(atColumn: column) as? ShaderGroupCell {
                return cellView
            }
        }
        return nil // rowView(for: group)?.view(atColumn: 0) as? ShaderGroupCell
    }
    */

    override func frameOfOutlineCell(atRow row: Int) -> NSRect {

        return .zero
    }
}

class ShaderPreferencesViewController: NSViewController {

    @IBOutlet weak var outlineView: MyOutlineView!
    @IBOutlet weak var shaderSelector: NSPopUpButton!

    var shader: Shader { return ShaderLibrary.shared.currentShader }

    override func viewDidLoad() {

        // oldSettings = app.crtUniforms

        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.indentationPerLevel = 0
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.gridColor = .controlAccentColor.withAlphaComponent(0.25) // .controlBackgroundColor // windowBackgroundColor
        outlineView.gridStyleMask = [.solidHorizontalGridLineMask]

        // Add all available shaders to the shader selector popup
        shaderSelector.removeAllItems()

        for shader in ShaderLibrary.shared.shaders {

            let item = NSMenuItem(title: shader.name,
                                  action: nil,
                                  keyEquivalent: "")
            item.tag = shader.id ?? 0
            shaderSelector.menu?.addItem(item)
        }

        shaderSelector.selectItem(withTag: shader.id ?? 0)
        outlineView.reloadData()

        for group in outlineView.groups {
            
            if group.key == nil || shader.get(key: group.key!) != 0 {
                outlineView.expandItem(group)
            } else {
                outlineView.collapseItem(group)
            }
        }
    }

    func refresh() {

        shaderSelector.selectItem(withTag: shader.id ?? 0)
        outlineView.reloadData()
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
            // return group.children.count
            return group.children.filter { !shader.isHidden(key: $0.key) }.count
        } else {
            return shader.settings.count
        }
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {

        return item is ShaderSettingGroup ? 42 : 56
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {

        return item is ShaderSettingGroup
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {

        if let group = item as? ShaderSettingGroup {
            // return group.children[index]
            return group.children.filter { !shader.isHidden(key: $0.key) }[index]
        } else {
            return shader.settings[index]
        }
    }
}

extension ShaderPreferencesViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

        if let group = item as? ShaderSettingGroup {

            let id = NSUserInterfaceItemIdentifier("GroupCell")
            let cell = outlineView.makeView(withIdentifier: id, owner: self) as! ShaderGroupView
            cell.setup(with: group)
            cell.updateIcon(expanded: outlineView.isItemExpanded(item))
            group.view = cell
            return cell

        } else if let row = item as? ShaderSetting {

            let id = NSUserInterfaceItemIdentifier(rawValue: "RowCell")
            let cell = outlineView.makeView(withIdentifier: id, owner: self) as! ShaderSettingView
            cell.shaderSetting = row
            return cell

        } else {

            return nil
        }
    }

    func outlineViewItemDidExpand(_ notification: Notification) {

        guard let item = notification.userInfo?["NSObject"] else { return }
        if let cell = item as? ShaderSettingGroup {
            cell.view?.updateIcon(expanded: true)
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {

        guard let item = notification.userInfo?["NSObject"] else { return }
        if let cell = item as? ShaderSettingGroup {
            cell.view?.updateIcon(expanded: false)
        }
    }
}
