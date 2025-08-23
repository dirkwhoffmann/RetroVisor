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

        var INPUT_PIXEL_SIZE: Int32

        var BLUR_ENABLE: Int32
        var BLUR_FILTER: BlurFilterType
        var BLUR_RADIUS_X: Float
        var BLUR_RADIUS_Y: Float

        var RESAMPLE_FILTER: ResampleFilterType
        var RESAMPLE_SCALE_X: Float
        var RESAMPLE_SCALE_Y: Float

        static let defaults = Uniforms(

            INPUT_PIXEL_SIZE: 1,

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

            ShaderSetting(
                name: "Input Pixel Size",
                key: "INPUT_PIXEL_SIZE",
                range: 1...16,
                step: 1
            ),

            ShaderSetting(
                name: "Blur Filter",
                enableKey: "BLUR_ENABLE",
                key: "BLUR_FILTER",
                values: [("BOX", 0), ("TENT", 1), ("GAUSS", 2), ("MEDIAN", 3)]
            ),

            ShaderSetting(
                name: "Blur width",
                key: "BLUR_RADIUS_X",
                range: 0.1...20.0,
                step: 0.1
            ),

            ShaderSetting(
                name: "Blur height",
                key: "BLUR_RADIUS_Y",
                range: 0.1...20.0,
                step: 0.1
            ),

            ShaderSetting(
                name: "Resampler",
                key: "RESAMPLE_FILTER",
                values: [("BILINEAR", 0), ("LANCZOS", 1)]
            ),

            ShaderSetting(
                name: "Scale X",
                key: "RESAMPLE_SCALE_X",
                range: 0.1...1.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Scale Y",
                key: "RESAMPLE_SCALE_Y",
                range: 0.1...1.0,
                step: 0.01
            )
        ]
    }

    override func get(key: String) -> Float {

        switch key {

        case "INPUT_PIXEL_SIZE":    return Float(uniforms.INPUT_PIXEL_SIZE)
        case "BLUR_ENABLE":         return Float(uniforms.BLUR_ENABLE)
        case "BLUR_FILTER":         return Float(uniforms.BLUR_FILTER.rawValue)
        case "BLUR_RADIUS_X":       return Float(uniforms.BLUR_RADIUS_X)
        case "BLUR_RADIUS_Y":       return Float(uniforms.BLUR_RADIUS_Y)
        case "RESAMPLE_FILTER":     return Float(uniforms.RESAMPLE_FILTER.rawValue)
        case "RESAMPLE_SCALE_X":    return Float(uniforms.RESAMPLE_SCALE_X)
        case "RESAMPLE_SCALE_Y":    return Float(uniforms.RESAMPLE_SCALE_Y)

        default:
            return super.get(key: key)
        }
    }

    override func set(key: String, value: Float) {

        switch key {

        case "INPUT_PIXEL_SIZE":    uniforms.INPUT_PIXEL_SIZE = Int32(value)
        case "BLUR_ENABLE":         uniforms.BLUR_ENABLE = Int32(value)
        case "BLUR_FILTER":         uniforms.BLUR_FILTER = BlurFilterType(rawValue: Int32(value))!
        case "BLUR_RADIUS_X":       uniforms.BLUR_RADIUS_X = value
        case "BLUR_RADIUS_Y":       uniforms.BLUR_RADIUS_Y = value
        case "RESAMPLE_FILTER":     uniforms.RESAMPLE_FILTER = ResampleFilterType(rawValue: Int32(value))!
        case "RESAMPLE_SCALE_X":    uniforms.RESAMPLE_SCALE_X = value
        case "RESAMPLE_SCALE_Y":    uniforms.RESAMPLE_SCALE_Y = value

        default:
            super.set(key: key, value: value)
        }
    }

    func updateTextures(in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        let srcW = output.width / Int(uniforms.INPUT_PIXEL_SIZE)
        let srcH = output.height / Int(uniforms.INPUT_PIXEL_SIZE)

        if src?.width != srcW || src?.height != srcH {

            src = output.makeTexture(width: srcW, height: srcH)
            blur = output.makeTexture(width: srcW, height: srcH)
        }
    }

    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        // Create helper textures if needed
        updateTextures(in: input, out: output, rect: rect)

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
