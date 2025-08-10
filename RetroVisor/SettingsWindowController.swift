// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Cocoa



class SettingsWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var tableView: NSTableView!

    var appDelegate: AppDelegate { NSApp.delegate as! AppDelegate }
    var oldSettings: CrtUniforms!

    override func showWindow(_ sender: Any?) {

        super.showWindow(sender)
        oldSettings = appDelegate.crtUniforms
        tableView.reloadData()
    }

    func get(key: String) -> Float {

        switch key {
        case "BRIGHT_BOOST": return appDelegate.crtUniforms.BRIGHT_BOOST
        case "DILATION": return appDelegate.crtUniforms.DILATION
        case "GAMMA_INPUT": return appDelegate.crtUniforms.GAMMA_INPUT
        case "GAMMA_OUTPUT": return appDelegate.crtUniforms.GAMMA_OUTPUT
        case "MASK_SIZE": return appDelegate.crtUniforms.MASK_SIZE
        case "MASK_STAGGER": return appDelegate.crtUniforms.MASK_STAGGER
        case "MASK_STRENGTH": return appDelegate.crtUniforms.MASK_STRENGTH
        case "MASK_DOT_WIDTH": return appDelegate.crtUniforms.MASK_DOT_WIDTH
        case "MASK_DOT_HEIGHT": return appDelegate.crtUniforms.MASK_DOT_HEIGHT
        case "SCANLINE_BEAM_WIDTH_MAX": return appDelegate.crtUniforms.SCANLINE_BEAM_WIDTH_MAX
        case "SCANLINE_BEAM_WIDTH_MIN": return appDelegate.crtUniforms.SCANLINE_BEAM_WIDTH_MIN
        case "SCANLINE_BRIGHT_MAX": return appDelegate.crtUniforms.SCANLINE_BRIGHT_MAX
        case "SCANLINE_BRIGHT_MIN": return appDelegate.crtUniforms.SCANLINE_BRIGHT_MIN
        case "SCANLINE_CUTOFF": return appDelegate.crtUniforms.SCANLINE_CUTOFF
        case "SCANLINE_STRENGTH": return appDelegate.crtUniforms.SCANLINE_STRENGTH
        case "SHARPNESS_H": return appDelegate.crtUniforms.SHARPNESS_H
        case "SHARPNESS_V": return appDelegate.crtUniforms.SHARPNESS_V
        case "ENABLE_LANCZOS": return Float(appDelegate.crtUniforms.ENABLE_LANCZOS)

        default:
            NSSound.beep()
            return 0
        }
    }

    func set(key: String, value: Float) {

        switch key {
        case "BRIGHT_BOOST": appDelegate.crtUniforms.BRIGHT_BOOST = value
        case "DILATION": appDelegate.crtUniforms.DILATION = value
        case "GAMMA_INPUT": appDelegate.crtUniforms.GAMMA_INPUT = value
        case "GAMMA_OUTPUT": appDelegate.crtUniforms.GAMMA_OUTPUT = value
        case "MASK_SIZE": appDelegate.crtUniforms.MASK_SIZE = value
        case "MASK_STAGGER": appDelegate.crtUniforms.MASK_STAGGER = value
        case "MASK_STRENGTH": appDelegate.crtUniforms.MASK_STRENGTH = value
        case "MASK_DOT_WIDTH": appDelegate.crtUniforms.MASK_DOT_WIDTH = value
        case "MASK_DOT_HEIGHT": appDelegate.crtUniforms.MASK_DOT_HEIGHT = value
        case "SCANLINE_BEAM_WIDTH_MAX": appDelegate.crtUniforms.SCANLINE_BEAM_WIDTH_MAX = value
        case "SCANLINE_BEAM_WIDTH_MIN": appDelegate.crtUniforms.SCANLINE_BEAM_WIDTH_MIN = value
        case "SCANLINE_BRIGHT_MAX": appDelegate.crtUniforms.SCANLINE_BRIGHT_MAX = value
        case "SCANLINE_BRIGHT_MIN": appDelegate.crtUniforms.SCANLINE_BRIGHT_MIN = value
        case "SCANLINE_CUTOFF": appDelegate.crtUniforms.SCANLINE_CUTOFF = value
        case "SCANLINE_STRENGTH": appDelegate.crtUniforms.SCANLINE_STRENGTH = value
        case "SHARPNESS_H": appDelegate.crtUniforms.SHARPNESS_H = value
        case "SHARPNESS_V": appDelegate.crtUniforms.SHARPNESS_V = value
        case "ENABLE_LANCZOS": appDelegate.crtUniforms.ENABLE_LANCZOS = Int32(value)

        default:
            NSSound.beep()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return shaderSettings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "settingsCell"), owner: self) as? ShaderSettingCell else { return nil }

        cell.shaderSetting = shaderSettings[row]
        cell.value = get(key: shaderSettings[row].key)
        return cell
    }

    @IBAction func defaultsAction(_ sender: NSButton) {

        appDelegate.crtUniforms.self = CrtUniforms.defaults
        tableView.reloadData()
    }

    @IBAction func cancelAction(_ sender: NSButton) {

        appDelegate.crtUniforms.self = oldSettings
        window?.close()
    }

    @IBAction func okAction(_ sender: NSButton) {

        window?.close()
    }
}
