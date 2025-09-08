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
final class ColorFilter: Shader {
    
    struct Uniforms {
        
        var INPUT_TEX_SCALE: Float
        var OUTPUT_TEX_SCALE: Float

        var PALETTE: Int32
        var BRIGHTNESS: Float
        var CONTRAST: Float
        var SATURATION: Float

        var BLUR_ENABLE: Int32
        var BLUR_FILTER: Int32
        var BLUR_RADIUS_X: Float
        var BLUR_RADIUS_Y: Float
        
        var RESAMPLE_FILTER: Int32
        var RESAMPLE_SCALE_X: Float
        var RESAMPLE_SCALE_Y: Float
        
        static let defaults = Uniforms(
            
            INPUT_TEX_SCALE: 0.5,
            OUTPUT_TEX_SCALE: 2.0,
            
            PALETTE: 0,
            BRIGHTNESS: 0.5,
            CONTRAST: 0.5,
            SATURATION: 0.5,
            
            BLUR_ENABLE: 0,
            BLUR_FILTER: BlurFilterType.box.rawValue,
            BLUR_RADIUS_X: 1.0,
            BLUR_RADIUS_Y: 1.0,
            
            RESAMPLE_FILTER: ResampleFilterType.bilinear.rawValue,
            RESAMPLE_SCALE_X: 1.0,
            RESAMPLE_SCALE_Y: 1.0
        )
    }
    
    var uniforms = Uniforms.defaults
    
    // Filter
    var resampler = ResampleFilter()
    var blurFilter = BlurFilter()
    var colorizer = PaletteFilter(sampler: ShaderLibrary.linear)
    
    // Downscaled input texture
    var src: MTLTexture!

    // Colorized texture
    var col: MTLTexture!

    // Blurred texture
    var blur: MTLTexture!
    
    init() {
        
        super.init(name: "Passthrough")
        
        delegate = self
        
        settings = [
            
            Group(title: "Textures", [
                
                ShaderSetting(
                    title: "Input Downscaling Factor",
                    range: 0.125...1.0,
                    step: 0.125,
                    value: Binding(
                        key: "INPUT_TEX_SCALE",
                        get: { [unowned self] in self.uniforms.INPUT_TEX_SCALE },
                        set: { [unowned self] in self.uniforms.INPUT_TEX_SCALE = $0 })),
                
                ShaderSetting(
                    title: "Resampler",
                    items: [("BILINEAR", 0), ("LANCZOS", 1)],
                    value: Binding(
                        key: "RESAMPLE_FILTER",
                        get: { [unowned self] in Float(self.uniforms.RESAMPLE_FILTER) },
                        set: { [unowned self] in self.uniforms.RESAMPLE_FILTER = Int32($0) })),
            ]),
            
            Group(title: "Filter",
                  
                  enable: Binding(
                    key: "BLUR_ENABLE",
                    get: { [unowned self] in Float(self.uniforms.BLUR_ENABLE) },
                    set: { [unowned self] in self.uniforms.BLUR_ENABLE = Int32($0) }),
                  
                  [ ShaderSetting(
                    title: "Palette",
                    items: [("COLOR", 0), ("BLACK_WHITE", 1), ("PAPER_WHITE", 2),
                            ("GREEN", 3), ("AMBER", 4), ("SEPIA", 5)],
                    value: Binding(
                        key: "PALETTE",
                        get: { [unowned self] in Float(self.uniforms.PALETTE) },
                        set: { [unowned self] in self.uniforms.PALETTE = Int32($0) })),
                    
                    ShaderSetting(
                    title: "Blur Filter",
                    items: [("BOX", 0), ("TENT", 1), ("GAUSS", 2)],
                    value: Binding(
                        key: "BLUR_FILTER",
                        get: { [unowned self] in Float(self.uniforms.BLUR_FILTER) },
                        set: { [unowned self] in self.uniforms.BLUR_FILTER = Int32($0) })),
                    
                    ShaderSetting(
                        title: "Blur width",
                        range: 0.1...20.0,
                        step: 0.1,
                        value: Binding(
                            key: "BLUR_RADIUS_X",
                            get: { [unowned self] in self.uniforms.BLUR_RADIUS_X },
                            set: { [unowned self] in self.uniforms.BLUR_RADIUS_X = $0 })),
                    
                    ShaderSetting(
                        title: "Blur height",
                        range: 0.1...20.0,
                        step: 0.1,
                        value: Binding(
                            key: "BLUR_RADIUS_Y",
                            get: { [unowned self] in self.uniforms.BLUR_RADIUS_Y },
                            set: { [unowned self] in self.uniforms.BLUR_RADIUS_Y = $0 })),
                    
                    ShaderSetting(
                        title: "Scale X",
                        range: 0.1...1.0,
                        step: 0.01,
                        value: Binding(
                            key: "RESAMPLE_SCALE_X",
                            get: { [unowned self] in self.uniforms.RESAMPLE_SCALE_X },
                            set: { [unowned self] in self.uniforms.RESAMPLE_SCALE_X = $0 })),
                    
                    ShaderSetting(
                        title: "Scale Y",
                        range: 0.1...1.0,
                        step: 0.01,
                        value: Binding(
                            key: "RESAMPLE_SCALE_Y",
                            get: { [unowned self] in self.uniforms.RESAMPLE_SCALE_Y },
                            set: { [unowned self] in self.uniforms.RESAMPLE_SCALE_Y = $0 }))
                  ])
        ]
    }
    
    override func revertToPreset(nr: Int) {
        
        uniforms = Uniforms.defaults
    }
    
    func updateTextures(in input: MTLTexture, out output: MTLTexture) {
        
        let srcW = Int(Float(output.width) * uniforms.INPUT_TEX_SCALE)
        let srcH = Int(Float(output.height) * uniforms.INPUT_TEX_SCALE)
        
        if src?.width != srcW || src?.height != srcH {
            
            src = output.makeTexture(width: srcW, height: srcH)
            col = output.makeTexture(width: srcW, height: srcH)
            blur = output.makeTexture(width: srcW, height: srcH)
        }
    }
    
    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {
        
        // Create helper textures if needed
        updateTextures(in: input, out: output)
        
        // Rescale to the source texture size
        resampler.type = ResampleFilterType(rawValue: uniforms.RESAMPLE_FILTER)!
        resampler.apply(commandBuffer: commandBuffer, in: input, out: src, rect: rect)
        
        // Apply the color split filter
        colorizer!.apply(commandBuffer: commandBuffer,
                         textures: [src, col],
                         options: &uniforms,
                         length: MemoryLayout<Uniforms>.stride)
        
        if uniforms.BLUR_ENABLE != 0 {
            
            // Blur the source texture
            blurFilter.blurType = BlurFilterType(rawValue: uniforms.BLUR_FILTER)!
            blurFilter.resampleXY = (uniforms.RESAMPLE_SCALE_X, uniforms.RESAMPLE_SCALE_Y)
            blurFilter.blurSize = (uniforms.BLUR_RADIUS_X, uniforms.BLUR_RADIUS_Y)
            blurFilter.apply(commandBuffer: commandBuffer, in: col, out: blur)
            
            // Rescale to the output texture size
            resampler.apply(commandBuffer: commandBuffer, in: blur, out: output)
            
        } else {
            
            // Rescale to the output texture size
            resampler.apply(commandBuffer: commandBuffer, in: col, out: output)
        }
    }
}

extension ColorFilter: ShaderDelegate {
    
    func isHidden(setting: ShaderSetting) -> Bool {
        
        switch setting.valueKey {
            
        case "BLUR_RADIUS_Y":
            return uniforms.BLUR_FILTER == BlurFilterType.gaussian.rawValue
        default:
            return false
        }
    }    
}

extension ColorFilter {
    
    class PaletteFilter: Kernel {

        convenience init?(sampler: MTLSamplerState) {

            self.init(name: "colorfilter::colorizer", sampler: sampler)
        }
    }
}
