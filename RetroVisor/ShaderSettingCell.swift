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
    @IBOutlet weak var checkbox: NSButton!
    @IBOutlet weak var valueLabel: NSTextField!
    @IBOutlet weak var helpButtom: NSButton!

    var step: Float = 0.1

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }

    @IBAction func sliderAction(_ sender: NSSlider) {

        let value = round(sender.floatValue / step) * step

        controller.set(key: subLabel.stringValue, value: value)
        let readBack = controller.get(key: subLabel.stringValue)
        valueLabel.stringValue = String(format: "%.2f", readBack)
    }

    @IBAction func enableAction(_ sender: NSButton) {

        controller.set(key: subLabel.stringValue, value: sender.state == .on ? 1.0 : 0.0)
        valueLabel.stringValue = sender.state == .on ? "On" : "Off"
    }

    @IBAction func helpButton(_ sender: NSButton) {

        print("Need help")
    }

}
