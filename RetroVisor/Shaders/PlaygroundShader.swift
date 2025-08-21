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
    var INPUT_PIXEL_SIZE: Float
    var CHROMA_RADIUS: Float

    var SCANLINE_BRIGHTNESS: Float
    var SCANLINE_WEIGHT: Float

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
        INPUT_PIXEL_SIZE: 1,
        CHROMA_RADIUS: 1.3,

        SCANLINE_BRIGHTNESS: 1.0,
        SCANLINE_WEIGHT: 1.0,

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

    var splitKernel: Kernel!
    var crtKernel: Kernel!
    var chromaKernel: Kernel!
    var uniforms: PlaygroundUniforms = .defaults

    // Result of pass 1: Downscaled input texture
    var src: MTLTexture!

    // Result of pass 2: Texture in YUV/YIQ space
    var ycc: MTLTexture!

    // Result of pass 3: Texture with composite effects applied
    var rgb: MTLTexture!

    // Result of pass 4: Texture with CRT effects applied
    var crt: MTLTexture!

    // var texRect: SIMD4<Float> { app.windowController!.metalView!.uniforms.texRect }

    var transform = MPSScaleTransform.init() // scaleX: 1.5, scaleY: 1.5, translateX: 0.0, translateY: 0.0)

    init() {

        super.init(name: "Dirk's Playground")

        settings = [

            ShaderSetting(
                name: "Input Pixel Size",
                key: "INPUT_PIXEL_SIZE",
                optional: true,
                range: 1...16,
                step: 1
            ),

            ShaderSetting(
                name: "Video Standard",
                key: "PAL",
                values: [("PAL", 1), ("NTSC", 0)]
            ),

            ShaderSetting(
                name: "Chroma Radius",
                key: "CHROMA_RADIUS",
                range: 1...10,
                step: 1
            ),

            ShaderSetting(
                name: "Scanline Brightness",
                key: "SCANLINE_BRIGHTNESS",
                range: 0.0...2.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Scanline Weight",
                key: "SCANLINE_WEIGHT",
                range: 0.1...20.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Brightness",
                key: "BRIGHTNESS",
                range: 0.0...2.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Glow",
                key: "GLOW",
                range: 0.0...2.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Grid Width",
                key: "GRID_WIDTH",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Grid Height",
                key: "GRID_HEIGHT",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Minimal Dot Width",
                key: "MIN_DOT_WIDTH",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Maximal Dot Width",
                key: "MAX_DOT_WIDTH",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Minimal Dot Height",
                key: "MIN_DOT_HEIGHT",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Maximal Dot Height",
                key: "MAX_DOT_HEIGHT",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Phospor Shape",
                key: "SHAPE",
                range: 1.0...10.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Phosphor Feather",
                key: "FEATHER",
                range: 0.0...1.0,
                step: 0.01
            )
        ]
    }

    override func get(key: String) -> Float {

        switch key {
        case "PAL": return Float(uniforms.PAL)
        case "INPUT_PIXEL_SIZE": return uniforms.INPUT_PIXEL_SIZE
        case "CHROMA_RADIUS": return uniforms.CHROMA_RADIUS
        case "SCANLINE_BRIGHTNESS": return uniforms.SCANLINE_BRIGHTNESS
        case "SCANLINE_WEIGHT": return uniforms.SCANLINE_WEIGHT

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
        case "INPUT_PIXEL_SIZE": uniforms.INPUT_PIXEL_SIZE = value
        case "CHROMA_RADIUS": uniforms.CHROMA_RADIUS = value
        case "SCANLINE_BRIGHTNESS": uniforms.SCANLINE_BRIGHTNESS = value
        case "SCANLINE_WEIGHT": uniforms.SCANLINE_WEIGHT = value

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
        splitKernel = ColorSpaceFilter(sampler: ShaderLibrary.linear)
        crtKernel = CrtFilter(sampler: ShaderLibrary.linear)
        chromaKernel = CompositeFilter(sampler: ShaderLibrary.linear)
    }

    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        // Size of the downscaled input texture
        let inpWidth = output.width / Int(uniforms.INPUT_PIXEL_SIZE)
        let inpHeight = output.height / Int(uniforms.INPUT_PIXEL_SIZE)

        // Size of the upscaled CRT texture
        let crtWidth = 2 * output.width
        let crtHeight = 2 * output.height

        // Update intermediate textures
        if ycc?.width != inpWidth || ycc?.height != inpHeight {

            print("Creating downscaled textures (\(inpWidth) x \(inpHeight))...")
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: output.pixelFormat,
                width: inpWidth,
                height: inpHeight,
                mipmapped: false
            )
            desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
            src = output.device.makeTexture(descriptor: desc)
            ycc = output.device.makeTexture(descriptor: desc)
            rgb = output.device.makeTexture(descriptor: desc)
        }

        if crt?.width != crtWidth || crt?.height != crtHeight {

            print("Creating upscaled CRT texture (\(crtWidth) x \(crtHeight))...")
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: output.pixelFormat,
                width: crtWidth,
                height: crtHeight,
                mipmapped: false
            )
            desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
            crt = output.device.makeTexture(descriptor: desc)
        }

        //
        // Pass 1: Crop and downsample the input area
        //

        /*
        ShaderLibrary.scale(device: PlaygroundShader.device,
                            commandBuffer: commandBuffer,
                            input: input,
                            output: src,
                            rect: texRect);
        */
        ShaderLibrary.bilinear.apply(commandBuffer: commandBuffer,
                                     in: input, out: src, rect: rect)


        //
        // Pass 2: Convert RGB pixels into YUV/YIQ space
        //

        splitKernel.apply(commandBuffer: commandBuffer,
                    textures: [src, ycc],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)

        //
        // Pass 3: Apply chroma effects
        //

        chromaKernel.apply(commandBuffer: commandBuffer,
                           textures: [ycc, rgb],
                           options: &app.windowController!.metalView!.uniforms,
                           length: MemoryLayout<Uniforms>.stride,
                           options2: &uniforms,
                           length2: MemoryLayout<PlaygroundUniforms>.stride)

        //
        // Pass 4: Emulate CRT artifacts
        //

        crtKernel.apply(commandBuffer: commandBuffer,
                        textures: [rgb, output],
                        options: &app.windowController!.metalView!.uniforms,
                        length: MemoryLayout<Uniforms>.stride,
                        options2: &uniforms,
                        length2: MemoryLayout<PlaygroundUniforms>.stride)

        /*
        //
        // Pass 5: Downscale to final texture
        //

        let filter = MPSImageBilinearScale(device: PlaygroundShader.device)
        filter.encode(commandBuffer: commandBuffer, sourceTexture: crt, destinationTexture: outTex)
        */
    }
}
