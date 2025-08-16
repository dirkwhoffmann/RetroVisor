// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

@MainActor
final class PassthroughShader: Shader {

    var passthrough: Kernel!

    init() {

        super.init(name: "Passthrough")
    }

    override func get(key: String) -> Float { return 0 }
    override func set(key: String, value: Float) { }

    override func activate() {

        super.activate()
        passthrough = BypassFilter(sampler: ShaderLibrary.linear)
    }

    override func apply(commandBuffer: MTLCommandBuffer,
                        in inTexture: MTLTexture, out outTexture: MTLTexture) {

        passthrough.apply(commandBuffer: commandBuffer,
                          source: inTexture, target: outTexture,
                          options: &app.windowController!.metalView!.uniforms,
                          length: MemoryLayout<Uniforms>.stride)
    }
}
