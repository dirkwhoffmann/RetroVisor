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
        
        var DOTMASK_ENABLE: Int32
        var DOTMASK_TYPE: Int32
        var DOTMASK_COLOR: Int32
        var DOTMASK_WIDTH: Int32
        var DOTMASK_HEIGHT: Int32
        var DOTMASK_SATURATION: Float
        var DOTMASK_BRIGHTNESS: Float
        var DOTMASK_BLUR: Float
        var DOTMASK_GAIN: Float
        var DOTMASK_LOOSE: Float
        
        var SCANLINES_ENABLE: Int32
        var SCANLINE_DISTANCE: Float
        var SCANLINE_SHARPNESS: Float
        var SCANLINE_BLOOM: Float
        var SCANLINE_WEIGHT1: Float
        var SCANLINE_WEIGHT2: Float
        var SCANLINE_WEIGHT3: Float
        var SCANLINE_WEIGHT4: Float
        var SCANLINE_WEIGHT5: Float
        var SCANLINE_WEIGHT6: Float
        var SCANLINE_WEIGHT7: Float
        var SCANLINE_WEIGHT8: Float
        var SCANLINE_BRIGHTNESS: Float
        
        var DEBUG_ENABLE: Int32
        var DEBUG_TEXTURE: Int32
        var DEBUG_ANCHOR: Int32
        var DEBUG_SLICE: Float
        
        static let defaults = Uniforms(
            
            INPUT_TEX_SCALE: 1.0,
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
            
            DOTMASK_ENABLE: 1,
            DOTMASK_TYPE: 0,
            DOTMASK_COLOR: 0,
            DOTMASK_WIDTH: 5,
            DOTMASK_HEIGHT: 5,
            DOTMASK_SATURATION: 0.5,
            DOTMASK_BRIGHTNESS: 1.0,
            DOTMASK_BLUR: 0.0,
            DOTMASK_GAIN: 1.0,
            DOTMASK_LOOSE: 0.5,
            
            SCANLINES_ENABLE: 1,
            SCANLINE_DISTANCE: 8.0,
            SCANLINE_SHARPNESS: 1.77,
            SCANLINE_BLOOM: 1.0,
            SCANLINE_WEIGHT1: 0.48,
            SCANLINE_WEIGHT2: 0.68,
            SCANLINE_WEIGHT3: 0.76,
            SCANLINE_WEIGHT4: 0.80,
            SCANLINE_WEIGHT5: 0.67,
            SCANLINE_WEIGHT6: 0.59,
            SCANLINE_WEIGHT7: 0.48,
            SCANLINE_WEIGHT8: 0.44,
            SCANLINE_BRIGHTNESS: 0.5,
            
            DEBUG_ENABLE: 1,
            DEBUG_TEXTURE: 9,
            DEBUG_ANCHOR: 0,
            DEBUG_SLICE: 0.5
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
    var dot: MTLTexture!
    
    // Dot mask provider
    var dotMaskLibrary: DotMaskLibrary!
    
    // var transform = MPSScaleTransform.init() // scaleX: 1.5, scaleY: 1.5, translateX: 0.0, translateY: 0.0)
    
    init() {
        
        super.init(name: "Dracula")
        
        settings = [
            
            Group(title: "Textures", [
                
                ShaderSetting(
                    title: "Input Downscaling Factor",
                    range: 0.125...1.0, step: 0.125,
                    value: Binding(
                        key: "INPUT_TEX_SCALE",
                        get: { [unowned self] in self.uniforms.INPUT_TEX_SCALE },
                        set: { [unowned self] in self.uniforms.INPUT_TEX_SCALE = $0 })),
                
                ShaderSetting(
                    title: "Output Upscaling Factor",
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
                
            ]),
            
            Group(title: "Chroma Effects", [
                
                ShaderSetting(
                    title: "Video Standard",
                    items: [("PAL", 1), ("NTSC", 0)],
                    value: Binding(
                        key: "PAL",
                        get: { [unowned self] in Float(self.uniforms.PAL) },
                        set: { [unowned self] in self.uniforms.PAL = Int32($0) })),
                
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
                
                ShaderSetting(
                    title: "Chroma Radius",
                    range: 1...10, step: 1,
                    value: Binding(
                        key: "CHROMA_RADIUS",
                        get: { [unowned self] in self.uniforms.CHROMA_RADIUS },
                        set: { [unowned self] in self.uniforms.CHROMA_RADIUS = $0 })),
            ]),
            
            Group(title: "Blooming",
                  
                  enable: Binding(
                    key: "BLOOM_ENABLE",
                    get: { [unowned self] in Float(self.uniforms.BLOOM_ENABLE) },
                    set: { [unowned self] in self.uniforms.BLOOM_ENABLE = Int32($0) }),
                  
                  [ ShaderSetting(
                    title: "Bloom Filter",
                    items: [("BOX", 0), ("TENT", 1), ("GAUSS", 2), ("MEDIAN", 3)],
                    value: Binding(
                        key: "BLOOM_FILTER",
                        get: { [unowned self] in Float(self.uniforms.BLOOM_FILTER) },
                        set: { [unowned self] in self.uniforms.BLOOM_FILTER = Int32($0) })),
                    
                    ShaderSetting(
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
                        get: { [unowned self] in self.uniforms.SCANLINE_DISTANCE },
                        set: { [unowned self] in self.uniforms.SCANLINE_DISTANCE = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Sharpness",
                        range: 0...4.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_SHARPNESS",
                            get: { [unowned self] in self.uniforms.SCANLINE_SHARPNESS },
                            set: { [unowned self] in self.uniforms.SCANLINE_SHARPNESS = $0 })),
                    
                    ShaderSetting(
                        title: "Scanline Bloom",
                        range: 0...1, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_BLOOM",
                            get: { [unowned self] in self.uniforms.SCANLINE_BLOOM },
                            set: { [unowned self] in self.uniforms.SCANLINE_BLOOM = $0 })),
                    
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
                    
                    ShaderSetting(
                        title: "Scanline Brightness",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "SCANLINE_BRIGHTNESS",
                            get: { [unowned self] in self.uniforms.SCANLINE_BRIGHTNESS },
                            set: { [unowned self] in self.uniforms.SCANLINE_BRIGHTNESS = $0 })),
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
                        title: "Dotmask Width",
                        range: 1.0...16.0, step: 1.0,
                        value: Binding(
                            key: "DOTMASK_WIDTH",
                            get: { [unowned self] in Float(self.uniforms.DOTMASK_WIDTH) },
                            set: { [unowned self] in self.uniforms.DOTMASK_WIDTH = Int32($0) })),

                    ShaderSetting(
                        title: "Dotmask Height",
                        range: 1.0...16.0, step: 1.0,
                        value: Binding(
                            key: "DOTMASK_HEIGHT",
                            get: { [unowned self] in Float(self.uniforms.DOTMASK_HEIGHT) },
                            set: { [unowned self] in self.uniforms.DOTMASK_HEIGHT = Int32($0) })),
                    
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
                        title: "Dotmask Loose",
                        range: -1.0...0.0, step: 0.01,
                        value: Binding(
                            key: "DOTMASK_LOOSE",
                            get: { [unowned self] in self.uniforms.DOTMASK_LOOSE },
                            set: { [unowned self] in self.uniforms.DOTMASK_LOOSE = $0 })),
                    
                  ]),
            
            Group(title: "Debugging",
                  
                  enable: Binding(
                    key: "DEBUG_ENABLE",
                    get: { [unowned self] in Float(self.uniforms.DEBUG_ENABLE) },
                    set: { [unowned self] in self.uniforms.DEBUG_ENABLE = Int32($0) }),
                  
                  [ ShaderSetting(
                    title: "Debug Texture",
                    items: [ ("Original", 0),
                             ("Ycc", 1),
                             ("Ycc (Mipmap 1)", 2),
                             ("Ycc (Mipmap 2)", 3),
                             ("Ycc (Mipmap 3)", 4),
                             ("Ycc (Mipmap 4)", 5),
                             ("Luma", 6),
                             ("Chroma U/I", 7),
                             ("Chroma V/Q", 8),
                             ("Dotmask", 9),
                             ("Bloom texture", 10) ],
                    value: Binding(
                        key: "DEBUG_TEXTURE",
                        get: { [unowned self] in Float(self.uniforms.DEBUG_TEXTURE) },
                        set: { [unowned self] in self.uniforms.DEBUG_TEXTURE = Int32($0) })),
                    
                    ShaderSetting(
                      title: "Debug Anchor",
                      items: [ ("Left", 0),
                               ("Right", 1),
                               ("Above", 2),
                               ("Below", 3) ],
                      value: Binding(
                          key: "DEBUG_TEXTURE",
                          get: { [unowned self] in Float(self.uniforms.DEBUG_ANCHOR) },
                          set: { [unowned self] in self.uniforms.DEBUG_ANCHOR = Int32($0) })),
                    
                    ShaderSetting(
                        title: "Debug Area",
                        range: 0.0...1.0, step: 0.01,
                        value: Binding(
                            key: "DEBUG_SLICE",
                            get: { [unowned self] in self.uniforms.DEBUG_SLICE },
                            set: { [unowned self] in self.uniforms.DEBUG_SLICE = $0 }))
                  ]),
        ]
    }
    
    override func activate() {
        
        super.activate()
        splitKernel = ColorSpaceFilter(sampler: ShaderLibrary.linear)
        dotMaskKernel = DotMaskFilter(sampler: ShaderLibrary.mipmapLinear)
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
            lin = output.makeTexture(width: inpWidth, height: inpHeight, mipmaps: 4)
            ycc = output.makeTexture(width: inpWidth, height: inpHeight, mipmaps: 4)
            bri = output.makeTexture(width: inpWidth, height: inpHeight)
            blm = output.makeTexture(width: inpWidth, height: inpHeight)
            rgb = output.makeTexture(width: inpWidth, height: inpHeight)
        }
        
        if crt?.width != crtWidth || crt?.height != crtHeight {
            
            dot = output.makeTexture(width: crtWidth, height: crtHeight, mipmaps: 4)
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
                          textures: [src, lin, ycc],
                          options: &uniforms,
                          length: MemoryLayout<Uniforms>.stride)
        
        pyramid.encode(commandBuffer: commandBuffer, inPlaceTexture: &ycc)
        pyramid.encode(commandBuffer: commandBuffer, inPlaceTexture: &lin)
        
        //
        //
        // Pass 3: Apply chroma effects
        //
        
        
        let descriptor = DotMaskDescriptor(type: uniforms.DOTMASK_TYPE,
                                           color: uniforms.DOTMASK_COLOR,
                                           cellWidth: uniforms.DOTMASK_WIDTH,
                                           cellHeight: uniforms.DOTMASK_HEIGHT,
                                           saturation: uniforms.DOTMASK_SATURATION,
                                           brightness: uniforms.DOTMASK_BRIGHTNESS,
                                           blur: 1.0)
        
        dotMaskLibrary.create(commandBuffer: commandBuffer,
                              descriptor: descriptor,
                              texture: &dot)
        
        /*
        dotMaskKernel.apply(commandBuffer: commandBuffer,
                            textures: [ycc, dot],
                            options: &uniforms,
                            length: MemoryLayout<Uniforms>.stride)
        */
        pyramid.encode(commandBuffer: commandBuffer, inPlaceTexture: &dot)
        
        chromaKernel.apply(commandBuffer: commandBuffer,
                           textures: [ycc, dot, rgb, bri],
                           options: &uniforms,
                           length: MemoryLayout<Uniforms>.stride)
        
        //
        // Pass 4: Create the bloom texture
        //
        
        blurFilter.blurType = BlurFilterType(rawValue: uniforms.BLOOM_FILTER)!
        blurFilter.blurWidth = uniforms.BLOOM_RADIUS_X
        blurFilter.blurHeight = uniforms.BLOOM_RADIUS_Y
        blurFilter.apply(commandBuffer: commandBuffer, in: bri, out: blm)
        
        //
        // Pass 5: Emulate CRT artifacts
        //
        
        crtKernel.apply(commandBuffer: commandBuffer,
                        textures: [lin, ycc, dot, blm, output],
                        options: &uniforms,
                        length: MemoryLayout<Uniforms>.stride)
        
        //
        // Optional: Run the debugger
        //
        
        if uniforms.DEBUG_ENABLE > 0 {
            
            debugKernel.apply(commandBuffer: commandBuffer,
                              textures: [src, ycc, dot, blm, output],
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
