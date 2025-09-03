// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class ShaderTableCellView: NSTableCellView {
    
    func updateIcon(expanded: Bool) {
        
    }
}

class ShaderGroupView: ShaderTableCellView {

    @IBOutlet weak var controller: ShaderPreferencesViewController!
    @IBOutlet weak var disclosureButton: NSButton!
    @IBOutlet weak var enableButton: NSButton!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var subLabel: NSTextField!

    var group: Group!

    var shader: Shader { controller.shader }
    // var clickable: Bool { group.setting != nil }
    // var expandable: Bool { group.setting == nil }

    func setup(with group: Group) {

        self.group = group
        label.stringValue = group.title

        let count = group.children.count
        let optString = "\(count) option" + (count > 1 ? "s" : "")

        if let setting = group.setting {
            
            enableButton.isHidden = false
            disclosureButton.isHidden = true
            enableButton.state = setting.enabled != false ? .on : .off
            subLabel.stringValue = "\(setting.enableKey)"
            
        } else {

            enableButton.isHidden = true
            disclosureButton.isHidden = false
            subLabel.stringValue = "\(optString)"
        }
    }

    override func updateIcon(expanded: Bool) {

        disclosureButton.state = expanded ? .on : .off
        disclosureButton.image = expanded ? .chevronDown() : .chevronRight()
    }

    override func draw(_ dirtyRect: NSRect) {

        // NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
        NSColor.separatorColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }

    @IBAction func enableAction(_ sender: NSButton) {

        group.setting?.enabled = sender.state == .on

        if sender.state == .on {
            controller.outlineView.expandItem(group)
        } else {
            controller.outlineView.collapseItem(group)
        }
    }
}

class ShaderSettingView: ShaderTableCellView {

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

    var shader: Shader { return ShaderLibrary.shared.currentShader }
    
    var shaderSetting: ShaderSetting! {

        didSet {

            // let enableKey = shaderSetting.enableKey
            let enabled = shaderSetting.enabled ?? true
            let active = !shaderSetting.hidden()

            optionLabel.stringValue = shaderSetting.title
            subLabel.stringValue = shaderSetting.value?.key ?? ""
            helpButtom.isHidden = shaderSetting.help == nil
            optCeckbox.isHidden = shaderSetting.enable == nil

            optionLabel.textColor = active ? .textColor : .disabledControlTextColor
            subLabel.textColor = active ? .textColor : .disabledControlTextColor
            helpButtom.isEnabled = true
            optCeckbox.isEnabled = true

            valuePopup.isHidden = true
            valueSlider.isHidden = true
            valueStepper.isHidden = true
            valueLabel.isHidden = true

            valuePopup.isEnabled = enabled && active
            valueSlider.isEnabled = enabled && active
            valueStepper.isEnabled = enabled && active
            valueLabel.textColor = enabled && active ? .textColor : .disabledControlTextColor

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

            if let values = shaderSetting.items {

                valuePopup.isHidden = false
                valuePopup.removeAllItems()
                for value in values {
                    let item = NSMenuItem(title: value.0,
                                          action: nil,
                                          keyEquivalent: "")
                    item.tag = value.1
                    valuePopup.menu?.addItem(item)
                }
            }

            update()
        }
    }

    var value: Float! { didSet { update() } }

    func update() {

        let value = shaderSetting.floatValue ?? 0 //  shader.get(key: shaderSetting.key)
        let enable = shaderSetting.enabled
        
        if !optCeckbox.isHidden {

            optCeckbox.state = enable == true ? .on : .off;
        }

        if !valueSlider.isHidden {

            valueSlider.floatValue = value
            valueStepper.floatValue = value
            valueLabel.stringValue = value.formatted(min: 1, max: 3)
        }

        if !valuePopup.isHidden {

            valuePopup.selectItem(withTag: Int(value))
        }
    }

    @IBAction func sliderAction(_ sender: NSControl) {

        let rounded = round(sender.floatValue / shaderSetting.step) * shaderSetting.step

        shaderSetting.floatValue = rounded
        value = shaderSetting.floatValue
    }

    @IBAction func stepperAction(_ sender: NSControl) {

        sliderAction(sender)
    }

    @IBAction func popupAction(_ sender: NSPopUpButton) {

        shaderSetting.intValue = sender.selectedTag()
        update();
        controller.outlineView.reloadData()
    }

    @IBAction func enableAction(_ sender: NSButton) {

        shaderSetting.enabled = sender.state == .on
        update();
        controller.outlineView.reloadData()
    }

    @IBAction func helpAction(_ sender: NSButton) {

        print("Not implemented yet")
    }
}
