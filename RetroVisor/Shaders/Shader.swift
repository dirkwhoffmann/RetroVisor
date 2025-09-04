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
struct Binding {
    
    let key: String
    let get: () -> Float
    let set: (Float) -> Void
    
    init(key: String, get: @escaping () -> Float, set: @escaping (Float) -> Void) {
        
        self.key = key
        self.get = get
        self.set = set
    }
}

@MainActor
class ShaderSetting {

    // Description of this setting
    var title: String

    // Parameters for numeric settings
    let range: ClosedRange<Double>?
    let step: Float

    // Parameters for enum settings
    let items: [(String,Int)]?

    // Optional help string
    let help: String?

    // Indicates if this options should be hidden in the GUI
    // var hidden: () -> Bool = { false }

    // Binding for the enable key
    private var enable: Binding?

    // Binding for the value key
    private var value: Binding?
    
    // Format string for numeric arguments
    var formatString: String { "%.3g" }

    init(title: String = "",
         range: ClosedRange<Double>? = nil,
         step: Float = 0.01,
         items: [(String,Int)]? = nil,
         enable: Binding? = nil,
         value: Binding? = nil,
         help: String? = nil
        ) {

        self.title = title
        self.enable = enable
        self.value = value
        self.range = range
        self.step = step
        self.items = items
        self.help = help
    }
 
    var enableKey: String { enable?.key ?? "" }
    var valueKey: String { value?.key ?? "" }

    var enabled: Bool? {
        get { enable.map { $0.get() != 0 } }
        set { newValue.map { enable?.set($0.floatValue) } }
    }
                    
    var boolValue: Bool? {
        get { value.map { $0.get() != 0 } }
        set { newValue.map { value?.set($0.floatValue) } }
    }

    var int32Value: Int32? {
        get { value.map { Int32($0.get()) } }
        set { newValue.map { value?.set(Float($0)) } }
    }

    var intValue: Int? {
        get { value.map { Int($0.get()) } }
        set { newValue.map { value?.set(Float($0)) } }
    }

    var floatValue: Float? {
        get { value.map { $0.get() } }
        set { newValue.map { value?.set($0) } }
    }
}

@MainActor
class Group : ShaderSetting {

    // The cell view associated with this group
    var view: ShaderTableCellView?
    
    // The settings in this group
    var children: [ShaderSetting]
    
    // var count: Int { children.filter { $0.hidden() == false }.count }
    
    init(title: String = "",
         range: ClosedRange<Double>? = nil,
         step: Float = 0.01,
         items: [(String,Int)]? = nil,
         enable: Binding? = nil,
         value: Binding? = nil,
         help: String? = nil,
         hidden: @escaping () -> Bool = { false },
         _ children: [ShaderSetting]) {
        
        self.children = children
        super.init(title: title,
                   range: range,
                   step: step,
                   items: items,
                   enable: enable,
                   value: value,
                   help: help)
    }
    
    func findSetting(key: String) -> ShaderSetting? {
        
        // Check this setting's bindings
        if enableKey == key || valueKey == key { return self }
        
        // Recurse into children
        for child in children {
            if child.enableKey == key || child.valueKey == key { return child }
        }
        
        return nil
    }
}

@MainActor
protocol ShaderDelegate {
    
    func title(setting: ShaderSetting) -> String
    func isHidden(setting: ShaderSetting) -> Bool
}

extension ShaderDelegate {
    
    func title(setting: ShaderSetting) -> String { setting.title }
    func isHidden(key: String) -> Bool { false }
}

@MainActor
class Shader : Loggable {

    static var device: MTLDevice { MTLCreateSystemDefaultDevice()! }

    // Enables debug output to the console
    let logging: Bool = false

    // Name of this shader
    var name: String = ""
    
    // Shader settings
    var settings: [Group] = []

    // Delegate
    var delegate: ShaderDelegate?
    
    init(name: String) {

        self.name = name
    }
    
    // Searches a setting by name
    func findSetting(key: String) -> ShaderSetting? {
        for group in settings { if let match = group.findSetting(key: key) { return match } }
        return nil
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
