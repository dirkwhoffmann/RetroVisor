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

    var INPUT_TEX_SCALE: Float
    var OUTPUT_TEX_SCALE: Float
    var RESAMPLE_FILTER: ResampleFilterType
    
    var PAL: Int32
    var GAMMA_INPUT: Float
    var GAMMA_OUTPUT: Float
    var CHROMA_RADIUS: Float

    var BLOOM_ENABLE: Int32
    var BLOOM_FILTER: BlurFilterType
    var BLOOM_THRESHOLD: Float
    var BLOOM_INTENSITY: Float
    var BLOOM_RADIUS_X: Float
    var BLOOM_RADIUS_Y: Float

    var SHADOW_ENABLE: Float
    var BRIGHTNESS: Float
    var GLOW: Float
    var SHADOW_GRID_WIDTH: Float
    var SHADOW_GRID_HEIGHT: Float
    var SHADOW_DOT_WIDTH: Float
    var SHADOW_DOT_HEIGHT: Float
    var SHADOW_DOT_WEIGHT: Float
    var SHADOW_DOT_GLOW: Float
    var SHADOW_FEATHER: Float

    var DOTMASK_ENABLE: Int32
    var DOTMASK: Int32
    var DOTMASK_BRIGHTNESS: Float

    var DEBUG_ENABLE: Int32
    var DEBUG_TEXTURE: Int32
    var DEBUG_SLIDER: Float

    static let defaults = PlaygroundUniforms(

        INPUT_TEX_SCALE: 0.5,
        OUTPUT_TEX_SCALE: 2.0,
        RESAMPLE_FILTER: .bilinear,

        PAL: 0,
        GAMMA_INPUT: 2.2,
        GAMMA_OUTPUT: 2.2,
        CHROMA_RADIUS: 1.3,

        BLOOM_ENABLE: 0,
        BLOOM_FILTER: .box,
        BLOOM_THRESHOLD: 0.7,
        BLOOM_INTENSITY: 1.0,
        BLOOM_RADIUS_X: 5,
        BLOOM_RADIUS_Y: 3,

        /*
        SCANLINE_ENABLE: 0,
        SCANLINE_BRIGHTNESS: 1.0,
        SCANLINE_WEIGHT1: 0.5,
        SCANLINE_WEIGHT2: 0.5,
        SCANLINE_WEIGHT3: 0.5,
        SCANLINE_WEIGHT4: 0.5,
        */

        SHADOW_ENABLE: 1,
        BRIGHTNESS: 1,
        GLOW: 1,
        SHADOW_GRID_WIDTH: 5,
        SHADOW_GRID_HEIGHT: 8,
        SHADOW_DOT_WIDTH: 0.9,
        SHADOW_DOT_HEIGHT: 0.9,
        SHADOW_DOT_WEIGHT: 0.5,
        SHADOW_DOT_GLOW: 1.0,
        SHADOW_FEATHER: 0.2,

        DOTMASK_ENABLE: 0,
        DOTMASK: 0,
        DOTMASK_BRIGHTNESS: 0.5,

        DEBUG_ENABLE: 1,
        DEBUG_TEXTURE: 9,
        DEBUG_SLIDER: 0.5
    )
}

@MainActor
final class PlaygroundShader: Shader {

    var splitKernel: Kernel!
    var crtKernel: Kernel!
    var chromaKernel: Kernel!
    var shadowMaskKernel: Kernel!
    var debugKernel: Kernel!

    var uniforms: PlaygroundUniforms = .defaults

    // Result of pass 1: Downscaled input texture
    var src: MTLTexture!

    // Result of pass 2: Texture in YUV/YIQ space
    var ycc: MTLTexture!

    // Result of pass 3: Textures with composite effects applied
    var rgb: MTLTexture!
    var bri: MTLTexture!

    // Result of pass 4: The bloom texture
    var blm: MTLTexture!

    // Result of pass 5: Texture with CRT effects applied
    var crt: MTLTexture!

    // Performance shader for computing mipmaps
    var pyramid: MPSImagePyramid!

    // Resampler used for image scaling
    var resampler = ResampleFilter()

    // Blur filter
    var blurFilter = BlurFilter()

    // Shadow mask and dot mask textures
    var shadow: MTLTexture!
    var dotmask: MTLTexture!

    // var dotmaskType: Int32?
    // var dotmaskBrightness: Float?

    //
    var dotMaskLibrary: DotMaskLibrary!

    // var texRect: SIMD4<Float> { app.windowController!.metalView!.uniforms.texRect }

    var transform = MPSScaleTransform.init() // scaleX: 1.5, scaleY: 1.5, translateX: 0.0, translateY: 0.0)

    init() {

        super.init(name: "Dirk's Playground")

        settings = [

            ShaderSettingGroup(title: "Textures", [

                ShaderSetting(
                    name: "Input Downscaling Factor",
                    key: "INPUT_TEX_SCALE",
                    range: 0.125...1.0,
                    step: 0.125
                ),

                ShaderSetting(
                    name: "Output Upscaling Factor",
                    key: "OUTPUT_TEX_SCALE",
                    range: 1.0...2.0,
                    step: 0.125
                ),

                ShaderSetting(
                    name: "Resampler",
                    key: "RESAMPLE_FILTER",
                    values: [("BILINEAR", 0), ("LANCZOS", 1)]
                ),

            ]),

            ShaderSettingGroup(title: "Chroma Effects", [

                ShaderSetting(
                    name: "Video Standard",
                    key: "PAL",
                    values: [("PAL", 1), ("NTSC", 0)]
                ),

                ShaderSetting(
                    name: "Gamma Input",
                    key: "GAMMA_INPUT",
                    range: 0.1...5.0,
                    step: 0.1
                ),

                ShaderSetting(
                    name: "Gamma Output",
                    key: "GAMMA_OUTPUT",
                    range: 0.1...5.0,
                    step: 0.1
                ),

                ShaderSetting(
                    name: "Chroma Radius",
                    key: "CHROMA_RADIUS",
                    range: 1...10,
                    step: 1
                ),
            ]),

            ShaderSettingGroup(title: "Blooming", key: "BLOOM_ENABLE", [

                ShaderSetting(
                    name: "Bloom Filter",
                    key: "BLOOM_FILTER",
                    values: [("BOX", 0), ("TENT", 1), ("GAUSS", 2), ("MEDIAN", 3)]
                ),

                ShaderSetting(
                    name: "Bloom Threshold",
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

                /*
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
                 */

            ]),

            ShaderSettingGroup(title: "Shadow Mask", key: "SHADOW_ENABLE", [

                ShaderSetting(
                    name: "Grid Width",
                    key: "SHADOW_GRID_WIDTH",
                    range: 1.0...60.0,
                    step: 1.0
                ),

                ShaderSetting(
                    name: "Grid Height",
                    key: "SHADOW_GRID_HEIGHT",
                    range: 1.0...60.0,
                    step: 1.0
                ),

                ShaderSetting(
                    name: "Maximal Dot Width",
                    key: "SHADOW_DOT_WIDTH",
                    range: 0.0...1.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Maximal Dot Height",
                    key: "SHADOW_DOT_HEIGHT",
                    range: 0.0...1.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Weight",
                    key: "SHADOW_DOT_WEIGHT",
                    range: 0.0...2.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Glow",
                    key: "SHADOW_DOT_GLOW",
                    range: 0.05...5.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Phosphor Feather",
                    key: "SHADOW_FEATHER",
                    range: 0.0...3.0,
                    step: 0.01
                )
            ]),

            ShaderSettingGroup(title: "Dot Mask", key: "DOTMASK_ENABLE", [

                ShaderSetting(
                    name: "Dotmask",
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
                    range: 0.0...10.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Glow",
                    key: "GLOW",
                    range: 0.0...2.0,
                    step: 0.01
                ),
            ]),

            ShaderSettingGroup(title: "Debugging", key: "DEBUG_ENABLE", [

                ShaderSetting(
                    name: "Debug",
                    key: "DEBUG_TEXTURE",
                    values: [ ("Ycc", 1),
                              ("Ycc (Mipmap 1)", 2),
                              ("Ycc (Mipmap 2)", 3),
                              ("Ycc (Mipmap 3)", 4),
                              ("Ycc (Mipmap 4)", 5),
                              ("Luma", 6),
                              ("Chroma U/I", 7),
                              ("Chroma V/Q", 8),
                              ("Shadow texture", 9),
                              ("Bloom texture", 10) ]
                ),

                ShaderSetting(
                    name: "Debug Slider",
                    key: "DEBUG_SLIDER",
                    range: 0.0...1.0,
                    step: 0.01
                )
            ]),
         ]
    }

    override func get(key: String) -> Float {

        switch key {

        case "INPUT_TEX_SCALE":     return uniforms.INPUT_TEX_SCALE
        case "OUTPUT_TEX_SCALE":    return uniforms.OUTPUT_TEX_SCALE
        case "RESAMPLE_FILTER":     return Float(uniforms.RESAMPLE_FILTER.rawValue)
            
        case "PAL":                 return Float(uniforms.PAL)
        case "GAMMA_INPUT":         return uniforms.GAMMA_INPUT
        case "GAMMA_OUTPUT":        return uniforms.GAMMA_OUTPUT
        case "CHROMA_RADIUS":       return uniforms.CHROMA_RADIUS

        case "BLOOM_ENABLE":        return Float(uniforms.BLOOM_ENABLE)
        case "BLOOM_FILTER":        return Float(uniforms.BLOOM_FILTER.rawValue)
        case "BLOOM_THRESHOLD":     return uniforms.BLOOM_THRESHOLD
        case "BLOOM_INTENSITY":     return uniforms.BLOOM_INTENSITY
        case "BLOOM_RADIUS_X":      return uniforms.BLOOM_RADIUS_X
        case "BLOOM_RADIUS_Y":      return uniforms.BLOOM_RADIUS_Y

            /*
        case "SCANLINE_ENABLE": return Float(uniforms.SCANLINE_ENABLE)
        case "SCANLINE_BRIGHTNESS": return uniforms.SCANLINE_BRIGHTNESS
        case "SCANLINE_WEIGHT1": return uniforms.SCANLINE_WEIGHT1
        case "SCANLINE_WEIGHT2": return uniforms.SCANLINE_WEIGHT2
        case "SCANLINE_WEIGHT3": return uniforms.SCANLINE_WEIGHT3
        case "SCANLINE_WEIGHT4": return uniforms.SCANLINE_WEIGHT4
             */

        case "SHADOW_ENABLE":       return uniforms.SHADOW_ENABLE
        case "BRIGHTNESS":          return uniforms.BRIGHTNESS
        case "GLOW":                return uniforms.GLOW
        case "SHADOW_GRID_WIDTH":   return uniforms.SHADOW_GRID_WIDTH
        case "SHADOW_GRID_HEIGHT":  return uniforms.SHADOW_GRID_HEIGHT
        case "SHADOW_DOT_WIDTH":    return uniforms.SHADOW_DOT_WIDTH
        case "SHADOW_DOT_HEIGHT":   return uniforms.SHADOW_DOT_HEIGHT
        case "SHADOW_DOT_WEIGHT":   return uniforms.SHADOW_DOT_WEIGHT
        case "SHADOW_DOT_GLOW":     return uniforms.SHADOW_DOT_GLOW
        case "SHADOW_FEATHER":      return uniforms.SHADOW_FEATHER

        case "DOTMASK_ENABLE":      return Float(uniforms.DOTMASK_ENABLE)
        case "DOTMASK":             return Float(uniforms.DOTMASK)
        case "DOTMASK_BRIGHTNESS":  return uniforms.DOTMASK_BRIGHTNESS

        case "DEBUG_ENABLE":        return Float(uniforms.DEBUG_ENABLE)
        case "DEBUG_TEXTURE":       return Float(uniforms.DEBUG_TEXTURE)
        case "DEBUG_SLIDER":        return uniforms.DEBUG_SLIDER

        default:
            NSSound.beep()
            fatalError()
            // return 0
        }
    }

    override func set(key: String, value: Float) {

        switch key {

        case "INPUT_TEX_SCALE":     uniforms.INPUT_TEX_SCALE = value
        case "OUTPUT_TEX_SCALE":    uniforms.OUTPUT_TEX_SCALE = value
        case "RESAMPLE_FILTER":     uniforms.RESAMPLE_FILTER = ResampleFilterType(value)!

        case "PAL":                 uniforms.PAL = Int32(value)
        case "GAMMA_INPUT":         uniforms.GAMMA_INPUT = value
        case "GAMMA_OUTPUT":        uniforms.GAMMA_OUTPUT = value
        case "CHROMA_RADIUS":       uniforms.CHROMA_RADIUS = value

        case "BLOOM_ENABLE":        uniforms.BLOOM_ENABLE = Int32(value)
        case "BLOOM_FILTER":        uniforms.BLOOM_FILTER = BlurFilterType(rawValue: Int32(value))!
        case "BLOOM_THRESHOLD":     uniforms.BLOOM_THRESHOLD = value
        case "BLOOM_INTENSITY":     uniforms.BLOOM_INTENSITY = value
        case "BLOOM_RADIUS_X":      uniforms.BLOOM_RADIUS_X = value
        case "BLOOM_RADIUS_Y":      uniforms.BLOOM_RADIUS_Y = value

            /*
        case "SCANLINE_ENABLE": uniforms.SCANLINE_ENABLE = Int32(value)
        case "SCANLINE_BRIGHTNESS": uniforms.SCANLINE_BRIGHTNESS = value
        case "SCANLINE_WEIGHT1": uniforms.SCANLINE_WEIGHT1 = value
        case "SCANLINE_WEIGHT2": uniforms.SCANLINE_WEIGHT2 = value
        case "SCANLINE_WEIGHT3": uniforms.SCANLINE_WEIGHT3 = value
        case "SCANLINE_WEIGHT4": uniforms.SCANLINE_WEIGHT4 = value
             */
            
        case "SHADOW_ENABLE":       uniforms.SHADOW_ENABLE = value
        case "BRIGHTNESS":          uniforms.BRIGHTNESS = value
        case "GLOW":                uniforms.GLOW = value
        case "SHADOW_GRID_WIDTH":   uniforms.SHADOW_GRID_WIDTH = value
        case "SHADOW_GRID_HEIGHT":  uniforms.SHADOW_GRID_HEIGHT = value
        case "SHADOW_DOT_WIDTH":    uniforms.SHADOW_DOT_WIDTH = value
        case "SHADOW_DOT_HEIGHT":   uniforms.SHADOW_DOT_HEIGHT = value
        case "SHADOW_DOT_WEIGHT":   uniforms.SHADOW_DOT_WEIGHT = value
        case "SHADOW_DOT_GLOW":     uniforms.SHADOW_DOT_GLOW = value
        case "SHADOW_FEATHER":      uniforms.SHADOW_FEATHER = value

        case "DOTMASK_ENABLE":      uniforms.DOTMASK_ENABLE = Int32(value)
        case "DOTMASK":             uniforms.DOTMASK = Int32(value)
        case "DOTMASK_BRIGHTNESS":  uniforms.DOTMASK_BRIGHTNESS = value

        case "DEBUG_ENABLE":        uniforms.DEBUG_ENABLE = Int32(value)
        case "DEBUG_TEXTURE":       uniforms.DEBUG_TEXTURE = Int32(value)
        case "DEBUG_SLIDER":        uniforms.DEBUG_SLIDER = value

        default:
            NSSound.beep()
            fatalError()
        }
    }

    override func activate() {

        super.activate()
        splitKernel = ColorSpaceFilter(sampler: ShaderLibrary.linear)
        crtKernel = CrtFilter(sampler: ShaderLibrary.mipmapLinear)
        chromaKernel = CompositeFilter(sampler: ShaderLibrary.linear)
        shadowMaskKernel = ShadowMaskFilter(sampler: ShaderLibrary.mipmapLinear)
        debugKernel = DebugFilter(sampler: ShaderLibrary.mipmapLinear)
        pyramid = MPSImageGaussianPyramid(device: ShaderLibrary.device)
        dotMaskLibrary = DotMaskLibrary()
    }

    func updateTextures(in input: MTLTexture, out output: MTLTexture) {

        // Size of the downscaled input texture
        let inpWidth = Int(Float(output.width) * uniforms.INPUT_TEX_SCALE)
        let inpHeight = Int(Float(output.height) * uniforms.INPUT_TEX_SCALE)

        // Internal texture size
        let crtWidth = Int(Float(output.width) * uniforms.OUTPUT_TEX_SCALE)
        let crtHeight = Int(Float(output.height) * uniforms.OUTPUT_TEX_SCALE)

        // Update intermediate textures
        if ycc?.width != inpWidth || ycc?.height != inpHeight {

            src = output.makeTexture(width: inpWidth, height: inpHeight)
            ycc = output.makeTexture(width: inpWidth, height: inpHeight, mipmaps: 4)
            bri = output.makeTexture(width: inpWidth, height: inpHeight)
            blm = output.makeTexture(width: inpWidth, height: inpHeight)
            rgb = output.makeTexture(width: inpWidth, height: inpHeight)
            dotmask = output.makeTexture(width: inpWidth, height: inpHeight)
        }

        if crt?.width != crtWidth || crt?.height != crtHeight {

            shadow = output.makeTexture(width: crtWidth, height: crtWidth)
            crt = output.makeTexture(width: crtWidth, height: crtHeight)
        }
    }

    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        updateTextures(in: input, out: output)

        //
        // Pass 1: Crop and downsample the input area
        //

        resampler.type = uniforms.RESAMPLE_FILTER
        resampler.apply(commandBuffer: commandBuffer, in: input, out: src, rect: rect)

        //
        // Pass 2: Convert RGB image into YUV/YIQ space and compute mipmaps
        //

        splitKernel.apply(commandBuffer: commandBuffer,
                          textures: [src, ycc],
                          options: &uniforms,
                          length: MemoryLayout<PlaygroundUniforms>.stride)

        pyramid.encode(commandBuffer: commandBuffer, inPlaceTexture: &ycc)

        //
        //
        // Pass 3: Apply chroma effects
        //

        let descriptor = DotMaskDescriptor(type: Int(uniforms.DOTMASK),
                                           brightness: uniforms.DOTMASK_BRIGHTNESS,
                                           blur: uniforms.BRIGHTNESS)

        dotMaskLibrary.create(commandBuffer: commandBuffer,
                              descriptor: descriptor,
                              texture: &dotmask)

        chromaKernel.apply(commandBuffer: commandBuffer,
                           textures: [ycc, dotmask, rgb, bri],
                           options: &uniforms,
                           length: MemoryLayout<PlaygroundUniforms>.stride)

        //
        // Pass 4: Compute the shadow mask
        //

        shadowMaskKernel.apply(commandBuffer: commandBuffer,
                               textures: [ycc, shadow],
                               options: &uniforms,
                               length: MemoryLayout<PlaygroundUniforms>.stride)

        let shadowFilter = MPSImageGaussianBlur(device: ycc.device, sigma: uniforms.SHADOW_FEATHER)
        shadowFilter.encode(commandBuffer: commandBuffer, inPlaceTexture: &shadow)

        //
        // Pass 4: Create the bloom texture
        //

        // print("FILTER: \(uniforms.BLOOM_FILTER)")
        blurFilter.blurType = uniforms.BLOOM_FILTER
        blurFilter.blurWidth = uniforms.BLOOM_RADIUS_X
        blurFilter.blurHeight = uniforms.BLOOM_RADIUS_Y
        blurFilter.apply(commandBuffer: commandBuffer, in: bri, out: blm)

        //
        // Pass 5: Emulate CRT artifacts
        //

        crtKernel.apply(commandBuffer: commandBuffer,
                        textures: [rgb, shadow, dotmask, blm, output],
                        options: &uniforms,
                        length: MemoryLayout<PlaygroundUniforms>.stride)

        //
        // Optional: Run the debugger
        //

        if uniforms.DEBUG_ENABLE > 0 {

            debugKernel.apply(commandBuffer: commandBuffer,
                              textures: [ycc, shadow, dotmask, blm, output],
                              options: &uniforms,
                              length: MemoryLayout<PlaygroundUniforms>.stride)
        }
    }
}
