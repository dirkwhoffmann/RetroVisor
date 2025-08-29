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
final class HSVShader: Shader {

    var hsvKernel: Kernel!

    struct Uniforms {

        var H_ENABLE: Int32
        var H_VALUE: Float

        var S_ENABLE: Int32
        var S_VALUE: Float

        var V_ENABLE: Int32
        var V_VALUE: Float

        static let defaults = Uniforms(

            H_ENABLE: 0,
            H_VALUE: 0.5,

            S_ENABLE: 0,
            S_VALUE: 0.5,

            V_ENABLE: 0,
            V_VALUE: 0.5,
        )
    }

    var uniforms = Uniforms.defaults

    // Textures
    var src: MTLTexture!

    // Filters
    var resampler = ResampleFilter()
    var hsvFilter = HSVFilter()

    init() {

        super.init(name: "HSV Splitter")

        settings = [

            ShaderSettingGroup(title: "Channels", [

                ShaderSetting(
                    name: "Hue",
                    enableKey: "H_ENABLE",
                    key: "H_VALUE",
                    range: 0.0...1.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Saturation",
                    enableKey: "S_ENABLE",
                    key: "S_VALUE",
                    range: 0.0...1.0,
                    step: 0.01
                ),

                ShaderSetting(
                    name: "Value",
                    enableKey: "V_ENABLE",
                    key: "V_VALUE",
                    range: 0.0...1.0,
                    step: 0.01
                ),
            ]),
        ]
    }

    override func get(key: String) -> Float {

        switch key {

        case "H_ENABLE":    return Float(uniforms.H_ENABLE)
        case "H_VALUE":     return Float(uniforms.H_VALUE)

        case "S_ENABLE":    return Float(uniforms.S_ENABLE)
        case "S_VALUE":     return Float(uniforms.S_VALUE)

        case "V_ENABLE":    return Float(uniforms.V_ENABLE)
        case "V_VALUE":     return Float(uniforms.V_VALUE)

        default:
            return super.get(key: key)
        }
    }

    override func set(key: String, value: Float) {

        switch key {

        case "H_ENABLE":    uniforms.H_ENABLE = Int32(value)
        case "H_VALUE":     uniforms.H_VALUE = value

        case "S_ENABLE":    uniforms.S_ENABLE = Int32(value)
        case "S_VALUE":     uniforms.S_VALUE = value

        case "V_ENABLE":    uniforms.V_ENABLE = Int32(value)
        case "V_VALUE":     uniforms.V_VALUE = value

        default:
            super.set(key: key, value: value)
        }
    }

    override func activate() {

        super.activate()
        hsvKernel = HSVFilter(sampler: ShaderLibrary.linear)
    }

    func updateTextures(in input: MTLTexture, out output: MTLTexture) {

        let srcW = Int(Float(output.width))
        let srcH = Int(Float(output.height))

        if src?.width != srcW || src?.height != srcH {

            src = output.makeTexture(width: srcW, height: srcH)
        }
    }

    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        // Create helper textures if needed
        updateTextures(in: input, out: output)

        // Rescale to the source texture size
        resampler.apply(commandBuffer: commandBuffer, in: input, out: src, rect: rect)

        // Apply the HSV filter
        hsvKernel.apply(commandBuffer: commandBuffer,
                        textures: [src, output],
                        options: &uniforms,
                        length: MemoryLayout<PlaygroundUniforms>.stride)
    }
}
