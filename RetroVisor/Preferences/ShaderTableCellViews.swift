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

    @IBOutlet weak var controller: ShaderPreferencesViewController!

    var shader: Shader { controller.shader }
    var outlineView: MyOutlineView { controller.outlineView }
    
    func updateIcon(expanded: Bool) {
        
    }
}

class ShaderGroupView: ShaderTableCellView {

    @IBOutlet weak var disclosureButton: NSButton!
    @IBOutlet weak var enableButton: NSButton!
    @IBOutlet weak var fakeButton: NSButton!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var subLabel: NSTextField!

    var group: Group!

    func setup(with group: Group) {

        func reposition(_ label: NSTextField, over button: NSButton) {

            var frame = label.frame
            frame.origin.x = button.frame.origin.x
            label.frame = frame
        }
        
        self.group = group
        label.stringValue = shader.delegate?.title(setting: group) ?? group.title

        let count = group.children.count
        let optString = "\(count) option" + (count > 1 ? "s" : "")

        if let enabled = group.enabled {
            
            reposition(label, over: fakeButton)
            reposition(subLabel, over: fakeButton)
            
            enableButton.isHidden = false
            enableButton.state = enabled ? .on : .off
            subLabel.stringValue = "\(group.enableKey)"
        
        } else {

            reposition(label, over: enableButton)
            reposition(subLabel, over: enableButton)

            enableButton.isHidden = true
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

    @IBAction func disclosureAction(_ sender: NSButton) {

        if sender.state == .on {
            outlineView.expandItem(group)
        } else {
            outlineView.collapseItem(group)
        }

        outlineView.reloadData()
    }
    
    @IBAction func enableAction(_ sender: NSButton) {

        group.enabled = sender.state == .on
        
        /*
        if sender.state == .on {
            outlineView.expandItem(group)
        } else {
            outlineView.collapseItem(group)
        }
        */
        
        shader.delegate?.settingDidChange(setting: group)
        outlineView.reloadData()
    }
}

class ShaderSettingView: ShaderTableCellView {

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

            // let enableKey = shaderSetting.enableKey
            let enabled = shaderSetting.enabled ?? true
            let hidden = shader.delegate?.isHidden(setting: shaderSetting) ?? false
            let customTitle = shader.delegate?.title(setting: shaderSetting)
            
            optionLabel.stringValue = customTitle ?? shaderSetting.title
            subLabel.stringValue = shaderSetting.valueKey
            helpButtom.isHidden = shaderSetting.help == nil
            optCeckbox.isHidden = shaderSetting.enabled == nil

            optionLabel.textColor = hidden ? .disabledControlTextColor : .textColor
            subLabel.textColor = hidden ? .disabledControlTextColor : .textColor
            helpButtom.isEnabled = !hidden
            optCeckbox.isEnabled = !hidden

            valuePopup.isHidden = true
            valueSlider.isHidden = true
            valueStepper.isHidden = true
            valueLabel.isHidden = true

            valuePopup.isEnabled = enabled && !hidden
            valueSlider.isEnabled = enabled && !hidden
            valueStepper.isEnabled = enabled && !hidden
            valueLabel.textColor = enabled && !hidden ? .textColor : .disabledControlTextColor

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
                    
                    let item = value.0.isEmpty ?
                    NSMenuItem.separator() :
                    NSMenuItem(title: value.0, action: nil, keyEquivalent: "")
                    
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
        shader.delegate?.settingDidChange(setting: shaderSetting)
    }

    @IBAction func stepperAction(_ sender: NSControl) {

        sliderAction(sender)
    }

    @IBAction func popupAction(_ sender: NSPopUpButton) {

        shaderSetting.intValue = sender.selectedTag()
        shader.delegate?.settingDidChange(setting: shaderSetting)
        outlineView.reloadData()
    }

    @IBAction func enableAction(_ sender: NSButton) {

        shaderSetting.enabled = sender.state == .on
        shader.delegate?.settingDidChange(setting: shaderSetting)
        outlineView.reloadData()
    }

    @IBAction func helpAction(_ sender: NSButton) {

        print("Not implemented yet")
    }
}
