// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

struct CrtUniforms {

    var BRIGHT_BOOST: Float
    var DILATION: Float
    var GAMMA_INPUT: Float
    var GAMMA_OUTPUT: Float
    var MASK_SIZE: Float
    var MASK_STAGGER: Float
    var MASK_STRENGTH: Float
    var MASK_DOT_WIDTH: Float
    var MASK_DOT_HEIGHT: Float
    var SCANLINE_BEAM_WIDTH_MAX: Float
    var SCANLINE_BEAM_WIDTH_MIN: Float
    var SCANLINE_BRIGHT_MAX: Float
    var SCANLINE_BRIGHT_MIN: Float
    var SCANLINE_CUTOFF: Float
    var SCANLINE_STRENGTH: Float
    var SHARPNESS_H: Float
    var SHARPNESS_V: Float
    var ENABLE_LANCZOS: Int32

    static let defaults = CrtUniforms(

        BRIGHT_BOOST: 1.2,
        DILATION: 1.0,
        GAMMA_INPUT: 2.0,
        GAMMA_OUTPUT: 1.8,
        MASK_SIZE: 1.0,
        MASK_STAGGER: 0.0,
        MASK_STRENGTH: 0.3,
        MASK_DOT_WIDTH: 1.0,
        MASK_DOT_HEIGHT: 1.0,
        SCANLINE_BEAM_WIDTH_MAX: 1.5,
        SCANLINE_BEAM_WIDTH_MIN: 1.5,
        SCANLINE_BRIGHT_MAX: 0.65,
        SCANLINE_BRIGHT_MIN: 0.35,
        SCANLINE_CUTOFF: 1000.0,
        SCANLINE_STRENGTH: 1.0,
        SHARPNESS_H: 0.5,
        SHARPNESS_V: 1.0,
        ENABLE_LANCZOS: 1
    )
}

final class CRTEasyShader: Shader {

    var kernel: Kernel!
    var uniforms: CrtUniforms = .defaults

    // Input texture passed to the CRTEasy kernel
    var src: MTLTexture!

    init() {

        super.init(name: "CrtEasy")

        settings = [

            Group(title: "Uniforms", [
                
                ShaderSetting(
                    name: "Brightness Boost",
                    range: 0.0...2.0, step: 0.01,
                    value: Binding(
                        key: "BRIGHT_BOOST",
                        get: { [unowned self] in self.uniforms.BRIGHT_BOOST },
                        set: { [unowned self] in self.uniforms.BRIGHT_BOOST = $0 }),
                ),
                
                ShaderSetting(
                    name: "Horizontal Sharpness",
                    range: 0.0...1.0, step: 0.05,
                    value: Binding(
                        key: "SHARPNESS_H",
                        get: { [unowned self] in self.uniforms.SHARPNESS_H },
                        set: { [unowned self] in self.uniforms.SHARPNESS_H = $0 }),
                ),
                
                ShaderSetting(
                    name: "Vertical Sharpness",
                    range: 0.0...1.0, step: 0.05,
                    value: Binding(
                        key: "SHARPNESS_V",
                        get: { [unowned self] in self.uniforms.SHARPNESS_V },
                        set: { [unowned self] in self.uniforms.SHARPNESS_V = $0 }),
                ),
                
                ShaderSetting(
                    name: "Dilation",
                    range: 0.0...1.0, step: 0.05,
                    value: Binding(
                        key: "DILATION",
                        get: { [unowned self] in self.uniforms.DILATION },
                        set: { [unowned self] in self.uniforms.DILATION = $0 }),
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
                    name: "Dot Mask Strength",
                    range: 0.0...1.0, step: 0.01,
                    value: Binding(
                        key: "MASK_STRENGTH",
                        get: { [unowned self] in self.uniforms.MASK_STRENGTH },
                        set: { [unowned self] in self.uniforms.MASK_STRENGTH = $0 }),
                ),
                
                ShaderSetting(
                    name: "Dot Mask Width",
                    range: 1.0...100.0, step: 1.0,
                    value: Binding(
                        key: "MASK_DOT_WIDTH",
                        get: { [unowned self] in self.uniforms.MASK_DOT_WIDTH },
                        set: { [unowned self] in self.uniforms.MASK_DOT_WIDTH = $0 }),
                ),
                
                ShaderSetting(
                    name: "Dot Mask Height",
                    range: 1.0...100.0, step: 1.0,
                    value: Binding(
                        key: "MASK_DOT_HEIGHT",
                        get: { [unowned self] in self.uniforms.MASK_DOT_HEIGHT },
                        set: { [unowned self] in self.uniforms.MASK_DOT_HEIGHT = $0 }),
                ),
                
                ShaderSetting(
                    name: "Dot Mask Stagger",
                    range: 0.0...100.0, step: 1.0,
                    value: Binding(
                        key: "MASK_STAGGER",
                        get: { [unowned self] in self.uniforms.MASK_STAGGER },
                        set: { [unowned self] in self.uniforms.MASK_STAGGER = $0 }),
                ),
                
                ShaderSetting(
                    name: "Dot Mask Size",
                    range: 1.0...100.0, step: 1.0,
                    value: Binding(
                        key: "MASK_SIZE",
                        get: { [unowned self] in self.uniforms.MASK_SIZE },
                        set: { [unowned self] in self.uniforms.MASK_SIZE = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Strength",
                    range: 0.0...1.0, step: 0.05,
                    value: Binding(
                        key: "SCANLINE_STRENGTH",
                        get: { [unowned self] in self.uniforms.SCANLINE_STRENGTH },
                        set: { [unowned self] in self.uniforms.SCANLINE_STRENGTH = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Minimum Beam Width",
                    range: 0.5...5.0, step: 0.5,
                    value: Binding(
                        key: "SCANLINE_BEAM_WIDTH_MIN",
                        get: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MIN },
                        set: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MIN = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Maximum Beam Width",
                    range: 0.5...5.0, step: 0.5,
                    value: Binding(
                        key: "SCANLINE_BEAM_WIDTH_MAX",
                        get: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MAX },
                        set: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MAX = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Minimum Brightness",
                    range: 0.0...1.0, step: 0.05,
                    value: Binding(
                        key: "SCANLINE_BEAM_WIDTH_MAX",
                        get: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MAX },
                        set: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MAX = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Maximum Brightness",
                    range: 0.0...1.0, step: 0.05,
                    value: Binding(
                        key: "SCANLINE_BRIGHT_MAX",
                        get: { [unowned self] in self.uniforms.SCANLINE_BRIGHT_MAX },
                        set: { [unowned self] in self.uniforms.SCANLINE_BRIGHT_MAX = $0 }),
                ),
                
                ShaderSetting(
                    name: "Scanline Cutoff",
                    range: 1.0...1000.0, step: 1.0,
                    value: Binding(
                        key: "SCANLINE_CUTOFF",
                        get: { [unowned self] in self.uniforms.SCANLINE_CUTOFF },
                        set: { [unowned self] in self.uniforms.SCANLINE_CUTOFF = $0 }),
                ),
                
                ShaderSetting(
                    name: "Lanczos Filter",
                    range: nil, step: 1.0,
                    value: Binding(
                        key: "ENABLE_LANCZOS",
                        get: { [unowned self] in Float(self.uniforms.ENABLE_LANCZOS) },
                        set: { [unowned self] in self.uniforms.ENABLE_LANCZOS = Int32($0) }),
                ),
            ])
        ]
    }

    override func activate() {

        super.activate()
        kernel = CrtEasyKernel(sampler: ShaderLibrary.linear)
    }

    func updateTextures(in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        let inpWidth = output.width // * uniforms.INPUT_TEX_SCALE
        let inpHeight = output.height // * uniforms.INPUT_TEX_SCALE

        if src?.width != inpWidth || src?.height != inpHeight {

            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: output.pixelFormat,
                width: inpWidth,
                height: inpHeight,
                mipmapped: false
            )
            desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
            src = output.device.makeTexture(descriptor: desc)
        }
    }
    
    override func apply(commandBuffer: MTLCommandBuffer,
                        in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        updateTextures(in: input, out: output, rect: rect)

        // Crop and downscale the captured screen contents
        let scaler = ShaderLibrary.bilinear
        scaler.apply(commandBuffer: commandBuffer, in: input, out: src, rect: rect)

        // Apply the CRTEasy kernel
        kernel.apply(commandBuffer: commandBuffer,
                     source: src, target: output,
                     options: &app.windowController!.metalView!.uniforms,
                     length: MemoryLayout<Uniforms>.stride,
                     options2: &uniforms,
                     length2: MemoryLayout<CrtUniforms>.stride)
    }
}
