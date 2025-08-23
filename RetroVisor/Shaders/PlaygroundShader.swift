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

    var BLOOM_ENABLE: Int32
    var BLOOM_THRESHOLD: Float
    var BLOOM_INTENSITY: Float
    var BLOOM_RADIUS_X: Float
    var BLOOM_RADIUS_Y: Float

    var SCANLINE_ENABLE: Int32
    var SCANLINE_BRIGHTNESS: Float
    var SCANLINE_WEIGHT1: Float
    var SCANLINE_WEIGHT2: Float
    var SCANLINE_WEIGHT3: Float
    var SCANLINE_WEIGHT4: Float

    var DOTMASK_ENABLE: Int32
    var DOTMASK: Int32
    var DOTMASK_BRIGHTNESS: Float

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

        BLOOM_ENABLE: 0,
        BLOOM_THRESHOLD: 0.7,
        BLOOM_INTENSITY: 1.0,
        BLOOM_RADIUS_X: 5,
        BLOOM_RADIUS_Y: 3,

        SCANLINE_ENABLE: 0,
        SCANLINE_BRIGHTNESS: 1.0,
        SCANLINE_WEIGHT1: 0.5,
        SCANLINE_WEIGHT2: 0.5,
        SCANLINE_WEIGHT3: 0.5,
        SCANLINE_WEIGHT4: 0.5,

        DOTMASK_ENABLE: 1,
        DOTMASK: 0,
        DOTMASK_BRIGHTNESS: 0.5,

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

    // Result of pass 2: Texture in YUV/YIQ space, Bright areas
    var ycc: MTLTexture!

    // Result of pass 3: Textures with composite effects applied
    var rgb: MTLTexture!
    var bri: MTLTexture!

    // Result of pass 4: The bloom texture
    var blm: MTLTexture!

    // Result of pass 5: Texture with CRT effects applied
    var crt: MTLTexture!

    // The dotmask texture
    var dotmask: MTLTexture!

    var dotmaskType: Int32?
    var dotmaskBrightness: Float?

    // var texRect: SIMD4<Float> { app.windowController!.metalView!.uniforms.texRect }

    var transform = MPSScaleTransform.init() // scaleX: 1.5, scaleY: 1.5, translateX: 0.0, translateY: 0.0)

    init() {

        super.init(name: "Dirk's Playground")

        settings = [

            ShaderSetting(
                name: "Input Pixel Size",
                key: "INPUT_PIXEL_SIZE",
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
                name: "Bloom Threshold",
                enableKey: "BLOOM_ENABLE",
                key: "BLOOM_THRESHOLD",
                range: 0.0...1.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Bloom Intensity",
                key: "BLOOM_INTENSITY",
                range: 0.1...2.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Bloom Radius X",
                key: "BLOOM_RADIUS_X",
                range: 0.0...30.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Bloom Radius Y",
                key: "BLOOM_RADIUS_Y",
                range: 0.0...30.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Scanline Brightness",
                enableKey: "SCANLINE_ENABLE",
                key: "SCANLINE_BRIGHTNESS",
                range: 0.0...2.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Scanline Weight 1",
                key: "SCANLINE_WEIGHT1",
                range: 0.1...1.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Scanline Weight 2",
                key: "SCANLINE_WEIGHT2",
                range: 0.1...1.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Scanline Weight 3",
                key: "SCANLINE_WEIGHT3",
                range: 0.1...1.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Scanline Weight 4",
                key: "SCANLINE_WEIGHT4",
                range: 0.1...1.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Dotmask",
                enableKey: "DOTMASK_ENABLE",
                key: "DOTMASK",
                range: 0...4,
                step: 1.0
            ),

            ShaderSetting(
                name: "Dotmask Brightness",
                key: "DOTMASK_BRIGHTNESS",
                range: 0...1,
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

        case "BLOOM_ENABLE": return Float(uniforms.BLOOM_ENABLE)
        case "BLOOM_THRESHOLD": return uniforms.BLOOM_THRESHOLD
        case "BLOOM_INTENSITY": return uniforms.BLOOM_INTENSITY
        case "BLOOM_RADIUS_X": return uniforms.BLOOM_RADIUS_X
        case "BLOOM_RADIUS_Y": return uniforms.BLOOM_RADIUS_Y

        case "SCANLINE_ENABLE": return Float(uniforms.SCANLINE_ENABLE)
        case "SCANLINE_BRIGHTNESS": return uniforms.SCANLINE_BRIGHTNESS
        case "SCANLINE_WEIGHT1": return uniforms.SCANLINE_WEIGHT1
        case "SCANLINE_WEIGHT2": return uniforms.SCANLINE_WEIGHT2
        case "SCANLINE_WEIGHT3": return uniforms.SCANLINE_WEIGHT3
        case "SCANLINE_WEIGHT4": return uniforms.SCANLINE_WEIGHT4

        case "DOTMASK_ENABLE": return Float(uniforms.DOTMASK_ENABLE)
        case "DOTMASK": return Float(uniforms.DOTMASK)
        case "DOTMASK_BRIGHTNESS": return uniforms.DOTMASK_BRIGHTNESS

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

        case "BLOOM_ENABLE": uniforms.BLOOM_ENABLE = Int32(value)
        case "BLOOM_THRESHOLD": uniforms.BLOOM_THRESHOLD = value
        case "BLOOM_INTENSITY": uniforms.BLOOM_INTENSITY = value
        case "BLOOM_RADIUS_X": uniforms.BLOOM_RADIUS_X = value
        case "BLOOM_RADIUS_Y": uniforms.BLOOM_RADIUS_Y = value

        case "SCANLINE_ENABLE": uniforms.SCANLINE_ENABLE = Int32(value)
        case "SCANLINE_BRIGHTNESS": uniforms.SCANLINE_BRIGHTNESS = value
        case "SCANLINE_WEIGHT1": uniforms.SCANLINE_WEIGHT1 = value
        case "SCANLINE_WEIGHT2": uniforms.SCANLINE_WEIGHT2 = value
        case "SCANLINE_WEIGHT3": uniforms.SCANLINE_WEIGHT3 = value
        case "SCANLINE_WEIGHT4": uniforms.SCANLINE_WEIGHT4 = value

        case "DOTMASK_ENABLE": uniforms.DOTMASK_ENABLE = Int32(value)
        case "DOTMASK": uniforms.DOTMASK = Int32(value)
        case "DOTMASK_BRIGHTNESS": uniforms.DOTMASK_BRIGHTNESS = value

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

    override func set(key: String, enable: Bool) {

        switch key {
        case "BLOOM_THRESHOLD": uniforms.BLOOM_ENABLE = enable ? 1 : 0

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

    func updateDotMask() {

        let brightness = uniforms.DOTMASK_BRIGHTNESS

        let max  = UInt8(85 + brightness * 170)
        let base = UInt8((1 - brightness) * 85)
        let none = UInt8(30 + (1 - brightness) * 55)

        let R = UInt32(r: max, g: base, b: base)
        let G = UInt32(r: base, g: max, b: base)
        let B = UInt32(r: base, g: base, b: max)
        let M = UInt32(r: max, g: base, b: max)
        let W = UInt32(r: max, g: max, b: max)
        let N = UInt32(r: none, g: none, b: none)

        let maskSize = [
            CGSize(width: 1, height: 1),
            CGSize(width: 3, height: 1),
            CGSize(width: 4, height: 1),
            CGSize(width: 3, height: 9),
            CGSize(width: 4, height: 8)
        ]

        let maskData = [

            [ W ],
            [ M, G, N ],
            [ R, G, B, N ],
            [ M, G, N,
              M, G, N,
              N, N, N,
              N, M, G,
              N, M, G,
              N, N, N,
              G, N, M,
              G, N, M,
              N, N, N],
            [ R, G, B, N,
              R, G, B, N,
              R, G, B, N,
              N, N, N, N,
              B, N, R, G,
              B, N, R, G,
              B, N, R, G,
              N, N, N, N]
        ]

        let n = Int(uniforms.DOTMASK)

        // Create image representation in memory
        let cap = Int(maskSize[n].width) * Int(maskSize[n].height)
        let mask = calloc(cap, MemoryLayout<UInt32>.size)!
        let ptr = mask.bindMemory(to: UInt32.self, capacity: cap)
        for i in 0 ... cap - 1 {
            ptr[i] = maskData[n][i]
        }

        // Create image
        let image = NSImage.make(data: mask, rect: maskSize[n])

        // Convert image to texture
        dotmask = image?.toTexture(device: ShaderLibrary.device)
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
            bri = output.device.makeTexture(descriptor: desc)
            blm = output.device.makeTexture(descriptor: desc)
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

        if (dotmaskType != uniforms.DOTMASK || dotmaskBrightness != uniforms.DOTMASK_BRIGHTNESS) {

            updateDotMask()
            dotmaskType = uniforms.DOTMASK
            dotmaskBrightness = uniforms.DOTMASK_BRIGHTNESS
        }

        //
        // Pass 1: Crop and downsample the input area
        //

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
                           textures: [ycc, dotmask, rgb, bri],
                           options: &app.windowController!.metalView!.uniforms,
                           length: MemoryLayout<Uniforms>.stride,
                           options2: &uniforms,
                           length2: MemoryLayout<PlaygroundUniforms>.stride)

        //
        // Pass 4: Create the bloom texture
        //

        let blur = MPSImageBox(device: bri.device,
                               kernelWidth: Int(uniforms.BLOOM_RADIUS_X * 2) | 1,
                               kernelHeight: Int(uniforms.BLOOM_RADIUS_Y * 2) | 1)
        blur.encode(commandBuffer: commandBuffer,
                    inPlaceTexture: &bri, fallbackCopyAllocator: nil)

        //
        // Pass 5: Emulate CRT artifacts
        //

        crtKernel.apply(commandBuffer: commandBuffer,
                        textures: [rgb, dotmask, bri, output],
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
