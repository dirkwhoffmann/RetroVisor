// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class ShaderSettingCell: NSTableCellView {

    @IBOutlet weak var controller: ShaderPreferencesViewController!
    @IBOutlet weak var optionImage: NSImageView!
    @IBOutlet weak var optionLabel: NSTextField!
    @IBOutlet weak var subLabel: NSTextField!
    @IBOutlet weak var optCeckbox: NSButton!
    @IBOutlet weak var valueSlider: NSSlider!
    @IBOutlet weak var valueStepper: NSStepper!
    @IBOutlet weak var valuePopup: NSPopUpButton!
    @IBOutlet weak var valueLabel: NSTextField!
    @IBOutlet weak var helpButtom: NSButton!

    var shaderSetting: ShaderSetting! {

        didSet {

            optionLabel.stringValue = shaderSetting.name
            subLabel.stringValue = shaderSetting.key
            helpButtom.isHidden = shaderSetting.help == nil
            optCeckbox.isHidden = !shaderSetting.optional

            valuePopup.isHidden = true
            valueSlider.isHidden = true
            valueStepper.isHidden = true
            valueSlider.isHidden = true
            valueLabel.isHidden = true

            if let range = shaderSetting.range {

                valueStepper.isHidden = false
                valueSlider.isHidden = false
                valueLabel.isHidden = false
                valueSlider.isHidden = false
                valueSlider.minValue = range.lowerBound
                valueSlider.maxValue = range.upperBound
                valueStepper.increment = Double(shaderSetting.step)
                valueStepper.minValue = Double(range.lowerBound)
                valueStepper.maxValue = Double(range.upperBound)
            }

            if let values = shaderSetting.values {

                valuePopup.isHidden = false
                valuePopup.removeAllItems()
                for value in values {
                    let item = NSMenuItem(title: value.0,
                                          action: nil,
                                          keyEquivalent: "")
                    item.tag = value.1
                    valuePopup.menu?.addItem(item)
                }
                valuePopup.selectItem(at: 0) // TODO: SELECT PROPER VALUE
            }
        }
    }

    var isEnabled: Bool = true {

        didSet {

            optCeckbox.state = isEnabled ? .on : .off
        }
    }

    var value: Float! { didSet { update() } }
/*
            if shaderSetting.range != nil {

                valueSlider.floatValue = value
                valueStepper.floatValue = value
                valueLabel.stringValue = String(format: shaderSetting.formatString, value)
            }

            if shaderSetting.values != nil {

                valuePopup.selectItem(withTag: Int(value))
            }
        }
    }
 */

    func update() {

        let value = controller.get(key: shaderSetting.key)

        if !optCeckbox.isHidden {

            let enabled = controller.get(key: shaderSetting.enableKey!) != 0
            optCeckbox.state = enabled ? .on : .off;
        }

        if !valueSlider.isHidden {

            valueSlider.floatValue = value
            valueStepper.floatValue = value
            valueLabel.stringValue = String(format: shaderSetting.formatString, value)
        }

        if !valuePopup.isHidden {

            valuePopup.selectItem(withTag: Int(value))
        }

    }

    @IBAction func optAction(_ sender: NSButton) {

        controller.shader.set(key: subLabel.stringValue, enable: sender.state == .on)
        isEnabled = controller.shader.isEnabled(key: subLabel.stringValue)
    }

    @IBAction func sliderAction(_ sender: NSControl) {

        let rounded = round(sender.floatValue / shaderSetting.step) * shaderSetting.step

        controller.shader.set(key: subLabel.stringValue, value: rounded)
        value = controller.get(key: subLabel.stringValue)
    }

    @IBAction func stepperAction(_ sender: NSControl) {

        sliderAction(sender)
    }

    @IBAction func popupAction(_ sender: NSPopUpButton) {

        controller.shader.set(key: shaderSetting.key, value: Float(sender.selectedTag()))
        update();
    }

    @IBAction func enableAction(_ sender: NSButton) {

        if let enableKey = shaderSetting.enableKey {

            controller.shader.set(key: enableKey, enable: sender.state == .on)
            update();
        }
    }

    @IBAction func helpButton(_ sender: NSButton) {

        print("Not implemented yet")
    }
}
