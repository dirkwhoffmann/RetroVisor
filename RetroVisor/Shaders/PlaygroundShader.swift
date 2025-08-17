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

struct PlaygroundUniforms {

    var GRID_WIDTH: Float
    var GRID_HEIGHT: Float
    var DOT_WIDTH: Float
    var DOT_HEIGHT: Float
    var GLOW: Float

    static let defaults = PlaygroundUniforms(

        GRID_WIDTH: 12,
        GRID_HEIGHT: 18,
        DOT_WIDTH: 10,
        DOT_HEIGHT: 16,
        GLOW: 5
    )
}

@MainActor
final class PlaygroundShader: Shader {

    var pass1: Kernel!
    var pass2: Kernel!
    var uniforms: PlaygroundUniforms = .defaults

    var dotmask: MTLTexture!

    init() {

        super.init(name: "Playground")

        settings = [

            ShaderSetting(
                name: "Grid width",
                key: "GRID_WIDTH",
                range: 1.0...30.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Grid height",
                key: "GRID_HEIGHT",
                range: 1.0...30.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Dot width",
                key: "DOT_WIDTH",
                range: 1.0...30.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Dot height",
                key: "DOT_HEIGHT",
                range: 1.0...30.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Glow",
                key: "GLOW",
                range: 1.0...30.0,
                step: 0.1,
                help: nil
            ),
        ]
    }

    override func get(key: String) -> Float {

        switch key {
        case "GRID_WIDTH": return uniforms.GRID_WIDTH
        case "GRID_HEIGHT": return uniforms.GRID_HEIGHT
        case "DOT_WIDTH": return uniforms.DOT_WIDTH
        case "DOT_HEIGHT": return uniforms.DOT_HEIGHT
        case "GLOW": return uniforms.GLOW

        default:
            NSSound.beep()
            return 0
        }
    }

    override func set(key: String, value: Float) {

        switch key {
        case "GRID_WIDTH": uniforms.GRID_WIDTH = value
        case "GRID_HEIGHT": uniforms.GRID_HEIGHT = value
        case "DOT_WIDTH": uniforms.DOT_WIDTH = value
        case "DOT_HEIGHT": uniforms.DOT_HEIGHT = value
        case "GLOW": uniforms.GLOW = value

        default:
            NSSound.beep()
        }
    }

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
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)

        //
        // Pass 2: Render the image
        //

        pass2.apply(commandBuffer: commandBuffer,
                    textures: [inTexture, dotmask, outTexture],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride)
    }
}
