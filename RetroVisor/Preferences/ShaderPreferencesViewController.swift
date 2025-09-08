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

    var groups: [Group] {

        var result: [Group] = []
        if let ds = self.dataSource {
            let count = ds.outlineView?(self, numberOfChildrenOfItem: parent) ?? 0
            for i in 0..<count {
                if let child = ds.outlineView?(self, child: i, ofItem: parent) {
                    if let group = child as? Group {
                        result.append(group)
                    }
                }
            }
        }
        return result
    }

    override func frameOfOutlineCell(atRow row: Int) -> NSRect {

        return .zero
    }
}

class ShaderPreferencesViewController: NSViewController {

    @IBOutlet weak var outlineView: MyOutlineView!
    @IBOutlet weak var shaderSelector: NSPopUpButton!
    @IBOutlet weak var presetSelector: NSPopUpButton!

    var shader: Shader { return ShaderLibrary.shared.currentShader }

    var oldSettings: [String: [String: String]]!
    
    override func viewDidLoad() {

        oldSettings = ShaderLibrary.shared.currentShader.dictionary
        
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.indentationPerLevel = 0
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.gridColor = .separatorColor // .controlBackgroundColor // windowBackgroundColor
        outlineView.gridStyleMask = [.solidHorizontalGridLineMask]

        updateShaderPopup()
        updatePresetPopup()
        
        outlineView.reloadData()

        expandAll()
        /*
        for group in outlineView.groups {
            
            if group.enabled ?? true {
                // print("Expand \(group.title)")
                outlineView.expandItem(group)
            } else {
                // print("Shrink \(group.title)")
                outlineView.collapseItem(group)
            }
        }
        */
    }

    func expandAll() {
     
        for group in outlineView.groups {
            outlineView.expandItem(group)
        }
    }
    
    func expandEnabled() {
        
        for group in outlineView.groups {
            if group.enabled ?? true {
                outlineView.expandItem(group)
            } else {
                outlineView.collapseItem(group)
            }
        }
    }
    
    func updateShaderPopup() {
        
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
    }
    
    func updatePresetPopup() {
     
        presetSelector.removeAllItems()
        
        // let item = NSMenuItem(title: "Revert to...", action: nil, keyEquivalent: "")
        presetSelector.menu?.addItem(withTitle: "Revert to...", action: nil, keyEquivalent: "")
        presetSelector.menu?.addItem(NSMenuItem.separator())

        for (index, title) in shader.presets.enumerated() {

            let item = NSMenuItem(title: title,
                                  action: nil,
                                  keyEquivalent: "")
            item.tag = index
            presetSelector.menu?.addItem(item)
        }
    }
    
    func refresh() {

        shaderSelector.selectItem(withTag: shader.id ?? 0)
        outlineView.reloadData()
    }

    @IBAction func shaderSelectAction(_ sender: NSPopUpButton) {

        print("shaderSelectAction \(sender.selectedTag())")

        ShaderLibrary.shared.selectShader(at: sender.selectedTag())
        updatePresetPopup()
        refresh()
        expandAll()
    }

    @IBAction func presetAction(_ sender: NSPopUpButton) {

        print("\(sender.selectedTag())")
        ShaderLibrary.shared.currentShader.revertToPreset(nr: sender.selectedTag())
        refresh()
    }

    @IBAction func infoAction(_ sender: Any!) {
        
    }
    
    @IBAction func cancelAction(_ sender: NSButton) {

        ShaderLibrary.shared.currentShader.dictionary = oldSettings
        print("\(ShaderLibrary.shared.currentShader.dictionary)")

        view.window?.close()
    }

    @IBAction func okAction(_ sender: NSButton) {

        view.window?.close()
    }
}

extension ShaderPreferencesViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {

        if let group = item as? Group {
            return group.children.count
            // return group.children.filter { $0.hidden == false }.count
        } else {
            return shader.settings.count
        }
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {

        return item is Group ? 56 : 56
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {

        return item is Group
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {

        if let group = item as? Group {
            return group.children[index]
            // return group.children.filter { $0.hidden == false }[index]
        } else {
            return shader.settings[index]
        }
    }
}

extension ShaderPreferencesViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

        if let group = item as? Group {

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
        if let cell = item as? Group {
            cell.view?.updateIcon(expanded: true)
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {

        guard let item = notification.userInfo?["NSObject"] else { return }
        if let cell = item as? Group {
            cell.view?.updateIcon(expanded: false)
        }
    }
}
