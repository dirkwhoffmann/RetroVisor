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

class ShaderSetting {

    // Setting name
    let name: String

    // Primary key for the value of this setting
    let key: String
    
    // Secondary key if the setting has an additional enable switch
    let enableKey: String?

    // Parameters for numeric arguments
    let range: ClosedRange<Double>?
    let step: Float

    // Parameters for enum-like arguments
    let values: [(String,Int)]?

    // Optional help string
    let help: String?

    // Indicates if this options should be hidden from the user
    var hidden = false

    private let getEnable: (() -> Bool)?
    private let setEnable: ((Bool) -> Void)?
    private let getter: (() -> Float)?
    private let setter: ((Float) -> Void)?
        
    var formatString: String { "%.3g" }

    init(name: String,
         enableKey: String? = nil,
         getEnable: (() -> Bool)? = nil,
         setEnable: ((Bool) -> Void)? = nil,
         key: String,
         get: (() -> Float)? = nil,
         set: ((Float) -> Void)? = nil,
         range: ClosedRange<Double>? = nil, step: Float = 0.01,
         values: [(String,Int)]? = nil, help: String? = nil
        ) {

        self.name = name
        self.key = key
        self.enableKey = enableKey
        self.range = range
        self.step = step
        self.values = values
        self.help = help
        self.getEnable = getEnable
        self.setEnable = setEnable
        self.getter = get
        self.setter = set
    }
    
    var enabled: Bool? {
        get { getEnable?() ?? nil }
        set { setEnable?(newValue ?? false) }
    }
    var value: Float {
        get { getter?() ?? 0 }
        set { setter?(newValue) }
    }
}

class ShaderSettingGroup {

    // Setting group name
    let title: String

    // Enable key for this setting
    let key: String?

    // All settings in this group
    var children: [ShaderSetting]

    // The NSTableCellView associated with this group
    var view: ShaderGroupView?

    private let getter: (() -> Float)?
    private let setter: ((Float) -> Void)?

    var count: Int { children.filter { $0.hidden == false }.count }

    init(title: String, key: String? = nil,
         get: (() -> Float)? = nil,
         set: ((Float) -> Void)? = nil,
         _ children: [ShaderSetting]) {

        self.title = title
        self.key = key
        self.children = children
        self.getter = get
        self.setter = set
    }
    
    var value: Float {
        get { getter?() ?? 0 }
        set { setter?(newValue) }
    }
}

@MainActor
class Shader : Loggable {

    static var device: MTLDevice { MTLCreateSystemDefaultDevice()! }

    // Enables debug output to the console
    let logging: Bool = false

    var name: String = ""
    var settings: [ShaderSettingGroup] = []

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

    // Looks up the shader setting with a given name
    func findSetting(key: String) -> ShaderSetting? {
        return settings.flatMap { $0.children }.first { $0.key == key }
    }

    // Get or sets the value of a shader option
    func get(key: String) -> Float { // DEPRECATED
    
        if let setting = findSetting(key: key) {
            return setting.value
        } else {
            print("Invalid key: \(key)")
            fatalError()
        }
    }
        
    func set(key: String, value: Float) { // DEPRECATED
        
        if let setting = findSetting(key: key) {
            setting.value = value
        } else {
            print("Invalid key: \(key)")
            fatalError()
        }
    }
    
    func set(key: String, enable: Bool) { set(key: key, value: enable ? 1 : 0) }
    func set(key: String, item: Int) { set(key: key, value: Float(item)) }

    func setHidden(key: String, value: Bool) {
        if let setting = findSetting(key: key) { setting.hidden = value }
    }
}

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

class BilinearShader: ScaleShader<MPSImageBilinearScale> {

    init() { super.init(name: "Bilinear") }
}

class LanczosShader: ScaleShader<MPSImageLanczosScale> {

    init() { super.init(name: "Lanczos") }
}
