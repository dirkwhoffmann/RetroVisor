//
//  ShaderSettingCell.swift
//  RetroVisor
//
//  Created by Dirk Hoffmann on 04.08.25.
//

import Cocoa




class ShaderSettingCell: NSTableCellView {

    @IBOutlet weak var controller: SettingsWindowController!
    @IBOutlet weak var optionImage: NSImageView!
    @IBOutlet weak var optionLabel: NSTextField!
    @IBOutlet weak var subLabel: NSTextField!
    @IBOutlet weak var valueSlider: NSSlider!
    @IBOutlet weak var valueLabel: NSTextField!
    @IBOutlet weak var helpButtom: NSButton!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }

    @IBAction func sliderAction(_ sender: NSSlider) {

        controller.set(key: subLabel.stringValue, value: sender.floatValue)
        valueLabel.stringValue = String(format: "%.2f", sender.floatValue)
    }

    @IBAction func helpButton(_ sender: Any) {

        print("Need help")
    }

}
