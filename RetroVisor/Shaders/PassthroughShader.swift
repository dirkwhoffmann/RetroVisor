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

    override func activate() {

        super.activate()
        passthrough = BypassFilter(sampler: ShaderLibrary.linear)
    }

    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        ShaderLibrary.lanczos.apply(commandBuffer: commandBuffer,
                                    in: input, out: output, rect: rect)

        /*
        passthrough.apply(commandBuffer: commandBuffer,
                          source: input, target: output,
                          options: &app.windowController!.metalView!.uniforms,
                          length: MemoryLayout<Uniforms>.stride)
        */
    }
}
