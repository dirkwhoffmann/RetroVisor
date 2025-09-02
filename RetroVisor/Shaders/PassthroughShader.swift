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
final class PassthroughShader: Shader {

    struct Uniforms {

        var INPUT_TEX_SCALE: Float
        var OUTPUT_TEX_SCALE: Float

        var BLUR_ENABLE: Int32
        var BLUR_FILTER: BlurFilterType
        var BLUR_RADIUS_X: Float
        var BLUR_RADIUS_Y: Float

        var RESAMPLE_FILTER: ResampleFilterType
        var RESAMPLE_SCALE_X: Float
        var RESAMPLE_SCALE_Y: Float

        static let defaults = Uniforms(

            INPUT_TEX_SCALE: 0.5,
            OUTPUT_TEX_SCALE: 2.0,

            BLUR_ENABLE: 0,
            BLUR_FILTER: .box,
            BLUR_RADIUS_X: 1.0,
            BLUR_RADIUS_Y: 1.0,

            RESAMPLE_FILTER: .bilinear,
            RESAMPLE_SCALE_X: 1.0,
            RESAMPLE_SCALE_Y: 1.0
        )
    }

    var uniforms = Uniforms.defaults

    // Filter
    var resampler = ResampleFilter()
    var blurFilter = BlurFilter()

    // Downscaled input texture
    var src: MTLTexture!

    // Blurred texture
    var blur: MTLTexture!

    init() {

        super.init(name: "Passthrough")

        settings = [

            ShaderSettingGroup(title: "Textures", [

                ShaderSetting(
                    name: "Input Downscaling Factor",
                    key: "INPUT_TEX_SCALE",
                    get: { [unowned self] in self.uniforms.INPUT_TEX_SCALE },
                    set: { [unowned self] in self.uniforms.INPUT_TEX_SCALE = $0 },
                    range: 0.125...1.0,
                    step: 0.125,
                ),
                
                ShaderSetting(
                    name: "Resampler",
                    key: "RESAMPLE_FILTER",
                    get: { [unowned self] in Float(self.uniforms.RESAMPLE_FILTER.rawValue) },
                    set: { [unowned self] in self.uniforms.RESAMPLE_FILTER = ResampleFilterType($0)! },
                    values: [("BILINEAR", 0), ("LANCZOS", 1)],
                ),
            ]),

            ShaderSettingGroup(title: "Filter",
                               key: "BLUR_ENABLE",
                               get: { [unowned self] in Float(self.uniforms.BLUR_ENABLE) },
                               set: { [unowned self] in self.uniforms.BLUR_ENABLE = Int32($0) }, [

                ShaderSetting(
                    name: "Blur Filter",
                    key: "BLUR_FILTER",
                    get: { [unowned self] in self.uniforms.BLUR_FILTER.floatValue },
                    set: { [unowned self] in self.uniforms.BLUR_FILTER = BlurFilterType($0)! },
                    values: [("BOX", 0), ("TENT", 1), ("GAUSS", 2), ("MEDIAN", 3)],
                ),

                ShaderSetting(
                    name: "Blur width",
                    key: "BLUR_RADIUS_X",
                    get: { [unowned self] in self.uniforms.BLUR_RADIUS_X },
                    set: { [unowned self] in self.uniforms.BLUR_RADIUS_X = $0 },
                    range: 0.1...20.0,
                    step: 0.1
                ),

                ShaderSetting(
                    name: "Blur height",
                    key: "BLUR_RADIUS_Y",
                    get: { [unowned self] in self.uniforms.BLUR_RADIUS_Y },
                    set: { [unowned self] in self.uniforms.BLUR_RADIUS_Y = $0 },
                    range: 0.1...20.0,
                    step: 0.1
                ),

                ShaderSetting(
                    name: "Scale X",
                    key: "RESAMPLE_SCALE_X",
                    get: { [unowned self] in self.uniforms.RESAMPLE_SCALE_X },
                    set: { [unowned self] in self.uniforms.RESAMPLE_SCALE_X = $0 },
                    range: 0.1...1.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Scale Y",
                    key: "RESAMPLE_SCALE_Y",
                    get: { [unowned self] in self.uniforms.RESAMPLE_SCALE_Y },
                    set: { [unowned self] in self.uniforms.RESAMPLE_SCALE_Y = $0 },
                    range: 0.1...1.0,
                    step: 0.01
                )
            ])
        ]
    }

    /*
    override func get(key: String) -> Float {

        switch key {

        case "INPUT_TEX_SCALE":     return Float(uniforms.INPUT_TEX_SCALE)
        case "OUTPUT_TEX_SCALE":    return Float(uniforms.OUTPUT_TEX_SCALE)
        case "RESAMPLE_FILTER":     return Float(uniforms.RESAMPLE_FILTER.rawValue)

        case "BLUR_ENABLE":         return Float(uniforms.BLUR_ENABLE)
        case "BLUR_FILTER":         return Float(uniforms.BLUR_FILTER.rawValue)
        case "BLUR_RADIUS_X":       return Float(uniforms.BLUR_RADIUS_X)
        case "BLUR_RADIUS_Y":       return Float(uniforms.BLUR_RADIUS_Y)
        case "RESAMPLE_SCALE_X":    return Float(uniforms.RESAMPLE_SCALE_X)
        case "RESAMPLE_SCALE_Y":    return Float(uniforms.RESAMPLE_SCALE_Y)

        default:
            return super.get(key: key)
        }
    }
    */
    
    override func set(key: String, value: Float) {
        
        super.set(key: key, value: value)
        /*
        switch key {

        case "RESAMPLE_FILTER":     uniforms.RESAMPLE_FILTER = ResampleFilterType(value)!
        case "INPUT_TEX_SCALE":     uniforms.INPUT_TEX_SCALE = value
        case "OUTPUT_TEX_SCALE":    uniforms.OUTPUT_TEX_SCALE = value

        case "BLUR_ENABLE":         uniforms.BLUR_ENABLE = Int32(value)
        case "BLUR_FILTER":         uniforms.BLUR_FILTER = BlurFilterType(value)!
        case "BLUR_RADIUS_X":       uniforms.BLUR_RADIUS_X = value
        case "BLUR_RADIUS_Y":       uniforms.BLUR_RADIUS_Y = value
        case "RESAMPLE_SCALE_X":    uniforms.RESAMPLE_SCALE_X = value
        case "RESAMPLE_SCALE_Y":    uniforms.RESAMPLE_SCALE_Y = value

        default:
            super.set(key: key, value: value)
        }
        */
        
        setHidden(key: "BLUR_RADIUS_Y",
                  value: get(key: "BLUR_FILTER") == BlurFilterType.gaussian.floatValue)
    }

    func updateTextures(in input: MTLTexture, out output: MTLTexture) {

        let srcW = Int(Float(output.width) * uniforms.INPUT_TEX_SCALE)
        let srcH = Int(Float(output.height) * uniforms.INPUT_TEX_SCALE)

        if src?.width != srcW || src?.height != srcH {

            src = output.makeTexture(width: srcW, height: srcH)
            blur = output.makeTexture(width: srcW, height: srcH)
        }
    }

    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        // Create helper textures if needed
        updateTextures(in: input, out: output)

        // Rescale to the source texture size
        resampler.type = uniforms.RESAMPLE_FILTER
        resampler.apply(commandBuffer: commandBuffer, in: input, out: src, rect: rect)

        if uniforms.BLUR_ENABLE != 0 {

            // Blur the source texture
            blurFilter.blurType = uniforms.BLUR_FILTER
            blurFilter.resampleX = uniforms.RESAMPLE_SCALE_X
            blurFilter.resampleY = uniforms.RESAMPLE_SCALE_Y
            blurFilter.blurWidth = uniforms.BLUR_RADIUS_X
            blurFilter.blurHeight = uniforms.BLUR_RADIUS_Y
            blurFilter.apply(commandBuffer: commandBuffer, in: src, out: blur)

            // Rescale to the output texture size
            resampler.apply(commandBuffer: commandBuffer, in: blur, out: output)

        } else {

            // Rescale to the output texture size
            resampler.apply(commandBuffer: commandBuffer, in: src, out: output)
        }
    }
}
