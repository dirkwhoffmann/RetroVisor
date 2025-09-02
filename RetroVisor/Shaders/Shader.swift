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

struct Binding {
    
    let key: String
    let get: () -> Float
    let set: (Float) -> Void
    
    init(key: String, get: @escaping () -> Float, set: @escaping (Float) -> Void) {
        
        self.key = key
        self.get = get
        self.set = set
    }
    
    var boolValue: Bool {
        
        get { get() != 0 }
        set { set(newValue ? 1 : 0) }
    }

    var int32Value: Int32 {
        
        get { Int32(get()) }
        set { set(Float(newValue)) }
    }

    var intValue: Int {
        
        get { Int(get()) }
        set { set(Float(newValue)) }
    }

    var floatValue: Float {
        
        get { get() }
        set { set(newValue) }
    }
}

class ShaderSetting {

    // Setting name
    let name: String

    // Parameters for numeric arguments
    let range: ClosedRange<Double>?
    let step: Float

    // Parameters for enum-like arguments
    let items: [(String,Int)]?

    // Optional help string
    let help: String?

    // Indicates if this options should be hidden from the user
    var hidden: () -> Bool = { false }

    // Binding for the optional enable key
    var enable: Binding?

    // Binding for the mandatory value key
    var value: Binding
    
    var formatString: String { "%.3g" }

    init(name: String,
         range: ClosedRange<Double>? = nil,
         step: Float = 0.01,
         items: [(String,Int)]? = nil,
         enable: Binding? = nil,
         value: Binding,
         help: String? = nil,
         hidden: @escaping () -> Bool = { false }
        ) {

        self.name = name
        self.enable = enable
        self.value = value
        self.range = range
        self.step = step
        self.items = items
        self.help = help
        self.hidden = hidden
    }
    
    /*
    var enabled: Bool {
        
        get { enable?.get() != 0 }
        set { enable?.set(newValue ? 1 : 0) }
    }

    var floatValue: Float {
        
        get { value.get() }
        set { value.set(newValue) }
    }
    
    var intValue: Int {
        
        get { Int(value.get()) }
        set { value.set(Float(newValue)) }
    }
    */
}

class Group {

    // Setting group name
    let title: String

    // The NSTableCellView associated with this group
    var view: ShaderGroupView?

    // Binding for the enable key (optional)
    let enable: Binding?
    
    //private let getter: (() -> Float)?
    // private let setter: ((Float) -> Void)?

    // All settings in this group
    var children: [ShaderSetting]
    
    var count: Int { children.filter { $0.hidden() == false }.count }

    init(title: String,
         enable: Binding? = nil,
         // get: (() -> Float)? = nil,
         // set: ((Float) -> Void)? = nil,
         _ children: [ShaderSetting]) {

        self.title = title
        // self.key = key
        self.enable = enable
        self.children = children
        // self.getter = get
        // self.setter = set
    }
    
    var enabled: Bool {
        
        get { enable?.get() != 0 }
        set { enable?.set(newValue ? 1 : 0) }
    }
}

@MainActor
class Shader : Loggable {

    static var device: MTLDevice { MTLCreateSystemDefaultDevice()! }

    // Enables debug output to the console
    let logging: Bool = false

    var name: String = ""
    var settings: [Group] = []

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
