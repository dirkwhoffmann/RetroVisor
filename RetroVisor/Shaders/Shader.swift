// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit
import MetalPerformanceShaders

@MainActor
protocol ShaderDelegate {
    
    func title(setting: ShaderSetting) -> String
    func isHidden(setting: ShaderSetting) -> Bool
    func settingDidChange(setting: ShaderSetting)
}

extension ShaderDelegate {
    
    func title(setting: ShaderSetting) -> String { setting.title }
    func isHidden(setting: ShaderSetting) -> Bool { false }
    func settingDidChange(setting: ShaderSetting) { }
}

@MainActor
class Shader : Loggable {

    static var device: MTLDevice { MTLCreateSystemDefaultDevice()! }

    // Enables debug output to the console
    let logging: Bool = true

    // Name of this shader
    var name: String = ""
    
    // Shader settings
    var settings: [Group] = []

    // Delegate
    var delegate: ShaderDelegate?
    
    init(name: String) {

        self.name = name
    }
    
    // Called once when the user selects this shader
    func activate() { log("Activating \(name)") }

    // Called once when the user selects another shader
    func retire() { log("Retiring \(name)") }
    
    // Runs the shader
    func apply(commandBuffer: MTLCommandBuffer,
               in input: MTLTexture, out output: MTLTexture, rect: CGRect = .unity) {
        
        fatalError("To be implemented by a subclass")
    }
}

//
// Loading and saving options
//

extension Shader {
    
    // Searches a setting by name
    func findSetting(key: String) -> ShaderSetting? {
        
        for group in settings { if let match = group.findSetting(key: key) { return match } }
        return nil
    }
    
    var dictionary: [String: [String: String]] {
        
        get {
            var result: [String: [String: String]] = [:]
            
            for group in settings {
                result[group.title] = group.dictionary
            }
            return result
        }
        set {
            
            for (_, keyValues) in newValue {
                
                for (key, value) in keyValues {
                                    
                    guard let setting = findSetting(key: key) else {
                        
                        log("Setting \(key) not found", .warning)
                        continue
                    }
                    guard let value = Float(value) else {
                        
                        log("Failed to parse string \(value)", .warning)
                        continue
                    }
                    if setting.enableKey == key { setting.enabled = value != 0 }
                    if setting.valueKey == key { setting.floatValue = value }
                }
            }
        }
    }
    
    func saveSettings(url: URL) throws {
                
        try Parser.save(url: url, dict: dictionary)
    }
}

//
// Wrappers around MPSImageScale
//

@MainActor
class ScaleShader<F: MPSImageScale> : Shader {

    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        let filter = F(device: output.device)
        var transform = MPSScaleTransform.init(in: input, out: output, rect: rect)

        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in

            filter.scaleTransform = transformPtr
            filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
        }
    }
}

@MainActor
class BilinearShader: ScaleShader<MPSImageBilinearScale> {

    init() { super.init(name: "Bilinear") }
}

@MainActor
class LanczosShader: ScaleShader<MPSImageLanczosScale> {

    init() { super.init(name: "Lanczos") }
}
