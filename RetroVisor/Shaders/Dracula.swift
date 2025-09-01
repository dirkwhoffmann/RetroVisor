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

@MainActor
final class DraculaShader: Shader {

    struct Uniforms {
        
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
        
        var DOTMASK_ENABLE: Int32
        var DOTMASK_TYPE: Int32
        var DOTMASK_WIDTH: Float
        var DOTMASK_SHIFT: Float
        var DOTMASK_WEIGHT: Float
        var DOTMASK_BRIGHTNESS: Float
        
        var SCANLINES_ENABLE: Int32
        var SCANLINE_DISTANCE: Float
        var SCANLINE_WEIGHT: Float
        var SCANLINE_BRIGHTNESS: Float
                                        
        var DEBUG_ENABLE: Int32
        var DEBUG_TEXTURE: Int32
        var DEBUG_SLIDER: Float
        
        static let defaults = Uniforms(
            
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
            
            DOTMASK_ENABLE: 1,
            DOTMASK_TYPE: 2,
            DOTMASK_WIDTH: 3,
            DOTMASK_SHIFT: 2.1,
            DOTMASK_WEIGHT: 1.0,
            DOTMASK_BRIGHTNESS: 0.5,
            
            SCANLINES_ENABLE: 0,
            SCANLINE_DISTANCE: 6.0,
            SCANLINE_WEIGHT: 0.2,
            SCANLINE_BRIGHTNESS: 0.5,
                
            DEBUG_ENABLE: 0,
            DEBUG_TEXTURE: 1,
            DEBUG_SLIDER: 0.0
        )
    }

    var splitKernel: Kernel!
    var chromaKernel: Kernel!
    var dotMaskKernel: Kernel!
    var crtKernel: Kernel!
    var debugKernel: Kernel!

    var uniforms: Uniforms = .defaults

    // Result of pass 1: Downscaled input texture
    var src: MTLTexture!

    // Result of pass 2: Texture in linear RGB and YUV/YIQ space
    var lin: MTLTexture!
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
    var dotmask: MTLTexture!

    // Dot mask provider
    var dotMaskLibrary: DotMaskLibrary!

    // var transform = MPSScaleTransform.init() // scaleX: 1.5, scaleY: 1.5, translateX: 0.0, translateY: 0.0)

    init() {

        super.init(name: "Dracula")

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
            ]),

            ShaderSettingGroup(title: "Scanlines", key: "SCANLINES_ENABLE", [

                ShaderSetting(
                    name: "Scanline Distance",
                    key: "SCANLINE_DISTANCE",
                    range: 0...10,
                    step: 1
                ),

                ShaderSetting(
                    name: "Scanline Weight",
                    key: "SCANLINE_WEIGHT",
                    range: 0.0...1.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Scanline Brightness",
                    key: "SCANLINE_BRIGHTNESS",
                    range: 0.0...1.0,
                    step: 0.01
                ),
            ]),
                
            ShaderSettingGroup(title: "Dot Mask", key: "DOTMASK_ENABLE", [

                ShaderSetting(
                    name: "Dotmask Type",
                    key: "DOTMASK_TYPE",
                    values: [ ("Add", 0),
                              ("Blend", 1),
                              ("Shift", 2) ]
                ),

                ShaderSetting(
                    name: "Dotmask Width",
                    key: "DOTMASK_WIDTH",
                    range: 3.0...15.0,
                    step: 1.0
                ),

                ShaderSetting(
                    name: "Dotmask Weight",
                    key: "DOTMASK_WEIGHT",
                    range: 0.0...1.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Dotmask Shift",
                    key: "DOTMASK_SHIFT",
                    range: 0.0...6.3,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Dotmask Brightness",
                    key: "DOTMASK_BRIGHTNESS",
                    range: 0...1,
                    step: 0.01
                )
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

        print("key: \(key)")
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

        case "DOTMASK_ENABLE":      return Float(uniforms.DOTMASK_ENABLE)
        case "DOTMASK_TYPE":        return Float(uniforms.DOTMASK_TYPE)
        case "DOTMASK_WIDTH":       return uniforms.DOTMASK_WIDTH
        case "DOTMASK_SHIFT":       return uniforms.DOTMASK_SHIFT
        case "DOTMASK_WEIGHT":      return uniforms.DOTMASK_WEIGHT
        case "DOTMASK_BRIGHTNESS":  return uniforms.DOTMASK_BRIGHTNESS

        case "SCANLINES_ENABLE":    return Float(uniforms.SCANLINES_ENABLE)
        case "SCANLINE_DISTANCE":   return uniforms.SCANLINE_DISTANCE
        case "SCANLINE_WEIGHT":     return uniforms.SCANLINE_WEIGHT
        case "SCANLINE_BRIGHTNESS": return uniforms.SCANLINE_BRIGHTNESS
            
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

        case "DOTMASK_ENABLE":      uniforms.DOTMASK_ENABLE = Int32(value)
        case "DOTMASK_TYPE":        uniforms.DOTMASK_TYPE = Int32(value)
        case "DOTMASK_WIDTH":       uniforms.DOTMASK_WIDTH = value
        case "DOTMASK_SHIFT":       uniforms.DOTMASK_SHIFT = value
        case "DOTMASK_WEIGHT":      uniforms.DOTMASK_WEIGHT = value
        case "DOTMASK_BRIGHTNESS":  uniforms.DOTMASK_BRIGHTNESS = value

        case "SCANLINES_ENABLE":    uniforms.SCANLINES_ENABLE = Int32(value)
        case "SCANLINE_DISTANCE":   uniforms.SCANLINE_DISTANCE = value
        case "SCANLINE_WEIGHT":     uniforms.SCANLINE_WEIGHT = value
        case "SCANLINE_BRIGHTNESS": uniforms.SCANLINE_BRIGHTNESS = value

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
        dotMaskKernel = DotMaskFilter(sampler: ShaderLibrary.linear)
        crtKernel = CrtFilter(sampler: ShaderLibrary.mipmapLinear)
        chromaKernel = CompositeFilter(sampler: ShaderLibrary.linear)
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
            lin = output.makeTexture(width: inpWidth, height: inpHeight)
            ycc = output.makeTexture(width: inpWidth, height: inpHeight, mipmaps: 4)
            bri = output.makeTexture(width: inpWidth, height: inpHeight)
            blm = output.makeTexture(width: inpWidth, height: inpHeight)
            rgb = output.makeTexture(width: inpWidth, height: inpHeight)
        }

        if crt?.width != crtWidth || crt?.height != crtHeight {

            dotmask = output.makeTexture(width: inpWidth, height: inpHeight)
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
                          textures: [src, lin, ycc],
                          options: &uniforms,
                          length: MemoryLayout<Uniforms>.stride)

        pyramid.encode(commandBuffer: commandBuffer, inPlaceTexture: &ycc)

        //
        //
        // Pass 3: Apply chroma effects
        //

        /*
        let descriptor = DotMaskDescriptor(type: Int(uniforms.DOTMASK_TYPE),
                                           brightness: uniforms.DOTMASK_BRIGHTNESS,
                                           blur: 1.0)
        */
        
        /*
        dotMaskLibrary.create(commandBuffer: commandBuffer,
                              descriptor: descriptor,
                              texture: &dotmask)
        */
        dotMaskKernel.apply(commandBuffer: commandBuffer,
                            textures: [ycc, dotmask],
                            options: &uniforms,
                            length: MemoryLayout<Uniforms>.stride)
        
        chromaKernel.apply(commandBuffer: commandBuffer,
                           textures: [ycc, dotmask, rgb, bri],
                           options: &uniforms,
                           length: MemoryLayout<Uniforms>.stride)

        //
        // Pass 4: Create the bloom texture
        //

        blurFilter.blurType = uniforms.BLOOM_FILTER
        blurFilter.blurWidth = uniforms.BLOOM_RADIUS_X
        blurFilter.blurHeight = uniforms.BLOOM_RADIUS_Y
        blurFilter.apply(commandBuffer: commandBuffer, in: bri, out: blm)

        //
        // Pass 5: Emulate CRT artifacts
        //

        crtKernel.apply(commandBuffer: commandBuffer,
                        textures: [lin, dotmask, blm, output],
                        options: &uniforms,
                        length: MemoryLayout<Uniforms>.stride)

        //
        // Optional: Run the debugger
        //

        if uniforms.DEBUG_ENABLE > 0 {

            debugKernel.apply(commandBuffer: commandBuffer,
                              textures: [ycc, dotmask, blm, output],
                              options: &uniforms,
                              length: MemoryLayout<Uniforms>.stride)
        }
    }
}

extension DraculaShader {
    
    class ColorSpaceFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "dracula::colorSpace", sampler: sampler)
        }
    }

    class ShadowMaskFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "dracula::shadowMask", sampler: sampler)
        }
    }

    class DotMaskFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "dracula::dotMask", sampler: sampler)
        }
    }

    class CompositeFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "dracula::composite", sampler: sampler)
        }
    }

    class CrtFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "dracula::crt", sampler: sampler)
        }
    }

    class DebugFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "dracula::debug", sampler: sampler)
        }
    }
}
