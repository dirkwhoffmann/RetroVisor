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

// This shader is my personal playground for developing self-made CRT effects.

struct PlaygroundUniforms {

    var GRID_WIDTH: Float
    var GRID_HEIGHT: Float
    var MIN_DOT_WIDTH: Float
    var MAX_DOT_WIDTH: Float
    var MIN_DOT_HEIGHT: Float
    var MAX_DOT_HEIGHT: Float
    var GLOW: Float

    static let defaults = PlaygroundUniforms(

        GRID_WIDTH: 12,
        GRID_HEIGHT: 18,
        MIN_DOT_WIDTH: 5,
        MAX_DOT_WIDTH: 10,
        MIN_DOT_HEIGHT: 8,
        MAX_DOT_HEIGHT: 16,
        GLOW: 5
    )
}

@MainActor
final class PlaygroundShader: Shader {

    var pass1: Kernel!
    var pass2: Kernel!
    var uniforms: PlaygroundUniforms = .defaults

    var blur: MTLTexture!
    var image: MTLTexture!
    var dotmask: MTLTexture!

    init() {

        super.init(name: "Playground")

        settings = [

            ShaderSetting(
                name: "Grid width",
                key: "GRID_WIDTH",
                range: 1.0...60.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Grid height",
                key: "GRID_HEIGHT",
                range: 1.0...60.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Minimal dot width",
                key: "MIN_DOT_WIDTH",
                range: 1.0...60.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Maximal dot width",
                key: "MAX_DOT_WIDTH",
                range: 1.0...60.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Minimal dot height",
                key: "MIN_DOT_HEIGHT",
                range: 1.0...60.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Maximal dot height",
                key: "MAX_DOT_HEIGHT",
                range: 1.0...60.0,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Glow",
                key: "GLOW",
                range: 1.0...60.0,
                step: 0.1,
                help: nil
            ),
        ]
    }

    override func get(key: String) -> Float {

        switch key {
        case "GRID_WIDTH": return uniforms.GRID_WIDTH
        case "GRID_HEIGHT": return uniforms.GRID_HEIGHT
        case "MIN_DOT_WIDTH": return uniforms.MIN_DOT_WIDTH
        case "MIN_DOT_HEIGHT": return uniforms.MIN_DOT_HEIGHT
        case "MAX_DOT_WIDTH": return uniforms.MAX_DOT_WIDTH
        case "MAX_DOT_HEIGHT": return uniforms.MAX_DOT_HEIGHT
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
        case "MIN_DOT_WIDTH": uniforms.MIN_DOT_WIDTH = value
        case "MIN_DOT_HEIGHT": uniforms.MIN_DOT_HEIGHT = value
        case "MAX_DOT_WIDTH": uniforms.MAX_DOT_WIDTH = value
        case "MAX_DOT_HEIGHT": uniforms.MAX_DOT_HEIGHT = value
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

        // Create textures if needed
        if inTexture.width != blur?.width || inTexture.height != blur?.height {

            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: inTexture.pixelFormat,
                width: inTexture.width,
                height: inTexture.height,
                mipmapped: false
            )
            desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
            blur = inTexture.device.makeTexture(descriptor: desc)
        }

        if dotmask?.width != outTexture.width || dotmask?.height != outTexture.height {

            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: outTexture.pixelFormat,
                width: outTexture.width,
                height: outTexture.height,
                mipmapped: false
            )
            desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
            image = outTexture.device.makeTexture(descriptor: desc)
            dotmask = outTexture.device.makeTexture(descriptor: desc)
        }

        //
        // Pass 1: Create a blurred helper texture
        //

        let width = Int(2 * uniforms.GRID_WIDTH) | 1
        let height = Int(uniforms.GRID_HEIGHT) | 1
        let blurFilter = MPSImageBox(device: PlaygroundShader.device,
                               kernelWidth: width, kernelHeight: height)
        blurFilter.encode(commandBuffer: commandBuffer, sourceTexture: inTexture, destinationTexture: blur)

        //
        // Pass 1: Create the dotmask
        //

        /*
        pass1.apply(commandBuffer: commandBuffer,
                    textures: [inTexture, image, dotmask],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)
        */

        //
        // Pass 2: Render the image
        //

        pass2.apply(commandBuffer: commandBuffer,
                    textures: [inTexture, blur, outTexture],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)
    }
}
