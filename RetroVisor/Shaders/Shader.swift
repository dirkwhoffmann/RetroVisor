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
    let key: String

    // Indicates if the setting can be disabled
    let optional: Bool

    // Parameters for numeric arguments
    let range: ClosedRange<Double>?
    let step: Float

    // Parameters for enum-like arguments
    let values: [(String,Int)]?

    // Optional help string
    let help: String?

    var formatString: String {
        return step < 0.1 ? "%.2f" : step < 1.0 ? "%.1f" : "%.0f"
    }

    init(name: String, key: String, optional: Bool = false,
         range: ClosedRange<Double>? = nil, step: Float = 0.01,
         values: [(String,Int)]? = nil, help: String? = nil) {

        self.name = name
        self.key = key
        self.optional = optional
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
               in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        fatalError("To be implemented by a subclass")
    }

    func get(key: String) -> Float { return 0 }
    func isEnabled(key: String) -> Bool { return true }
    func set(key: String, value: Float) {}
    func set(key: String, enable: Bool) {}
    func apply(to encoder: MTLRenderCommandEncoder, pass: Int = 1) { }
}

class ScaleShader<F: MPSUnaryImageKernel> : Shader {

    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        let filter = MPSImageLanczosScale(device: output.device)
        var transform = MPSScaleTransform.init(in: input, out: output, rect: rect)

        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in

            filter.scaleTransform = transformPtr
            filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
        }
    }
}

class BilinearShader: ScaleShader<MPSImageBilinearScale> {

    init() { super.init(name: "Lanczos") }
}

class LanczosShader: ScaleShader<MPSImageLanczosScale> {

    init() { super.init(name: "Lanczos") }
}

extension MPSScaleTransform {

    init(in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        let scaleX = Double(output.width) / (rect.width * Double(input.width))
        let scaleY = Double(output.height) / (rect.height * Double(input.height))
        let transX = (-rect.minX * Double(input.width)) * scaleX
        let transY = (-rect.minY * Double(input.height)) * scaleY

        self.init(scaleX: scaleX, scaleY: scaleY, translateX: transX, translateY: transY)
    }
}
