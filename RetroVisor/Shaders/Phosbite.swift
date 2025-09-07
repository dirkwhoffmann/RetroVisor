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
final class Phosbite: Shader {
    
    struct Uniforms {

        // General
        var INPUT_TEX_SCALE: Float
        var OUTPUT_TEX_SCALE: Float
        var RESAMPLE_FILTER: Int32
        var BLUR_FILTER: Int32

        // Compposite effects
        var PAL: Int32
        var GAMMA_INPUT: Float
        var GAMMA_OUTPUT: Float
        var CONTRAST: Float
        var BRIGHTNESS: Float
        var SATURATION: Float
        var TINT: Float
        var BRIGHT_BOOST: Float
        var BRIGHT_BOOST_POST: Float
        var CHROMA_BLUR_ENABLE: Float
        var CHROMA_BLUR: Float
        
        var BLOOM_ENABLE: Int32
        var BLOOM_THRESHOLD: Float
        var BLOOM_INTENSITY: Float
        var BLOOM_RADIUS_X: Float
        var BLOOM_RADIUS_Y: Float
        
        var DOTMASK_ENABLE: Int32
        var DOTMASK_TYPE: Int32
        var DOTMASK_COLOR: Int32
        var DOTMASK_SIZE: Int32
        var DOTMASK_SATURATION: Float
        var DOTMASK_BRIGHTNESS: Float
        var DOTMASK_BLUR: Float
        var DOTMASK_GAIN: Float
        var DOTMASK_LOSS: Float
        
        var SCANLINES_ENABLE: Int32
        var SCANLINE_DISTANCE: Int32
        var SCANLINE_SHARPNESS: Float
        var SCANLINE_BLUR: Float
        var SCANLINE_BLOOM: Float
        var SCANLINE_STRENGTH: Float
        var SCANLINE_GAIN: Float
        var SCANLINE_LOSS: Float
        var SCANLINE_WEIGHT1: Float
        var SCANLINE_WEIGHT2: Float
        var SCANLINE_WEIGHT3: Float
        var SCANLINE_WEIGHT4: Float
        var SCANLINE_WEIGHT5: Float
        var SCANLINE_WEIGHT6: Float
        var SCANLINE_WEIGHT7: Float
        var SCANLINE_WEIGHT8: Float
        
        var DEBUG_ENABLE: Int32
        var DEBUG_TEXTURE1: Int32
        var DEBUG_TEXTURE2: Int32
        var DEBUG_LEFT: Int32
        var DEBUG_RIGHT: Int32
        var DEBUG_SLICE: Float
        var DEBUG_MIPMAP: Float

        static let defaults = Uniforms(
            
            INPUT_TEX_SCALE: 1.0,
            OUTPUT_TEX_SCALE: 2.0,
            RESAMPLE_FILTER: ResampleFilterType.bilinear.rawValue,
            BLUR_FILTER: BlurFilterType.box.rawValue,

            PAL: 0,
            GAMMA_INPUT: 2.2,
            GAMMA_OUTPUT: 2.2,
            CONTRAST: 0.5,
            BRIGHTNESS: 0.5,
            SATURATION: 0.5,
            TINT: 0.5,
            BRIGHT_BOOST: 1.0,
            BRIGHT_BOOST_POST: 1.0,
            CHROMA_BLUR_ENABLE: 1,
            CHROMA_BLUR: 16,
            
            BLOOM_ENABLE: 0,
            BLOOM_THRESHOLD: 0.7,
            BLOOM_INTENSITY: 1.0,
            BLOOM_RADIUS_X: 5,
            BLOOM_RADIUS_Y: 3,
            
            DOTMASK_ENABLE: 0,
            DOTMASK_TYPE: 0,
            DOTMASK_COLOR: 0,
            DOTMASK_SIZE: 5,
            DOTMASK_SATURATION: 0.5,
            DOTMASK_BRIGHTNESS: 0.5,
            DOTMASK_BLUR: 0.0,
            DOTMASK_GAIN: 1.0,
            DOTMASK_LOSS: -0.5,
            
            SCANLINES_ENABLE: 0,
            SCANLINE_DISTANCE: 6,
            SCANLINE_SHARPNESS: 1.0,
            SCANLINE_BLUR: 1.5,
            SCANLINE_BLOOM: 1.0,
            SCANLINE_STRENGTH: 1.0,
            SCANLINE_GAIN: 0.5,
            SCANLINE_LOSS: -0.5,
            SCANLINE_WEIGHT1: 0.20,
            SCANLINE_WEIGHT2: 0.36,
            SCANLINE_WEIGHT3: 0.60,
            SCANLINE_WEIGHT4: 0.68,
            SCANLINE_WEIGHT5: 0.75,
            SCANLINE_WEIGHT6: 0.80,
            SCANLINE_WEIGHT7: 1.0,
            SCANLINE_WEIGHT8: 1.0,
            
            DEBUG_ENABLE: 1,
            DEBUG_TEXTURE1: 0,
            DEBUG_TEXTURE2: 1,
            DEBUG_LEFT: 0,
            DEBUG_RIGHT: 1,
            DEBUG_SLICE: 0.5,
            DEBUG_MIPMAP: 0.0
        )
    }

    var uniforms: Uniforms = .defaults

    // Kernels
    var splitKernel: Kernel!
    var compositeKernel: Kernel!
    var dotMaskKernel: Kernel!
    var crtKernel: Kernel!
    var debugKernel: Kernel!
    
    // Textures
    var src: MTLTexture! // Downscaled input texture

    var yc0: MTLTexture! // Channel 0 of the ycc texture (for bloom effects)
    var yc1: MTLTexture! // Channel 1 of the ycc texture (for bloom effects)
    var yc2: MTLTexture! // Channel 2 of the ycc texture (for bloom effects)
    var bri: MTLTexture! // Brightness texture
    var ycc: MTLTexture! // Image in chroma/luma space

    // var com: MTLTexture! // Image in chroma/luma space with composite effects DEPRECATED
    var dom: MTLTexture! // Dot mask
    var blm: MTLTexture! // Bloom texture
    var crt: MTLTexture! // Texture with CRT effects applied
    var dbg: MTLTexture! // Copy of crt (needed by the debug kernel)
    

    var bl0: MTLTexture! // Blurred Channel 0 texture
    var bl1: MTLTexture! // Blurred Channel 1 texture
    var bl2: MTLTexture! // Blurren Channel 2 texture
    var bll1: MTLTexture! // Blurred Channel 1 texture
    var bll2: MTLTexture! // Blurren Channel 2 texture

    // Performance shader for computing mipmaps
    var pyramid: MPSImagePyramid!
    
    // Resampler used for image scaling
    var resampler = ResampleFilter()
    
    // Blur filter
    var blurFilter = BlurFilter()
        
    // Indicates whether the dot mask needs to be rebuild
    var dotMaskNeedsUpdate: Bool = true
            
    init() {
        
        super.init(name: "Phosbite")
        
        delegate = self
        
        settings = [
            
            Group(title: "General", [
                
                ShaderSetting(
                    title: "Input Texture Downscaling",
                    range: 0.125...1.0, step: 0.125,
                    value: Binding(
                        key: "INPUT_TEX_SCALE",
                        get: { [unowned self] in self.uniforms.INPUT_TEX_SCALE },
                        set: { [unowned self] in self.uniforms.INPUT_TEX_SCALE = $0 })),
                
                ShaderSetting(
                    title: "Output Texture Upscaling Factor",
                    range: 1.0...2.0, step: 0.125,
                    value: Binding(
                        key: "OUTPUT_TEX_SCALE",
                        get: { [unowned self] in self.uniforms.OUTPUT_TEX_SCALE },
                        set: { [unowned self] in self.uniforms.OUTPUT_TEX_SCALE = $0 })),
                
                ShaderSetting(
                    title: "Resampler",
                    items: [("BILINEAR", 0), ("LANCZOS", 1)],
                    value: Binding(
                        key: "RESAMPLE_FILTER",
                        get: { [unowned self] in Float(self.uniforms.RESAMPLE_FILTER) },
                        set: { [unowned self] in self.uniforms.RESAMPLE_FILTER = Int32($0) })),
                
                ShaderSetting(
                  title: "Blur Filter",
                  items: [("BOX", 0), ("TENT", 1), ("GAUSS", 2)],
                  value: Binding(
                      key: "BLUR_FILTER",
                      get: { [unowned self] in Float(self.uniforms.BLUR_FILTER) },
                      set: { [unowned self] in self.uniforms.BLUR_FILTER = Int32($0) })),

                ShaderSetting(
                    title: "Gamma Input",
                    range: 0.1...5.0, step: 0.1,
                    value: Binding(
                        key: "GAMMA_INPUT",
                        get: { [unowned self] in self.uniforms.GAMMA_INPUT },
                        set: { [unowned self] in self.uniforms.GAMMA_INPUT = $0 })),
                
                ShaderSetting(
                    title: "Gamma Output",
                    range: 0.1...5.0, step: 0.1,
                    value: Binding(
                        key: "GAMMA_OUTPUT",
                        get: { [unowned self] in self.uniforms.GAMMA_OUTPUT },
                        set: { [unowned self] in self.uniforms.GAMMA_OUTPUT = $0 })),
            ]),
            
            Group(title: "Composite Effects", [
                
                ShaderSetting(
                    title: "Video Standard",
                    items: [("PAL", 1), ("NTSC", 0)],
                    value: Binding(
                        key: "PAL",
                        get: { [unowned self] in Float(self.uniforms.PAL) },
                        set: { [unowned self] in self.uniforms.PAL = Int32($0) })),
                                
                ShaderSetting(
                    title: "Brightness",
                    range: 0.0...1.0, step: 0.01,
                    value: Binding(
                        key: "BRIGHTNESS",
                        get: { [unowned self] in self.uniforms.BRIGHTNESS },
                        set: { [unowned self] in self.uniforms.BRIGHTNESS = $0 })),

                ShaderSetting(
                    title: "Contrast",
                    range: 0.0...1.0, step: 0.01,
                    value: Binding(
                        key: "TINT",
                        get: { [unowned self] in self.uniforms.CONTRAST },
                        set: { [unowned self] in self.uniforms.CONTRAST = $0 })),

                ShaderSetting(
                    title: "Tint",
                    range: 0.0...1.0, step: 0.01,
                    value: Binding(
                        key: "TINT",
                        get: { [unowned self] in self.uniforms.TINT },
                        set: { [unowned self] in self.uniforms.TINT = $0 })),

                ShaderSetting( // DEPRECATED
                    title: "Brightness Boost",
                    range: 0.0...2.0, step: 0.01,
                    value: Binding(
                        key: "BRIGHT_BOOST",
                        get: { [unowned self] in self.uniforms.BRIGHT_BOOST },
                        set: { [unowned self] in self.uniforms.BRIGHT_BOOST = $0 }),
                ),

                ShaderSetting( // DEPRECATED
                    title: "Brightness Boost (post)",
                    range: 0.0...2.0, step: 0.01,
                    value: Binding(
                        key: "BRIGHT_BOOST_POST",
                        get: { [unowned self] in self.uniforms.BRIGHT_BOOST_POST },
                        set: { [unowned self] in self.uniforms.BRIGHT_BOOST_POST = $0 }),
                ),
                
                ShaderSetting(
                    title: "Chroma Blur",
                    range: 1...32, step: 1,
                    enable: Binding(
                        key: "CHROMA_BLUR_ENABLE",
                        get: { [unowned self] in self.uniforms.CHROMA_BLUR_ENABLE },
                        set: { [unowned self] in self.uniforms.CHROMA_BLUR_ENABLE = $0 }),
                    value: Binding(
                        key: "CHROMA_BLUR",
                        get: { [unowned self] in self.uniforms.CHROMA_BLUR },
                        set: { [unowned self] in self.uniforms.CHROMA_BLUR = $0 })),
            ]),
            
            Group(title: "Blooming",
                  
                  enable: Binding(
                    key: "BLOOM_ENABLE",
                    get: { [unowned self] in Float(self.uniforms.BLOOM_ENABLE) },
                    set: { [unowned self] in self.uniforms.BLOOM_ENABLE = Int32($0) }),
                  
                  [ ShaderSetting(
                        title: "Bloom Threshold",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "BLOOM_THRESHOLD",
                            get: { [unowned self] in self.uniforms.BLOOM_THRESHOLD },
                            set: { [unowned self] in self.uniforms.BLOOM_THRESHOLD = $0 })),

                    ShaderSetting(
                        title: "Bloom Intensity",
                        range: 0.1...2.0, step: 0.01,
                        value: Binding(
                            key: "BLOOM_INTENSITY",
                            get: { [unowned self] in self.uniforms.BLOOM_INTENSITY },
                            set: { [unowned self] in self.uniforms.BLOOM_INTENSITY = $0 })),

                    ShaderSetting(
                        title: "Bloom Radius X",
                        range: 0.0...30.0, step: 1.0,
                        value: Binding(
                            key: "BLOOM_RADIUS_X",
                            get: { [unowned self] in self.uniforms.BLOOM_RADIUS_X },
                            set: { [unowned self] in self.uniforms.BLOOM_RADIUS_X = $0 })),
                    
                    ShaderSetting(
                        title: "Bloom Radius Y",
                        range: 0.0...30.0, step: 1.0,
                        value: Binding(
                            key: "BLOOM_RADIUS_Y",
                            get: { [unowned self] in self.uniforms.BLOOM_RADIUS_Y },
                            set: { [unowned self] in self.uniforms.BLOOM_RADIUS_Y = $0 })),
                  ]),
            
            Group(title: "Scanlines",
                  
                  enable: Binding(
                    key: "SCANLINES_ENABLE",
                    get: { [unowned self] in Float(self.uniforms.SCANLINES_ENABLE) },
                    set: { [unowned self] in self.uniforms.SCANLINES_ENABLE = Int32($0) }),
                  
                  [ ShaderSetting(
                    title: "Scanline Distance",
                    range: 1...8, step: 1,
                    value: Binding(
                        key: "SCANLINE_DISTANCE",
                        get: { [unowned self] in Float(self.uniforms.SCANLINE_DISTANCE) },
                        set: { [unowned self] in self.uniforms.SCANLINE_DISTANCE = Int32($0) })),
                    
                    ShaderSetting(
                        title: "Scanline Strength",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_STRENGTH",
                            get: { [unowned self] in self.uniforms.SCANLINE_STRENGTH },
                            set: { [unowned self] in self.uniforms.SCANLINE_STRENGTH = $0 })),

                    ShaderSetting(
                        title: "Scanline Sharpness",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_SHARPNESS",
                            get: { [unowned self] in self.uniforms.SCANLINE_SHARPNESS },
                            set: { [unowned self] in self.uniforms.SCANLINE_SHARPNESS = $0 })),

                    ShaderSetting(
                        title: "Scanline Blur",
                        range: 0...4.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_BLUR",
                            get: { [unowned self] in self.uniforms.SCANLINE_BLUR },
                            set: { [unowned self] in self.uniforms.SCANLINE_BLUR = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Bloom",
                        range: 0...1, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_BLOOM",
                            get: { [unowned self] in self.uniforms.SCANLINE_BLOOM },
                            set: { [unowned self] in self.uniforms.SCANLINE_BLOOM = $0 })),

                    ShaderSetting(
                        title: "Scanline Gain",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_GAIN",
                            get: { [unowned self] in self.uniforms.SCANLINE_GAIN },
                            set: { [unowned self] in self.uniforms.SCANLINE_GAIN = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Loss",
                        range: -1.0...0.0, step: 0.01,
                        value: Binding(
                            key: "DOTMASK_LOSS",
                            get: { [unowned self] in self.uniforms.SCANLINE_LOSS },
                            set: { [unowned self] in self.uniforms.SCANLINE_LOSS = $0 })),

                    ShaderSetting(
                        title: "Scanline Weight 1",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_WEIGHT1",
                            get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT1 },
                            set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT1 = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Weight 2",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_WEIGHT2",
                            get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT2 },
                            set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT2 = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Weight 3",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_WEIGHT3",
                            get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT3 },
                            set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT3 = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Weight 4",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_WEIGHT4",
                            get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT4 },
                            set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT4 = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Weight 5",
                        range: 0.1...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_WEIGHT5",
                            get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT5 },
                            set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT5 = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Weight 6",
                        range: 0.1...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_WEIGHT6",
                            get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT6 },
                            set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT6 = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Weight 7",
                        range: 0.1...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_WEIGHT7",
                            get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT7 },
                            set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT7 = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Weight 8",
                        range: 0.1...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_WEIGHT8",
                            get: { [unowned self] in self.uniforms.SCANLINE_WEIGHT8 },
                            set: { [unowned self] in self.uniforms.SCANLINE_WEIGHT8 = $0 })),
                  ]),
            
            Group(title: "Dot Mask",
                  
                  enable: Binding(
                    key: "DOTMASK_ENABLE",
                    get: { [unowned self] in Float(self.uniforms.DOTMASK_ENABLE) },
                    set: { [unowned self] in self.uniforms.DOTMASK_ENABLE = Int32($0) }),
                  
                  [ ShaderSetting(
                    title: "Dotmask Type",
                    items: [ ("Aperture Grille", 0), ("Shadow Mask", 1), ("Slot Mask", 2) ],
                    value: Binding(
                        key: "DOTMASK_TYPE",
                        get: { [unowned self] in Float(self.uniforms.DOTMASK_TYPE) },
                        set: { [unowned self] in self.uniforms.DOTMASK_TYPE = Int32($0) })),

                    ShaderSetting(
                      title: "Dotmask Color",
                      items: [ ("GM", 0), ("RGB", 1) ],
                      value: Binding(
                          key: "DOTMASK_COLOR",
                          get: { [unowned self] in Float(self.uniforms.DOTMASK_COLOR) },
                          set: { [unowned self] in self.uniforms.DOTMASK_COLOR = Int32($0) })),

                    ShaderSetting(
                        title: "Dotmask Size",
                        range: 1.0...16.0, step: 1.0,
                        value: Binding(
                            key: "DOTMASK_SIZE",
                            get: { [unowned self] in Float(self.uniforms.DOTMASK_SIZE) },
                            set: { [unowned self] in self.uniforms.DOTMASK_SIZE = Int32($0) })),
                    
                    ShaderSetting(
                        title: "Dotmask Saturation",
                        range: 0...1, step: 0.01,
                        value: Binding(
                            key: "DOTMASK_SATURATION",
                            get: { [unowned self] in self.uniforms.DOTMASK_SATURATION },
                            set: { [unowned self] in self.uniforms.DOTMASK_SATURATION = $0 })),

                    ShaderSetting(
                        title: "Dotmask Brightness",
                        range: 0...1, step: 0.01,
                        value: Binding(
                            key: "DOTMASK_BRIGHTNESS",
                            get: { [unowned self] in self.uniforms.DOTMASK_BRIGHTNESS },
                            set: { [unowned self] in self.uniforms.DOTMASK_BRIGHTNESS = $0 })),
                    
                    ShaderSetting(
                        title: "Dotmask Blur",
                        range: 0...4, step: 0.01,
                        value: Binding(
                            key: "DOTMASK_BLUR",
                            get: { [unowned self] in self.uniforms.DOTMASK_BLUR },
                            set: { [unowned self] in self.uniforms.DOTMASK_BLUR = $0 })),
                                        
                    ShaderSetting(
                        title: "Dotmask Gain",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "DOTMASK_GAIN",
                            get: { [unowned self] in self.uniforms.DOTMASK_GAIN },
                            set: { [unowned self] in self.uniforms.DOTMASK_GAIN = $0 })),
                    
                    ShaderSetting(
                        title: "Dotmask Loss",
                        range: -1.0...0.0, step: 0.01,
                        value: Binding(
                            key: "DOTMASK_LOSS",
                            get: { [unowned self] in self.uniforms.DOTMASK_LOSS },
                            set: { [unowned self] in self.uniforms.DOTMASK_LOSS = $0 })),
                  ]),
            
            Group(title: "Debugging",
                  
                  enable: Binding(
                    key: "DEBUG_ENABLE",
                    get: { [unowned self] in Float(self.uniforms.DEBUG_ENABLE) },
                    set: { [unowned self] in self.uniforms.DEBUG_ENABLE = Int32($0) }),
                  
                  [ ShaderSetting(
                    title: "Texture 1",
                    items: [ ("Source", 0),
                             ("Final", 1),
                             ("", 0),
                             ("ycc", 2),
                             ("ycc (Y)", 3),
                             ("ycc (C1)", 4),
                             ("ycc (C2)", 5),
                             ("Bloom (Y)", 6),
                             ("Bloom (C1)", 7),
                             ("Bloom (C2)", 8),
                             ("Dotmask", 9) ],
                    value: Binding(
                        key: "DEBUG_TEXTURE1",
                        get: { [unowned self] in Float(self.uniforms.DEBUG_TEXTURE1) },
                        set: { [unowned self] in self.uniforms.DEBUG_TEXTURE1 = Int32($0) })),
                    
                    ShaderSetting(
                      title: "Texture 2",
                      items: [ ("Source", 0),
                               ("Final", 1),
                               ("", 0),
                               ("ycc", 2),
                               ("ycc (Y)", 3),
                               ("ycc (C1)", 4),
                               ("ycc (C2)", 5),
                               ("Bloom (Y)", 6),
                               ("Bloom (C1)", 7),
                               ("Bloom (C2)", 8),
                               ("Dotmask", 9) ],
                      value: Binding(
                          key: "DEBUG_TEXTURE2",
                          get: { [unowned self] in Float(self.uniforms.DEBUG_TEXTURE2) },
                          set: { [unowned self] in self.uniforms.DEBUG_TEXTURE2 = Int32($0) })),
                    
                    ShaderSetting(
                      title: "Left View",
                      items: [ ("Texture 1", 0),
                               ("Texture 2", 1),
                               ("Diff", 2) ],
                      value: Binding(
                          key: "DEBUG_LEFT",
                          get: { [unowned self] in Float(self.uniforms.DEBUG_LEFT) },
                          set: { [unowned self] in self.uniforms.DEBUG_LEFT = Int32($0) })),

                    ShaderSetting(
                      title: "Right View",
                      items: [ ("Texture 1", 0),
                               ("Texture 2", 1),
                               ("Diff", 2) ],
                      value: Binding(
                          key: "DEBUG_RIGHT",
                          get: { [unowned self] in Float(self.uniforms.DEBUG_RIGHT) },
                          set: { [unowned self] in self.uniforms.DEBUG_RIGHT = Int32($0) })),

                    ShaderSetting(
                        title: "Area Slider",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "DEBUG_SLICE",
                            get: { [unowned self] in self.uniforms.DEBUG_SLICE },
                            set: { [unowned self] in self.uniforms.DEBUG_SLICE = $0 })),
                    
                    ShaderSetting(
                        title: "Mipmap level",
                        range: 0.0...4.0, step: 0.01,
                        value: Binding(
                            key: "DEBUG_MIPMAP",
                            get: { [unowned self] in self.uniforms.DEBUG_MIPMAP },
                            set: { [unowned self] in self.uniforms.DEBUG_MIPMAP = $0 }))
                  ]),
        ]
    }
    
    override func activate() {
        
        super.activate()
        splitKernel = SplitFilter(sampler: ShaderLibrary.linear)
        compositeKernel = CompositeFilter(sampler: ShaderLibrary.linear)
        dotMaskKernel = DotMaskFilter(sampler: ShaderLibrary.mipmapLinear)
        crtKernel = CrtFilter(sampler: ShaderLibrary.mipmapLinear)
        debugKernel = DebugFilter(sampler: ShaderLibrary.mipmapLinear)
        pyramid = MPSImageGaussianPyramid(device: ShaderLibrary.device)
    }
    
    func updateTextures(commandBuffer: MTLCommandBuffer, in input: MTLTexture, out output: MTLTexture) {
        
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
            yc0 = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            yc1 = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            yc2 = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            bri = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            bl0 = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            bl1 = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            bl2 = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            bll1 = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            bll2 = output.makeTexture(width: inpWidth, height: inpHeight, pixelFormat: .r8Unorm)
            blm = output.makeTexture(width: inpWidth, height: inpHeight)
            // com = output.makeTexture(width: inpWidth, height: inpHeight, mipmaps: 4)
        }
        
        if crt?.width != crtWidth || crt?.height != crtHeight {
            
            dom = output.makeTexture(width: crtWidth, height: crtHeight, mipmaps: 4)
            crt = output.makeTexture(width: crtWidth, height: crtHeight)
        }

        if (uniforms.DEBUG_ENABLE != 0 && dbg?.width != crtWidth || dbg?.height != crtHeight) {

            dbg = output.makeTexture(width: crtWidth, height: crtHeight)
        }
        
        if dotMaskNeedsUpdate {
            
            updateDotMask(commandBuffer: commandBuffer)
            dotMaskNeedsUpdate = false
        }
    }
    
    func updateDotMask(commandBuffer: MTLCommandBuffer) {
                
        let s = Double(uniforms.DOTMASK_SATURATION)
        let b = Double(uniforms.DOTMASK_BRIGHTNESS)
                
        let R = UInt32(color: NSColor(hue: 0.0, saturation: s, brightness: 1.0, alpha: 1.0))
        let G = UInt32(color: NSColor(hue: 0.333, saturation: s, brightness: 1.0, alpha: 1.0))
        let B = UInt32(color: NSColor(hue: 0.666, saturation: s, brightness: 1.0, alpha: 1.0))
        let M = UInt32(color: NSColor(hue: 0.833, saturation: s, brightness: 1.0, alpha: 1.0))
        let N = UInt32(color: NSColor(red: b, green: b, blue: b, alpha: 1.0))
        
        let maskData = [
            [ apertureGrille(M, G, N), apertureGrille(R, G, B, N) ],
            [ slotMask      (M, G, N),       slotMask(R, G, B, N) ],
            [ shadowMask    (M, G, N),     shadowMask(R, G, B, N) ]
        ]
        
        // Convert dot mask pattern to texture
        let tex = dom.make(data: maskData[Int(uniforms.DOTMASK_TYPE)][Int(uniforms.DOTMASK_COLOR)])!
        
        // Create the dot mask texture
        dotMaskKernel.apply(commandBuffer: commandBuffer,
                            source: tex, target: dom,
                            options: &uniforms,
                            length: MemoryLayout<Uniforms>.stride)
        
        pyramid.encode(commandBuffer: commandBuffer, inPlaceTexture: &dom)
    }
    
    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {
        
        updateTextures(commandBuffer: commandBuffer, in: input, out: output)
        
        //
        // Pass 1: Crop and downsample the RGB input image
        //
        
        resampler.type = ResampleFilterType(rawValue: uniforms.RESAMPLE_FILTER)!
        resampler.apply(commandBuffer: commandBuffer, in: input, out: src, rect: rect)
        
        //
        // Pass 2: Convert the input image into YUV/YIQ space
        //
        
        splitKernel.apply(commandBuffer: commandBuffer,
                          textures:  [src, ycc, yc0, yc1, yc2, bri],
                          options: &uniforms,
                          length: MemoryLayout<Uniforms>.stride)
                
        //
        // Pass 3: Create the blur and bloom textures
        //
        
        if uniforms.BLOOM_ENABLE == 1 {
            
            blurFilter.blurType = BlurFilterType(rawValue: uniforms.BLUR_FILTER)!
            blurFilter.blurWidth = uniforms.BLOOM_RADIUS_X
            blurFilter.blurHeight = uniforms.BLOOM_RADIUS_Y
            blurFilter.apply(commandBuffer: commandBuffer, in: bri, out: bl0)
        }

        if uniforms.CHROMA_BLUR_ENABLE == 1 {
            
            let kernelWidth = Int(uniforms.CHROMA_BLUR) | 1
            let kernelHeight = 3
            let values = [Float](repeating: 0, count: kernelWidth * kernelHeight)
            
            let dilate = MPSImageDilate(device: ShaderLibrary.device,
                                        kernelWidth: kernelWidth, kernelHeight: kernelHeight, values: values)
            dilate.encode(commandBuffer: commandBuffer, sourceTexture: yc1, destinationTexture: bll1)
            dilate.encode(commandBuffer: commandBuffer, sourceTexture: yc2, destinationTexture: bll2)
            
            blurFilter.blurWidth = uniforms.CHROMA_BLUR / 2.0
            blurFilter.blurHeight = 2.0
            blurFilter.apply(commandBuffer: commandBuffer, in: bll1, out: bl1)
            blurFilter.apply(commandBuffer: commandBuffer, in: bll2, out: bl2)
            
            compositeKernel.apply(commandBuffer: commandBuffer, textures: [yc0, bl1, bl2, ycc])
        }
        
        pyramid.encode(commandBuffer: commandBuffer, inPlaceTexture: &ycc)

        //
        // Pass 4: Emulate CRT artifacts
        //
        
        crtKernel.apply(commandBuffer: commandBuffer,
                        textures: [ycc, bl0, bl1, bl2, dom, uniforms.DEBUG_ENABLE == 1 ? dbg : crt],
                        options: &uniforms,
                        length: MemoryLayout<Uniforms>.stride)

        //
        // Pass 5 (optional): Mix in debug textures
        //

        if uniforms.DEBUG_ENABLE == 1 {
            
            debugKernel.apply(commandBuffer: commandBuffer,
                              textures: [src, dbg, ycc, yc0, yc1, yc2, bl0, bl1, bl2, dom, output],
                              options: &uniforms,
                              length: MemoryLayout<Uniforms>.stride)
        } else {
            
            resampler.apply(commandBuffer: commandBuffer, in: crt, out: output)
        }
    }
}

extension Phosbite: ShaderDelegate {
    
    func settingDidChange(setting: ShaderSetting) {
                
        if setting.valueKey  == "OUTPUT_TEX_SCALE" || setting.valueKey .starts(with: "DOTMASK") {
            
            dotMaskNeedsUpdate = true
        }
    }
}

//
// Kernels
//

extension Phosbite {
    
    class SplitFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "phosbite::split", sampler: sampler)
        }
    }
    
    class CompositeFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "phosbite::composite", sampler: sampler)
        }
    }

    class DotMaskFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "phosbite::dotMask", sampler: sampler)
        }
    }
    
    class CrtFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "phosbite::crt", sampler: sampler)
        }
    }
    
    class DebugFilter: Kernel {
        convenience init?(sampler: MTLSamplerState) {
            self.init(name: "phosbite::debug", sampler: sampler)
        }
    }
}

//
// Dot mask patterns
//

extension Phosbite {
    
    func apertureGrille(_ M: UInt32, _ G: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ M, G, N ],
          [ M, G, N ] ]
    }
    
    func apertureGrille(_ R: UInt32, _ G: UInt32, _ B: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ R, G, B, N ],
          [ R, G, B, N ],
          [ R, G, B, N ],
          [ R, G, B, N ] ]
    }
    
    func shadowMask(_ M: UInt32, _ G: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ M, G, N ],
          [ M, G, N ],
          [ N, N, N ],
          [ N, M, G ],
          [ N, M, G ],
          [ N, N, N ],
          [ G, N, M ],
          [ G, N, M ],
          [ N, N, N ] ]
    }
    
    func shadowMask(_ R: UInt32, _ G: UInt32, _ B: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ R, G, B, N ],
          [ R, G, B, N ],
          [ R, G, B, N ],
          [ N, N, N, N ],
          [ B, N, R, G ],
          [ B, N, R, G ],
          [ B, N, R, G ],
          [ N, N, N, N ] ]
    }
    
    func slotMask(_ M: UInt32, _ G: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ M, G, N, M, G, N ],
          [ M, G, N, N, N, N ],
          [ M, G, N, M, G, N ],
          [ N, N, N, M, G, N ] ]
    }
    
    func slotMask(_ R: UInt32, _ G: UInt32, _ B: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ R, G, B, N, R, G, B, N ],
          [ R, G, B, N, R, G, B, N ],
          [ R, G, B, N, N, N, N, N ],
          [ R, G, B, N, R, G, B, N ],
          [ R, G, B, N, R, G, B, N ],
          [ N, N, N, N, R, G, B, N ] ]
    }
}
