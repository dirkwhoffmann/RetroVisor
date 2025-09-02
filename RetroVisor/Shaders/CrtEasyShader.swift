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

            ShaderSettingGroup(title: "Uniforms", [
                
                ShaderSetting(
                    name: "Brightness Boost",
                    key: "BRIGHT_BOOST",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.BRIGHT_BOOST },
                        set: { [unowned self] in self.uniforms.BRIGHT_BOOST = $0 }),
                    range: 0.0...2.0,
                    step: 0.01
                ),
                
                ShaderSetting(
                    name: "Horizontal Sharpness",
                    key: "SHARPNESS_H",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.SHARPNESS_H },
                        set: { [unowned self] in self.uniforms.SHARPNESS_H = $0 }),
                    range: 0.0...1.0,
                    step: 0.05
                ),
                
                ShaderSetting(
                    name: "Vertical Sharpness",
                    key: "SHARPNESS_V",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.SHARPNESS_V },
                        set: { [unowned self] in self.uniforms.SHARPNESS_V = $0 }),
                    range: 0.0...1.0,
                    step: 0.05
                ),
                
                ShaderSetting(
                    name: "Dilation",
                    key: "DILATION",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.DILATION },
                        set: { [unowned self] in self.uniforms.DILATION = $0 }),
                    range: 0.0...1.0,
                    step: 0.05
                ),
                
                ShaderSetting(
                    name: "Gamma Input",
                    key: "GAMMA_INPUT",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.GAMMA_INPUT },
                        set: { [unowned self] in self.uniforms.GAMMA_INPUT = $0 }),
                    range: 0.1...5.0,
                    step: 0.1
                ),
                
                ShaderSetting(
                    name: "Gamma Output",
                    key: "GAMMA_OUTPUT",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.GAMMA_OUTPUT },
                        set: { [unowned self] in self.uniforms.GAMMA_OUTPUT = $0 }),
                    range: 0.1...5.0,
                    step: 0.1
                ),
                
                ShaderSetting(
                    name: "Dot Mask Strength",
                    key: "MASK_STRENGTH",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.MASK_STRENGTH },
                        set: { [unowned self] in self.uniforms.MASK_STRENGTH = $0 }),
                    range: 0.0...1.0,
                    step: 0.01
                ),
                
                ShaderSetting(
                    name: "Dot Mask Width",
                    key: "MASK_DOT_WIDTH",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.MASK_DOT_WIDTH },
                        set: { [unowned self] in self.uniforms.MASK_DOT_WIDTH = $0 }),
                    range: 1.0...100.0,
                    step: 1.0
                ),
                
                ShaderSetting(
                    name: "Dot Mask Height",
                    key: "MASK_DOT_HEIGHT",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.MASK_DOT_HEIGHT },
                        set: { [unowned self] in self.uniforms.MASK_DOT_HEIGHT = $0 }),
                    range: 1.0...100.0,
                    step: 1.0
                ),
                
                ShaderSetting(
                    name: "Dot Mask Stagger",
                    key: "MASK_STAGGER",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.MASK_STAGGER },
                        set: { [unowned self] in self.uniforms.MASK_STAGGER = $0 }),
                    range: 0.0...100.0,
                    step: 1.0
                ),
                
                ShaderSetting(
                    name: "Dot Mask Size",
                    key: "MASK_SIZE",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.MASK_SIZE },
                        set: { [unowned self] in self.uniforms.MASK_SIZE = $0 }),
                    range: 1.0...100.0,
                    step: 1.0
                ),
                
                ShaderSetting(
                    name: "Scanline Strength",
                    key: "SCANLINE_STRENGTH",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.SCANLINE_STRENGTH },
                        set: { [unowned self] in self.uniforms.SCANLINE_STRENGTH = $0 }),
                    range: 0.0...1.0,
                    step: 0.05
                ),
                
                ShaderSetting(
                    name: "Scanline Minimum Beam Width",
                    key: "SCANLINE_BEAM_WIDTH_MIN",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MIN },
                        set: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MIN = $0 }),
                    range: 0.5...5.0,
                    step: 0.5
                ),
                
                ShaderSetting(
                    name: "Scanline Maximum Beam Width",
                    key: "SCANLINE_BEAM_WIDTH_MAX",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MAX },
                        set: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MAX = $0 }),
                    range: 0.5...5.0,
                    step: 0.5
                ),
                
                ShaderSetting(
                    name: "Scanline Minimum Brightness",
                    key: "SCANLINE_BEAM_WIDTH_MAX",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MAX },
                        set: { [unowned self] in self.uniforms.SCANLINE_BEAM_WIDTH_MAX = $0 }),
                    range: 0.0...1.0,
                    step: 0.05
                ),
                
                ShaderSetting(
                    name: "Scanline Maximum Brightness",
                    key: "SCANLINE_BRIGHT_MAX",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.SCANLINE_BRIGHT_MAX },
                        set: { [unowned self] in self.uniforms.SCANLINE_BRIGHT_MAX = $0 }),
                    range: 0.0...1.0,
                    step: 0.05
                ),
                
                ShaderSetting(
                    name: "Scanline Cutoff",
                    key: "SCANLINE_CUTOFF",
                    value: Binding(
                        get: { [unowned self] in self.uniforms.SCANLINE_CUTOFF },
                        set: { [unowned self] in self.uniforms.SCANLINE_CUTOFF = $0 }),
                    range: 1.0...1000.0,
                    step: 1.0
                ),
                
                ShaderSetting(
                    name: "Lanczos Filter",
                    key: "ENABLE_LANCZOS",
                    value: Binding(
                        get: { [unowned self] in Float(self.uniforms.ENABLE_LANCZOS) },
                        set: { [unowned self] in self.uniforms.ENABLE_LANCZOS = Int32($0) }),
                    range: nil,
                    step: 1.0
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
