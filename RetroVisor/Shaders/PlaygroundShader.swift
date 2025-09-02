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
    var RESAMPLE_FILTER: Int32
    
    var PAL: Int32
    var GAMMA_INPUT: Float
    var GAMMA_OUTPUT: Float
    var CHROMA_RADIUS: Float

    var BLOOM_ENABLE: Int32
    var BLOOM_FILTER: Int32
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
    var SCANLINE_WEIGHT5: Float
    var SCANLINE_WEIGHT6: Float
    var SCANLINE_WEIGHT7: Float
    var SCANLINE_WEIGHT8: Float

    var SHADOW_ENABLE: Int32
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
        RESAMPLE_FILTER: ResampleFilterType.bilinear.rawValue,

        PAL: 0,
        GAMMA_INPUT: 2.2,
        GAMMA_OUTPUT: 2.2,
        CHROMA_RADIUS: 1.3,

        BLOOM_ENABLE: 0,
        BLOOM_FILTER: BlurFilterType.box.rawValue,
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
        SCANLINE_WEIGHT5: 0.5,
        SCANLINE_WEIGHT6: 0.5,
        SCANLINE_WEIGHT7: 0.5,
        SCANLINE_WEIGHT8: 0.5,

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

            Group(title: "Textures", [
                
                ShaderSetting(
                    name: "Input Downscaling Factor",
                    range: 0.125...1.0, step: 0.125,
                    value: Binding(
                        key: "INPUT_TEX_SCALE",
                        get: { [unowned self] in self.uniforms.INPUT_TEX_SCALE },
                        set: { [unowned self] in self.uniforms.INPUT_TEX_SCALE = $0 }),
                ),
                
                ShaderSetting(
                    name: "Output Upscaling Factor",
                    range: 1.0...2.0, step: 0.125,
                    value: Binding(
                        key: "OUTPUT_TEX_SCALE",
                        get: { [unowned self] in self.uniforms.OUTPUT_TEX_SCALE },
                        set: { [unowned self] in self.uniforms.OUTPUT_TEX_SCALE = $0 }),
                ),
                
                ShaderSetting(
                    name: "Resampler",
                    items: [("BILINEAR", 0), ("LANCZOS", 1)],
                    value: Binding(
                        key: "RESAMPLE_FILTER",
                        get: { [unowned self] in Float(self.uniforms.RESAMPLE_FILTER) },
                        set: { [unowned self] in self.uniforms.RESAMPLE_FILTER = Int32($0) }),
                ),
            ]),

            Group(title: "Chroma Effects", [

                ShaderSetting(
                    name: "Video Standard",
                    items: [("PAL", 1), ("NTSC", 0)],
                    value: Binding(
                        key: "PAL",
                        get: { [unowned self] in Float(self.uniforms.PAL) },
                        set: { [unowned self] in self.uniforms.PAL = Int32($0) }),
                ),

                ShaderSetting(
                    name: "Gamma Input",
                    range: 0.1...5.0, step: 0.1,
                    value: Binding(
                        key: "GAMMA_INPUT",
                    get: { [unowned self] in self.uniforms.GAMMA_INPUT },
                    set: { [unowned self] in self.uniforms.GAMMA_INPUT = $0 }),
                ),

                ShaderSetting(
                    name: "Gamma Output",
                    range: 0.1...5.0, step: 0.1,
                    value: Binding(
                        key: "GAMMA_OUTPUT",
                    get: { [unowned self] in self.uniforms.GAMMA_OUTPUT },
                    set: { [unowned self] in self.uniforms.GAMMA_OUTPUT = $0 }),
                ),

                ShaderSetting(
                    name: "Chroma Radius",
                    range: 1...10, step: 1,
                    value: Binding(
                        key: "CHROMA_RADIUS",
                    get: { [unowned self] in self.uniforms.CHROMA_RADIUS },
                    set: { [unowned self] in self.uniforms.CHROMA_RADIUS = $0 }),
                ),
            ]),

            Group(title: "Blooming", enable: Binding(
                
                key: "BLOOM_ENABLE",
                get: { [unowned self] in Float(self.uniforms.BLOOM_ENABLE) },
                set: { [unowned self] in self.uniforms.BLOOM_ENABLE = Int32($0) }), [
                    
                ShaderSetting(
                    name: "Bloom Filter",
                    items: [("BOX", 0), ("TENT", 1), ("GAUSS", 2), ("MEDIAN", 3)],
                    value: Binding(
                        key: "BLOOM_FILTER",
                    get: { [unowned self] in Float(self.uniforms.BLOOM_FILTER) },
                    set: { [unowned self] in self.uniforms.BLOOM_FILTER = Int32($0) }),
                ),

                ShaderSetting(
                    name: "Bloom Threshold",
                    range: 0.0...1.0, step: 0.01,
                    value: Binding(
                        key: "BLOOM_THRESHOLD",
                    get: { [unowned self] in self.uniforms.BLOOM_THRESHOLD },
                    set: { [unowned self] in self.uniforms.BLOOM_THRESHOLD = $0 }),
                ),

                ShaderSetting(
                    name: "Bloom Intensity",
                    range: 0.1...2.0, step: 0.01,
                    value: Binding(
                        key: "BLOOM_INTENSITY",
                    get: { [unowned self] in self.uniforms.BLOOM_INTENSITY },
                    set: { [unowned self] in self.uniforms.BLOOM_INTENSITY = $0 }),
                ),

                ShaderSetting(
                    name: "Bloom Radius X",
                    range: 0.0...30.0, step: 1.0,
                    value: Binding(
                        key: "BLOOM_RADIUS_X",
                    get: { [unowned self] in self.uniforms.BLOOM_RADIUS_X },
                    set: { [unowned self] in self.uniforms.BLOOM_RADIUS_X = $0 }),
                ),

                ShaderSetting(
                    name: "Bloom Radius Y",
                    range: 0.0...30.0, step: 1.0,
                    value: Binding(
                        key: "BLOOM_RADIUS_Y",
                    get: { [unowned self] in self.uniforms.BLOOM_RADIUS_Y },
                    set: { [unowned self] in self.uniforms.BLOOM_RADIUS_Y = $0 }),
                ),

            ]),

            Group(title: "Scanlines", enable: Binding(
                
                key: "SCANLINE_ENABLE",
                get: { [unowned self] in Float(self.uniforms.SCANLINE_ENABLE) },
                set: { [unowned self] in self.uniforms.SCANLINE_ENABLE = Int32($0) }), [
                                    
                ShaderSetting(
                    name: "Scanline Brightness",
                    range: 0.0...2.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_BRIGHTNESS",
                        get: { [unowned self] in self.uniforms.SCANLINE_BRIGHTNESS },
                        set: { [unowned self] in self.uniforms.SCANLINE_BRIGHTNESS = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Weight 1",
                    range: 0.1...1.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_WEIGHT1",
                        get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT1 },
                        set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT1 = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Weight 2",
                    range: 0.1...1.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_WEIGHT2",
                        get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT2 },
                        set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT2 = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Weight 3",
                    range: 0.1...1.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_WEIGHT3",
                        get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT3 },
                        set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT3 = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Weight 4",
                    range: 0.1...1.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_WEIGHT4",
                        get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT4 },
                        set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT4 = $0 }),
                ),

                ShaderSetting(
                    name: "Scanline Weight 5",
                    range: 0.1...1.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_WEIGHT5",
                        get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT5 },
                        set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT5 = $0 }),
                ),

                ShaderSetting(
                    name: "Scanline Weight 6",
                    range: 0.1...1.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_WEIGHT6",
                        get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT6 },
                        set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT6 = $0 }),
                ),

                ShaderSetting(
                    name: "Scanline Weight 7",
                    range: 0.1...1.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_WEIGHT7",
                        get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT7 },
                        set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT7 = $0 }),
                ),

                ShaderSetting(
                    name: "Scanline Weight 8",
                    range: 0.1...1.0, step: 0.01,
                    value: Binding(
                        key: "SCANLINE_WEIGHT8",
                        get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT8 },
                        set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT8 = $0 }),
                ),
            ]),
            
            Group(title: "Shadow Mask", enable: Binding(
                
                key: "SHADOW_ENABLE",
                get: { [unowned self] in Float(self.uniforms.SHADOW_ENABLE) },
                set: { [unowned self] in self.uniforms.SHADOW_ENABLE = Int32($0) }), [
                                    
                ShaderSetting(
                    name: "Grid Width",
                    range: 1.0...60.0, step: 1.0,
                    value: Binding(
                        key: "SHADOW_GRID_WIDTH",
                        get: { [unowned self] in self.uniforms.SHADOW_GRID_WIDTH },
                        set: { [unowned self] in self.uniforms.SHADOW_GRID_WIDTH = $0 }),
                ),
                
                ShaderSetting(
                    name: "Grid Height",
                    range: 1.0...60.0, step: 1.0,
                    value: Binding(
                        key: "SHADOW_GRID_HEIGHT",
                        get: { [unowned self] in self.uniforms.SHADOW_GRID_HEIGHT },
                        set: { [unowned self] in self.uniforms.SHADOW_GRID_HEIGHT = $0 }),
                ),
                
                ShaderSetting(
                    name: "Maximal Dot Width",
                    range: 0.0...1.0, step: 0.01,
                    value: Binding(
                        key: "SHADOW_DOT_WIDTH",
                        get: { [unowned self] in self.uniforms.SHADOW_DOT_WIDTH },
                        set: { [unowned self] in self.uniforms.SHADOW_DOT_WIDTH = $0 }),
                ),
                
                ShaderSetting(
                    name: "Maximal Dot Height",
                    range: 0.0...1.0, step: 0.01,
                    value: Binding(
                        key: "SHADOW_DOT_HEIGHT",
                        get: { [unowned self] in self.uniforms.SHADOW_DOT_HEIGHT },
                        set: { [unowned self] in self.uniforms.SHADOW_DOT_HEIGHT = $0 }),
                ),
                
                ShaderSetting(
                    name: "Weight",
                    range: 0.0...2.0, step: 0.01,
                    value: Binding(
                        key: "SHADOW_DOT_WEIGHT",
                        get: { [unowned self] in self.uniforms.SHADOW_DOT_WEIGHT },
                        set: { [unowned self] in self.uniforms.SHADOW_DOT_WEIGHT = $0 }),
                ),
                
                ShaderSetting(
                    name: "Glow",
                    range: 0.05...5.0, step: 0.01,
                    value: Binding(
                        key: "SHADOW_DOT_GLOW",
                        get: { [unowned self] in self.uniforms.SHADOW_DOT_GLOW },
                        set: { [unowned self] in self.uniforms.SHADOW_DOT_GLOW = $0 }),
                ),
                
                ShaderSetting(
                    name: "Phosphor Feather",
                    range: 0.0...3.0, step: 0.01,
                    value: Binding(
                        key: "SHADOW_FEATHER",
                        get: { [unowned self] in self.uniforms.SHADOW_FEATHER },
                        set: { [unowned self] in self.uniforms.SHADOW_FEATHER = $0 }),
                )
            ]),
            
            Group(title: "Dot Mask", enable: Binding(
                
                key: "DOTMASK_ENABLE",
                get: { [unowned self] in Float(self.uniforms.DOTMASK_ENABLE) },
                set: { [unowned self] in self.uniforms.DOTMASK_ENABLE = Int32($0) }), [
                                    
                ShaderSetting(
                    name: "Dotmask",
                    range: 0...4, step: 1.0,
                    value: Binding(
                        key: "DOTMASK",
                        get: { [unowned self] in Float(self.uniforms.DOTMASK) },
                        set: { [unowned self] in self.uniforms.DOTMASK = Int32($0) }),
                ),
                
                ShaderSetting(
                    name: "Dotmask Brightness",
                    range: 0...1, step: 0.01,
                    value: Binding(
                        key: "DOTMASK_BRIGHTNESS",
                        get: { [unowned self] in self.uniforms.DOTMASK_BRIGHTNESS },
                        set: { [unowned self] in self.uniforms.DOTMASK_BRIGHTNESS = $0 }),
                ),
                
                ShaderSetting(
                    name: "Brightness",
                    range: 0.0...10.0, step: 0.01,
                    value: Binding(
                        key: "BRIGHTNESS",
                        get: { [unowned self] in self.uniforms.BRIGHTNESS },
                        set: { [unowned self] in self.uniforms.BRIGHTNESS = $0 }),
                ),
                
                ShaderSetting(
                    name: "Glow",
                    range: 0.0...2.0, step: 0.01,
                    value: Binding(
                        key: "GLOW",
                        get: { [unowned self] in self.uniforms.GLOW },
                        set: { [unowned self] in self.uniforms.GLOW = $0 }),
                ),
            ]),
            
            Group(title: "Debugging", enable: Binding(
                
                key: "DEBUG_ENABLE",
                get: { [unowned self] in Float(self.uniforms.DEBUG_ENABLE) },
                set: { [unowned self] in self.uniforms.DEBUG_ENABLE = Int32($0) }), [
                                    
                ShaderSetting(
                    name: "Debug",
                    items: [ ("Ycc", 1),
                             ("Ycc (Mipmap 1)", 2),
                             ("Ycc (Mipmap 2)", 3),
                             ("Ycc (Mipmap 3)", 4),
                             ("Ycc (Mipmap 4)", 5),
                             ("Luma", 6),
                             ("Chroma U/I", 7),
                             ("Chroma V/Q", 8),
                             ("Shadow texture", 9),
                             ("Bloom texture", 10) ],
                    value: Binding(
                        key: "DEBUG_TEXTURE",
                        get: { [unowned self] in Float(self.uniforms.DEBUG_TEXTURE) },
                        set: { [unowned self] in self.uniforms.DEBUG_TEXTURE = Int32($0) }),
                ),
                
                ShaderSetting(
                    name: "Debug Slider",
                    range: 0.0...1.0, step: 0.01,
                    value: Binding(
                        key: "DEBUG_SLIDER",
                        get: { [unowned self] in self.uniforms.DEBUG_SLIDER },
                        set: { [unowned self] in self.uniforms.DEBUG_SLIDER = $0 }),
                )
            ]),
        ]
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

        resampler.type = ResampleFilterType(rawValue: uniforms.RESAMPLE_FILTER)!
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
        blurFilter.blurType = BlurFilterType(rawValue: uniforms.BLOOM_FILTER)!
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
