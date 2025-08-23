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

struct ShaderSetting {

    let name: String

    let enableKey: String?
    let key: String

    // Parameters for numeric arguments
    let range: ClosedRange<Double>?
    let step: Float

    // Parameters for enum-like arguments
    let values: [(String,Int)]?

    // Optional help string
    let help: String?

    // Indicates if the setting can be disabled
    var optional: Bool {
        enableKey != nil
    }

    var formatString: String {
        return step < 0.1 ? "%.2f" : step < 1.0 ? "%.1f" : "%.0f"
    }

    init(name: String, enableKey: String? = nil, key: String,
         range: ClosedRange<Double>? = nil, step: Float = 0.01,
         values: [(String,Int)]? = nil, help: String? = nil) {

        self.name = name
        self.key = key
        self.enableKey = enableKey
        self.range = range
        self.step = step
        self.values = values
        self.help = help
    }
}

@MainActor
class Shader : Loggable {

    static var device: MTLDevice { MTLCreateSystemDefaultDevice()! }

    // Enables debug output to the console
    let logging: Bool = false

    var name: String = ""
    var settings: [ShaderSetting] = []

    init(name: String) {

        self.name = name
    }

    func activate() {
        log("Activating \(name)")
    }

    func retire() {
        log("Retiring \(name)")
    }

    func apply(commandBuffer: MTLCommandBuffer,
               in input: MTLTexture, out output: MTLTexture, rect: CGRect = .unity) {

        fatalError("To be implemented by a subclass")
    }

    func get(key: String) -> Float { NSSound.beep(); return 0 }
    func isEnabled(key: String) -> Bool { return true }
    func set(key: String, value: Float) { NSSound.beep() }
    func apply(to encoder: MTLRenderCommandEncoder, pass: Int = 1) { }

    func set(key: String, enable: Bool) { set(key: key, value: enable ? 1 : 0) }
    func set(key: String, item: Int) { set(key: key, value: Float(item)) }
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
