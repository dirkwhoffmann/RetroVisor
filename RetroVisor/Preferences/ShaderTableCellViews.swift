// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa

class ShaderGroupView: NSTableCellView {

    @IBOutlet weak var controller: ShaderPreferencesViewController!
    @IBOutlet weak var disclosureButton: NSButton!
    @IBOutlet weak var enableButton: NSButton!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var subLabel: NSTextField!

    var group: ShaderSettingGroup!

    var shader: Shader { controller.shader }
    var clickable: Bool { group.key != nil }
    var expandable: Bool { group.key == nil }

    func setup(with group: ShaderSettingGroup) {

        self.group = group
        label.stringValue = group.title

        if clickable {

            enableButton.isHidden = false
            disclosureButton.isHidden = true
            enableButton.state = shader.get(key: group.key!) != 0 ? .on : .off
            subLabel.stringValue = "\(group.key!) (\(group.children.count))"
        }

        if expandable {

            enableButton.isHidden = true
            disclosureButton.isHidden = false
            subLabel.stringValue = " \(group.children.count)"
        }
    }

    func updateIcon(expanded: Bool) {

        disclosureButton.state = expanded ? .on : .off
        disclosureButton.image = expanded ? .chevronDown() : .chevronRight()
    }

    override func draw(_ dirtyRect: NSRect) {

        NSColor.separatorColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }

    @IBAction func enableAction(_ sender: NSButton) {

        if let key = group.key {
            shader.set(key: key, enable: sender.state == .on)
        }
        if sender.state == .on {
            controller.outlineView.expandItem(group)
        } else {
            controller.outlineView.collapseItem(group)
        }
    }
}

class ShaderSettingView: NSTableCellView {

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

            let enableKey = shaderSetting.enableKey
            let enabled = enableKey == nil ? true : shader.get(key: enableKey!) != 0
            let active = !shaderSetting.hidden // !shader.isHidden(key: shaderSetting.key)

            optionLabel.stringValue = shaderSetting.name
            subLabel.stringValue = shaderSetting.key
            helpButtom.isHidden = shaderSetting.help == nil
            optCeckbox.isHidden = shaderSetting.enableKey == nil

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
            }

            update()
        }
    }

    var value: Float! { didSet { update() } }

    func update() {

        let value = shader.get(key: shaderSetting.key)

        if !optCeckbox.isHidden {

            let enabled = shader.get(key: shaderSetting.enableKey!) != 0
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

    @IBAction func sliderAction(_ sender: NSControl) {

        let rounded = round(sender.floatValue / shaderSetting.step) * shaderSetting.step

        shader.set(key: subLabel.stringValue, value: rounded)
        value = shader.get(key: subLabel.stringValue)
    }

    @IBAction func stepperAction(_ sender: NSControl) {

        sliderAction(sender)
    }

    @IBAction func popupAction(_ sender: NSPopUpButton) {

        shader.set(key: shaderSetting.key, value: Float(sender.selectedTag()))
        update();
        controller.outlineView.reloadData()
    }

    @IBAction func enableAction(_ sender: NSButton) {

        if let enableKey = shaderSetting.enableKey {

            shader.set(key: enableKey, enable: sender.state == .on)
            update();
            controller.outlineView.reloadData()
        }
    }

    @IBAction func helpAction(_ sender: NSButton) {

        print("Not implemented yet")
    }
}
