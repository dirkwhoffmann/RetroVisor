// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

// This shader is my personal playground for developing self-made CRT effects.

@MainActor
final class PlaygroundShader: Shader {

    var pass1: Kernel!
    var pass2: Kernel!

    var dotmask: MTLTexture!

    init() { super.init(name: "Playground") }

    override func get(key: String) -> Float { return 0 }
    override func set(key: String, value: Float) { }

    override func activate() {

        super.activate()
        pass1 = PlaygroundKernel1(sampler: ShaderLibrary.linear)
        pass2 = PlaygroundKernel2(sampler: ShaderLibrary.linear)
    }

    override func apply(commandBuffer: MTLCommandBuffer,
                        in inTexture: MTLTexture, out outTexture: MTLTexture) {

        // Create the dotmask texture if needed
        if dotmask == nil ||
            dotmask!.width  != outTexture.width ||
            dotmask!.height != outTexture.height ||
            dotmask!.pixelFormat != outTexture.pixelFormat {

            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: outTexture.pixelFormat,
                width: outTexture.width,
                height: outTexture.height,
                mipmapped: false
            )
            desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
            dotmask = outTexture.device.makeTexture(descriptor: desc)
        }

        //
        // Pass 1: Create the dotmask
        //

        pass1.apply(commandBuffer: commandBuffer,
                    source: inTexture, target: dotmask,
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride)

        //
        // Pass 2: Render the image
        //

        pass2.apply(commandBuffer: commandBuffer,
                    textures: [inTexture, dotmask, outTexture],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride)
    }
}
