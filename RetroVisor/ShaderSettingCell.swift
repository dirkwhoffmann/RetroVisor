//
//  ShaderSettingCell.swift
//  RetroVisor
//
//  Created by Dirk Hoffmann on 04.08.25.
//

import Cocoa




class ShaderSettingCell: NSTableCellView {

    @IBOutlet weak var userNameLabel: NSTextField!
    @IBOutlet weak var roleLabel: NSTextField!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }

    @IBAction func helpButton(_ sender: Any) {

        print("Need help")
    }

}
