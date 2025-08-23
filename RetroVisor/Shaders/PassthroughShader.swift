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
        var RESAMPLE_FILTER: ResampleFilterType
        var BLUR_ENABLE: Int32
        var BLUR_FILTER: BlurFilterType
        var BLUR_SCALE_X: Float
        var BLUR_SCALE_Y: Float
        var BLUR_RADIUS: Float

        static let defaults = Uniforms(

            INPUT_PIXEL_SIZE: 1,
            RESAMPLE_FILTER: .bilinear,
            BLUR_ENABLE: 0,
            BLUR_FILTER: .box,
            BLUR_SCALE_X: 1.0,
            BLUR_SCALE_Y: 1.0,
            BLUR_RADIUS: 1.0
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
                name: "Resampler",
                key: "RESAMPLE_FILTER",
                values: [("BILINEAR", 0), ("LANCZOS", 1)]
            ),

            ShaderSetting(
                name: "Blur Filter",
                enableKey: "BLUR_ENABLE",
                key: "BLUR_FILTER",
                values: [("BOX", 0), ("TENT", 1), ("GAUSS", 2), ("MEDIAN", 3)]
            ),

            ShaderSetting(
                name: "Blur radius",
                key: "BLUR_RADIUS",
                range: 0.1...20.0,
                step: 0.1
            ),

            ShaderSetting(
                name: "Scale X",
                key: "BLUR_SCALE_X",
                range: 0.1...1.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Scale Y",
                key: "BLUR_SCALE_Y",
                range: 0.1...1.0,
                step: 0.01
            )
        ]
    }

    override func get(key: String) -> Float {

        switch key {

        case "INPUT_PIXEL_SIZE":    return Float(uniforms.INPUT_PIXEL_SIZE)
        case "RESAMPLE_FILTER":     return Float(uniforms.RESAMPLE_FILTER.rawValue)
        case "BLUR_ENABLE":         return Float(uniforms.BLUR_ENABLE)
        case "BLUR_FILTER":         return Float(uniforms.BLUR_FILTER.rawValue)
        case "BLUR_SCALE_X":        return Float(uniforms.BLUR_SCALE_X)
        case "BLUR_SCALE_Y":        return Float(uniforms.BLUR_SCALE_Y)
        case "BLUR_RADIUS":         return Float(uniforms.BLUR_RADIUS)

        default:
            return super.get(key: key)
        }
    }

    override func set(key: String, value: Float) {

        switch key {

        case "INPUT_PIXEL_SIZE":    uniforms.INPUT_PIXEL_SIZE = Int32(value)
        case "RESAMPLE_FILTER":     uniforms.RESAMPLE_FILTER = ResampleFilterType(rawValue: Int32(value))!
        case "BLUR_ENABLE":         uniforms.BLUR_ENABLE = Int32(value)
        case "BLUR_FILTER":         uniforms.BLUR_FILTER = BlurFilterType(rawValue: Int32(value))!
        case "BLUR_SCALE_X":        uniforms.BLUR_SCALE_X = value
        case "BLUR_SCALE_Y":        uniforms.BLUR_SCALE_Y = value
        case "BLUR_RADIUS":         uniforms.BLUR_RADIUS = value

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
            blurFilter.type = uniforms.BLUR_FILTER
            blurFilter.scaleX = uniforms.BLUR_SCALE_X
            blurFilter.scaleY = uniforms.BLUR_SCALE_Y
            blurFilter.radius = uniforms.BLUR_RADIUS
            blurFilter.apply(commandBuffer: commandBuffer, in: src, out: blur)

            // Rescale to the output texture size
            resampler.apply(commandBuffer: commandBuffer, in: blur, out: output)

        } else {

            // Rescale to the output texture size
            resampler.apply(commandBuffer: commandBuffer, in: src, out: output)
        }
    }
}
