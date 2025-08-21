// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

@MainActor
final class PassthroughShader: Shader {

    struct Uniforms {

        var SCALER: Int32
        var INPUT_PIXEL_SIZE: Float

        static let defaults = Uniforms(

            SCALER: 0,
            INPUT_PIXEL_SIZE: 1
        )
    }

    var uniforms = Uniforms.defaults

    // Downscaled input texture
    var src: MTLTexture!

    init() {

        super.init(name: "Passthrough")

        settings = [

            ShaderSetting(
                name: "Scaler",
                key: "SCALER",
                values: [("BILINEAR", 0), ("LANCZOS", 1)]
            ),

            ShaderSetting(
                name: "Input Pixel Size",
                key: "INPUT_PIXEL_SIZE",
                optional: true,
                range: 1...16,
                step: 1
            )
        ]
    }

    override func get(key: String) -> Float {

        switch key {

        case "SCALER":              return Float(uniforms.SCALER)
        case "INPUT_PIXEL_SIZE":    return uniforms.INPUT_PIXEL_SIZE

        default:
            return super.get(key: key)
        }
    }

    override func set(key: String, value: Float) {

        switch key {

        case "SCALER":              uniforms.SCALER = Int32(value)
        case "INPUT_PIXEL_SIZE":    uniforms.INPUT_PIXEL_SIZE = value

        default:
            super.set(key: key, value: value)
        }
    }

    func updateTextures(in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        let inpWidth = output.width / Int(uniforms.INPUT_PIXEL_SIZE)
        let inpHeight = output.height / Int(uniforms.INPUT_PIXEL_SIZE)

        if src?.width != inpWidth || src?.height != inpHeight {

            print("Creating downscaled textures (\(inpWidth) x \(inpHeight))...")
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

        let scaler = uniforms.SCALER == 0 ? ShaderLibrary.bilinear :  ShaderLibrary.lanczos

        if uniforms.INPUT_PIXEL_SIZE != 1 {

            updateTextures(in: input, out: output, rect: rect)

            // Rescale to the source texture size
            scaler.apply(commandBuffer: commandBuffer, in: input, out: src, rect: rect)

            // Rescale to the output texture size
            scaler.apply(commandBuffer: commandBuffer, in: src, out: output)

        } else {

            // Rescale the output texture size
            scaler.apply(commandBuffer: commandBuffer, in: input, out: output, rect: rect)
        }
    }
}
