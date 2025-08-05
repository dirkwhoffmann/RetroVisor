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
    @IBOutlet weak var valueStepper: NSStepper!
    @IBOutlet weak var checkbox: NSButton!
    @IBOutlet weak var valueLabel: NSTextField!
    @IBOutlet weak var helpButtom: NSButton!

    var shaderSetting: ShaderSetting! {
        didSet {
            optionLabel.stringValue = shaderSetting.name
            subLabel.stringValue = shaderSetting.key
            helpButtom.isHidden = shaderSetting.help == nil
            if let range = shaderSetting.range {
                checkbox.isHidden = true
                valueSlider.isHidden = false
                valueSlider.minValue = range.lowerBound
                valueSlider.maxValue = range.upperBound
                valueStepper.increment = Double(shaderSetting.step)
                valueStepper.minValue = Double(range.lowerBound)
                valueStepper.maxValue = Double(range.upperBound)

            } else {
                checkbox.isHidden = false
                valueStepper.isHidden = true
                valueSlider.isHidden = true
            }
        }
    }

    var value: Float! {
        didSet {
            if shaderSetting.range != nil {
                valueSlider.floatValue = value
                valueStepper.floatValue = value
                valueLabel.stringValue = String(format: shaderSetting.formatString, value)
            } else {
                valueLabel.stringValue = value != 0 ? "Yes" : "No"
                checkbox.title = ""
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }

    @IBAction func sliderAction(_ sender: NSControl) {

        let rounded = round(sender.floatValue / shaderSetting.step) * shaderSetting.step

        controller.set(key: subLabel.stringValue, value: rounded)
        value = controller.get(key: subLabel.stringValue)
    }

    @IBAction func stepperAction(_ sender: NSStepper) {

        sliderAction(sender)

        /*
        let tmp = sender.floatValue

        controller.set(key: subLabel.stringValue, value: rounded)
        value = controller.get(key: subLabel.stringValue)
         */
    }

    @IBAction func enableAction(_ sender: NSButton) {

        controller.set(key: subLabel.stringValue, value: sender.state == .on ? 1.0 : 0.0)
        value = controller.get(key: subLabel.stringValue)
    }

    @IBAction func helpButton(_ sender: NSButton) {

        print("Need help")
    }

}
