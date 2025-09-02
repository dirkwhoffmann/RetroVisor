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

            Group(title: "Channels", [

                ShaderSetting(
                    name: "Hue",
                    range: 0.0...1.0,
                    step: 0.01,
                    enable: Binding(
                        key: "H_ENABLE",
                        get: { [unowned self] in Float(self.uniforms.H_ENABLE) },
                        set: { [unowned self] in self.uniforms.H_ENABLE = Int32($0) }),
                    value: Binding(
                        key: "H_VALUE",
                        get: { [unowned self] in self.uniforms.H_VALUE },
                        set: { [unowned self] in self.uniforms.H_VALUE = $0 }),
                ),

                ShaderSetting(
                    name: "Saturation",
                    range: 0.0...1.0,
                    step: 0.01,
                    enable: Binding(
                        key: "S_ENABLE",
                        get: { [unowned self] in Float(self.uniforms.S_ENABLE) },
                        set: { [unowned self] in self.uniforms.S_ENABLE = Int32($0) }),
                    value: Binding(
                        key: "S_VALUE",
                        get: { [unowned self] in self.uniforms.S_VALUE },
                        set: { [unowned self] in self.uniforms.S_VALUE = $0 }),
                ),

                ShaderSetting(
                    name: "Value",
                    range: 0.0...1.0,
                    step: 0.01,
                    enable: Binding(
                        key: "V_ENABLE",
                        get: { [unowned self] in Float(self.uniforms.V_ENABLE) },
                        set: { [unowned self] in self.uniforms.V_ENABLE = Int32($0) }),
                    value: Binding(
                        key: "V_VALUE",
                        get: { [unowned self] in self.uniforms.V_VALUE },
                        set: { [unowned self] in self.uniforms.V_VALUE = $0 }),
                ),
            ]),
        ]
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
