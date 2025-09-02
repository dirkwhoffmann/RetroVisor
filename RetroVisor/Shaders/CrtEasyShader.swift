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
    var crtUniforms: CrtUniforms = .defaults

    // Input texture passed to the CRTEasy kernel
    var src: MTLTexture!

    init() {

        super.init(name: "CrtEasy")

        settings = [

            ShaderSettingGroup(title: "Uniforms", [

                ShaderSetting(
                    name: "Brightness Boost",
                    key: "BRIGHT_BOOST",
                    range: 0.0...2.0,
                    step: 0.01,
                    help: nil
                ),

                ShaderSetting(
                    name: "Horizontal Sharpness",
                    key: "SHARPNESS_H",
                    range: 0.0...1.0,
                    step: 0.05,
                    help: nil
                ),

                ShaderSetting(
                    name: "Vertical Sharpness",
                    key: "SHARPNESS_V",
                    range: 0.0...1.0,
                    step: 0.05,
                    help: nil
                ),

                ShaderSetting(
                    name: "Dilation",
                    key: "DILATION",
                    range: 0.0...1.0,
                    step: 0.05,
                    help: nil
                ),

                ShaderSetting(
                    name: "Gamma Input",
                    key: "GAMMA_INPUT",
                    range: 0.1...5.0,
                    step: 0.1,
                    help: nil
                ),

                ShaderSetting(
                    name: "Gamma Output",
                    key: "GAMMA_OUTPUT",
                    range: 0.1...5.0,
                    step: 0.1,
                    help: nil
                ),

                ShaderSetting(
                    name: "Dot Mask Strength",
                    key: "MASK_STRENGTH",
                    range: 0.0...1.0,
                    step: 0.01,
                    help: nil
                ),

                ShaderSetting(
                    name: "Dot Mask Width",
                    key: "MASK_DOT_WIDTH",
                    range: 1.0...100.0,
                    step: 1.0,
                    help: nil
                ),

                ShaderSetting(
                    name: "Dot Mask Height",
                    key: "MASK_DOT_HEIGHT",
                    range: 1.0...100.0,
                    step: 1.0,
                    help: nil
                ),

                ShaderSetting(
                    name: "Dot Mask Stagger",
                    key: "MASK_STAGGER",
                    range: 0.0...100.0,
                    step: 1.0,
                    help: nil
                ),

                ShaderSetting(
                    name: "Dot Mask Size",
                    key: "MASK_SIZE",
                    range: 1.0...100.0,
                    step: 1.0,
                    help: nil
                ),

                ShaderSetting(
                    name: "Scanline Strength",
                    key: "SCANLINE_STRENGTH",
                    range: 0.0...1.0,
                    step: 0.05,
                    help: nil
                ),

                ShaderSetting(
                    name: "Scanline Minimum Beam Width",
                    key: "SCANLINE_BEAM_WIDTH_MIN",
                    range: 0.5...5.0,
                    step: 0.5,
                    help: nil
                ),

                ShaderSetting(
                    name: "Scanline Maximum Beam Width",
                    key: "SCANLINE_BEAM_WIDTH_MAX",
                    range: 0.5...5.0,
                    step: 0.5,
                    help: nil
                ),

                ShaderSetting(
                    name: "Scanline Minimum Brightness",
                    key: "SCANLINE_BRIGHT_MIN",
                    range: 0.0...1.0,
                    step: 0.05,
                    help: nil
                ),

                ShaderSetting(
                    name: "Scanline Maximum Brightness",
                    key: "SCANLINE_BRIGHT_MAX",
                    range: 0.0...1.0,
                    step: 0.05,
                    help: nil
                ),

                ShaderSetting(
                    name: "Scanline Cutoff",
                    key: "SCANLINE_CUTOFF",
                    range: 1.0...1000.0,
                    step: 1.0,
                    help: nil
                ),

                ShaderSetting(
                    name: "Lanczos Filter",
                    key: "ENABLE_LANCZOS",
                    range: nil,
                    step: 1.0,
                    help: nil
                ),
            ])
        ]
    }

    override func get(key: String, index: Int = 0) -> Float {

        switch key {
        case "BRIGHT_BOOST": return crtUniforms.BRIGHT_BOOST
        case "DILATION": return crtUniforms.DILATION
        case "GAMMA_INPUT": return crtUniforms.GAMMA_INPUT
        case "GAMMA_OUTPUT": return crtUniforms.GAMMA_OUTPUT
        case "MASK_SIZE": return crtUniforms.MASK_SIZE
        case "MASK_STAGGER": return crtUniforms.MASK_STAGGER
        case "MASK_STRENGTH": return crtUniforms.MASK_STRENGTH
        case "MASK_DOT_WIDTH": return crtUniforms.MASK_DOT_WIDTH
        case "MASK_DOT_HEIGHT": return crtUniforms.MASK_DOT_HEIGHT
        case "SCANLINE_BEAM_WIDTH_MAX": return crtUniforms.SCANLINE_BEAM_WIDTH_MAX
        case "SCANLINE_BEAM_WIDTH_MIN": return crtUniforms.SCANLINE_BEAM_WIDTH_MIN
        case "SCANLINE_BRIGHT_MAX": return crtUniforms.SCANLINE_BRIGHT_MAX
        case "SCANLINE_BRIGHT_MIN": return crtUniforms.SCANLINE_BRIGHT_MIN
        case "SCANLINE_CUTOFF": return crtUniforms.SCANLINE_CUTOFF
        case "SCANLINE_STRENGTH": return crtUniforms.SCANLINE_STRENGTH
        case "SHARPNESS_H": return crtUniforms.SHARPNESS_H
        case "SHARPNESS_V": return crtUniforms.SHARPNESS_V
        case "ENABLE_LANCZOS": return Float(crtUniforms.ENABLE_LANCZOS)

        default:
            NSSound.beep()
            return 0
        }
    }

    override func set(key: String, index: Int = 0, value: Float) {

        switch key {
        case "BRIGHT_BOOST": crtUniforms.BRIGHT_BOOST = value
        case "DILATION": crtUniforms.DILATION = value
        case "GAMMA_INPUT": crtUniforms.GAMMA_INPUT = value
        case "GAMMA_OUTPUT": crtUniforms.GAMMA_OUTPUT = value
        case "MASK_SIZE": crtUniforms.MASK_SIZE = value
        case "MASK_STAGGER": crtUniforms.MASK_STAGGER = value
        case "MASK_STRENGTH": crtUniforms.MASK_STRENGTH = value
        case "MASK_DOT_WIDTH": crtUniforms.MASK_DOT_WIDTH = value
        case "MASK_DOT_HEIGHT": crtUniforms.MASK_DOT_HEIGHT = value
        case "SCANLINE_BEAM_WIDTH_MAX": crtUniforms.SCANLINE_BEAM_WIDTH_MAX = value
        case "SCANLINE_BEAM_WIDTH_MIN": crtUniforms.SCANLINE_BEAM_WIDTH_MIN = value
        case "SCANLINE_BRIGHT_MAX": crtUniforms.SCANLINE_BRIGHT_MAX = value
        case "SCANLINE_BRIGHT_MIN": crtUniforms.SCANLINE_BRIGHT_MIN = value
        case "SCANLINE_CUTOFF": crtUniforms.SCANLINE_CUTOFF = value
        case "SCANLINE_STRENGTH": crtUniforms.SCANLINE_STRENGTH = value
        case "SHARPNESS_H": crtUniforms.SHARPNESS_H = value
        case "SHARPNESS_V": crtUniforms.SHARPNESS_V = value
        case "ENABLE_LANCZOS": crtUniforms.ENABLE_LANCZOS = Int32(value)

        default:
            NSSound.beep()
        }
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
                     options2: &crtUniforms,
                     length2: MemoryLayout<CrtUniforms>.stride)
    }
}
