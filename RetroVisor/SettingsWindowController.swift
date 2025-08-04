//
//  SettingsWindowController.swift
//  RetroVisor
//
//  Created by Dirk Hoffmann on 04.08.25.
//

import Cocoa

struct ShaderOption {
    let name: String
    var value: Float
    let range: ClosedRange<Float>
    let description: String
}

class SettingsWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    let users = [["name":"Scott Lougheed", "role":"CEO"], ["name":"Ari Khari", "role":"President"], ["name":"Tandi Lori", "role":"Leader"]]

    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return users.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let userCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "userCell"), owner: self) as? ShaderSettingCell else { return nil }

        userCell.userNameLabel.stringValue = users[row]["name"] ?? "unknown user"
        userCell.roleLabel.stringValue = users[row]["role"] ?? "unknown role"

        return userCell
    }

}
