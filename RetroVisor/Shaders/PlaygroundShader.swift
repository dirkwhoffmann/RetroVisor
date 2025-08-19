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

    var PAL: Int32
    var CHROMA_SIGMA: Float
    var PAL_BLEND: Float
    var CHROMA_GAIN: Float

    var BRIGHTNESS: Float
    var GLOW: Float
    var GRID_WIDTH: Float
    var GRID_HEIGHT: Float
    var MIN_DOT_WIDTH: Float
    var MAX_DOT_WIDTH: Float
    var MIN_DOT_HEIGHT: Float
    var MAX_DOT_HEIGHT: Float
    var SHAPE: Float
    var FEATHER: Float

    static let defaults = PlaygroundUniforms(

        PAL: 0,
        CHROMA_SIGMA: 1.3,
        PAL_BLEND: 0.4,
        CHROMA_GAIN: 1.0,

        BRIGHTNESS: 1,
        GLOW: 1,
        GRID_WIDTH: 20,
        GRID_HEIGHT: 20,
        MIN_DOT_WIDTH: 1,
        MAX_DOT_WIDTH: 10,
        MIN_DOT_HEIGHT: 1,
        MAX_DOT_HEIGHT: 10,
        SHAPE: 2.0,
        FEATHER: 0.2
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

        super.init(name: "Dirk's Playground")

        settings = [

            ShaderSetting(
                name: "PAL",
                key: "PAL",
                range: nil,
                step: 1.0,
                help: nil
            ),

            ShaderSetting(
                name: "Chroma Sigma",
                key: "CHROMA_SIGMA",
                range: 1.0...4.0,
                step: 0.01,
                help: nil
            ),

            ShaderSetting(
                name: "PAL Blend",
                key: "PAL_BLEND",
                range: 0.0...2.0,
                step: 0.01,
                help: nil
            ),

            ShaderSetting(
                name: "Chroma Gain",
                key: "CHROMA_GAIN",
                range: 0.5...2.0,
                step: 0.01,
                help: nil
            ),

            ShaderSetting(
                name: "Brightness",
                key: "BRIGHTNESS",
                range: 0.0...2.0,
                step: 0.01,
                help: nil
            ),

            ShaderSetting(
                name: "Glow",
                key: "GLOW",
                range: 0.0...2.0,
                step: 0.01,
                help: nil
            ),

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
                name: "Phospor shape",
                key: "SHAPE",
                range: 1.0...10.0,
                step: 0.01,
                help: nil
            ),

            ShaderSetting(
                name: "Phosphor feather",
                key: "FEATHER",
                range: 0.0...1.0,
                step: 0.01,
                help: nil
            )
        ]
    }

    override func get(key: String) -> Float {

        switch key {
        case "PAL": return Float(uniforms.PAL)
        case "CHROMA_SIGMA": return uniforms.CHROMA_SIGMA
        case "PAL_BLEND": return uniforms.PAL_BLEND
        case "CHROMA_GAIN": return uniforms.CHROMA_GAIN

        case "BRIGHTNESS": return uniforms.BRIGHTNESS
        case "GLOW": return uniforms.GLOW
        case "GRID_WIDTH": return uniforms.GRID_WIDTH
        case "GRID_HEIGHT": return uniforms.GRID_HEIGHT
        case "MIN_DOT_WIDTH": return uniforms.MIN_DOT_WIDTH
        case "MAX_DOT_WIDTH": return uniforms.MAX_DOT_WIDTH
        case "MIN_DOT_HEIGHT": return uniforms.MIN_DOT_HEIGHT
        case "MAX_DOT_HEIGHT": return uniforms.MAX_DOT_HEIGHT
        case "SHAPE": return uniforms.SHAPE
        case "FEATHER": return uniforms.FEATHER

        default:
            NSSound.beep()
            return 0
        }
    }

    override func set(key: String, value: Float) {

        switch key {
        case "PAL": uniforms.PAL = Int32(value)
        case "CHROMA_SIGMA": uniforms.CHROMA_SIGMA = value
        case "PAL_BLEND": uniforms.PAL_BLEND = value
        case "CHROMA_GAIN": uniforms.CHROMA_GAIN = value

        case "BRIGHTNESS": uniforms.BRIGHTNESS = value
        case "GLOW": uniforms.GLOW = value
        case "GRID_WIDTH": uniforms.GRID_WIDTH = value
        case "GRID_HEIGHT": uniforms.GRID_HEIGHT = value
        case "MIN_DOT_WIDTH": uniforms.MIN_DOT_WIDTH = value
        case "MAX_DOT_WIDTH": uniforms.MAX_DOT_WIDTH = value
        case "MIN_DOT_HEIGHT": uniforms.MIN_DOT_HEIGHT = value
        case "MAX_DOT_HEIGHT": uniforms.MAX_DOT_HEIGHT = value
        case "SHAPE": uniforms.SHAPE = value
        case "FEATHER": uniforms.FEATHER = value

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

        // DEPRECATED
        /*
        let width = Int(2 * uniforms.GRID_WIDTH) | 1
        let height = 1
        let blurFilter = MPSImageBox(device: PlaygroundShader.device,
                               kernelWidth: width, kernelHeight: height)
        blurFilter.encode(commandBuffer: commandBuffer, sourceTexture: inTexture, destinationTexture: blur)
        */

        //
        // Pass 1: Emulate video signal artifacts
        //

        pass1.apply(commandBuffer: commandBuffer,
                    textures: [inTexture, outTexture],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)

        //
        // Pass 2: Emulate CRT artifacts
        //

        /*
        pass2.apply(commandBuffer: commandBuffer,
                    textures: [image, outTexture],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)
         */
    }
}
