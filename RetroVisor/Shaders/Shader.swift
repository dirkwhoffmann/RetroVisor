// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

struct ShaderSetting {

    let name: String
    let key: String
    let range: ClosedRange<Double>?
    let step: Float
    let help: String?

    var formatString: String {
        return step < 0.1 ? "%.2f" : step < 1.0 ? "%.1f" : "%.0f"
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
               in inTexture: MTLTexture, out outTexture: MTLTexture) {

        fatalError("To be implemented by a subclass")
    }

    func get(key: String) -> Float { return 0 }
    func set(key: String, value: Float) {}
    func apply(to encoder: MTLRenderCommandEncoder, pass: Int = 1) { }
}
