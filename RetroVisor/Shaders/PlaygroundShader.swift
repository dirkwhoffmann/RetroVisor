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

// This shader is my personal playground for developing self-made CRT effects.

struct PlaygroundUniforms {

    var PAL: Int32
    var INPUT_PIXEL_SIZE: Float
    var CHROMA_RADIUS: Float
    var PAL_BLEND: Float
    var CHROMA_GAIN: Float

    var BRIGHTNESS: Float
    var GLOW: Float
    var GRID_WIDTH: Float
    var GRID_HEIGHT: Float
    var MIN_DOT_WIDTH: Float
    var MAX_DOT_WIDTH: Float
    var MIN_DOT_HEIGHT: Float
    var MAX_DOT_HEIGHT: Float
    var SHAPE: Float
    var FEATHER: Float

    static let defaults = PlaygroundUniforms(

        PAL: 0,
        INPUT_PIXEL_SIZE: 2,
        CHROMA_RADIUS: 1.3,
        PAL_BLEND: 0.4,
        CHROMA_GAIN: 1.0,

        BRIGHTNESS: 1,
        GLOW: 1,
        GRID_WIDTH: 20,
        GRID_HEIGHT: 20,
        MIN_DOT_WIDTH: 1,
        MAX_DOT_WIDTH: 10,
        MIN_DOT_HEIGHT: 1,
        MAX_DOT_HEIGHT: 10,
        SHAPE: 2.0,
        FEATHER: 0.2
    )
}

@MainActor
final class PlaygroundShader: Shader {

    var pass1: Kernel!
    var pass2: Kernel!
    var smoothPass: Kernel!
    var uniforms: PlaygroundUniforms = .defaults

    var image: MTLTexture!

    var luma: MTLTexture!
    var ycc: MTLTexture!
    var source: MTLTexture!
    var blur: MTLTexture!

    var texRect: SIMD4<Float> { app.windowController!.metalView!.uniforms.texRect }

    var transform = MPSScaleTransform.init() // scaleX: 1.5, scaleY: 1.5, translateX: 0.0, translateY: 0.0)

    init() {

        super.init(name: "Dirk's Playground")

        settings = [

            ShaderSetting(
                name: "Video Standard",
                key: "PAL",
                values: [("PAL", 1), ("NTSC", 0)]
            ),

            /*
            ShaderSetting(
                name: "Input Width",
                key: "INPUT_WIDTH",
                optional: true,
                range: 128...1280,
                step: 1
            ),
             */
            ShaderSetting(
                name: "Chroma Radius",
                key: "CHROMA_RADIUS",
                range: 1...10,
                step: 1
            ),

            ShaderSetting(
                name: "Input Pixel Size",
                key: "INPUT_PIXEL_SIZE",
                optional: true,
                range: 1...16,
                step: 1
            ),

            ShaderSetting(
                name: "PAL Blend",
                key: "PAL_BLEND",
                range: 0.0...2.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Chroma Gain",
                key: "CHROMA_GAIN",
                range: 0.1...20.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Brightness",
                key: "BRIGHTNESS",
                range: 0.0...2.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Glow",
                key: "GLOW",
                range: 0.0...2.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Grid Width",
                key: "GRID_WIDTH",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Grid Height",
                key: "GRID_HEIGHT",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Minimal Dot Width",
                key: "MIN_DOT_WIDTH",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Maximal Dot Width",
                key: "MAX_DOT_WIDTH",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Minimal Dot Height",
                key: "MIN_DOT_HEIGHT",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Maximal Dot Height",
                key: "MAX_DOT_HEIGHT",
                range: 1.0...60.0,
                step: 1.0
            ),

            ShaderSetting(
                name: "Phospor Shape",
                key: "SHAPE",
                range: 1.0...10.0,
                step: 0.01
            ),

            ShaderSetting(
                name: "Phosphor Feather",
                key: "FEATHER",
                range: 0.0...1.0,
                step: 0.01
            )
        ]
    }

    override func get(key: String) -> Float {

        switch key {
        case "PAL": return Float(uniforms.PAL)
        case "INPUT_PIXEL_SIZE": return uniforms.INPUT_PIXEL_SIZE
        case "CHROMA_RADIUS": return uniforms.CHROMA_RADIUS
        case "PAL_BLEND": return uniforms.PAL_BLEND
        case "CHROMA_GAIN": return uniforms.CHROMA_GAIN

        case "BRIGHTNESS": return uniforms.BRIGHTNESS
        case "GLOW": return uniforms.GLOW
        case "GRID_WIDTH": return uniforms.GRID_WIDTH
        case "GRID_HEIGHT": return uniforms.GRID_HEIGHT
        case "MIN_DOT_WIDTH": return uniforms.MIN_DOT_WIDTH
        case "MAX_DOT_WIDTH": return uniforms.MAX_DOT_WIDTH
        case "MIN_DOT_HEIGHT": return uniforms.MIN_DOT_HEIGHT
        case "MAX_DOT_HEIGHT": return uniforms.MAX_DOT_HEIGHT
        case "SHAPE": return uniforms.SHAPE
        case "FEATHER": return uniforms.FEATHER

        default:
            NSSound.beep()
            return 0
        }
    }

    override func set(key: String, value: Float) {

        switch key {
        case "PAL": uniforms.PAL = Int32(value)
        case "INPUT_PIXEL_SIZE": uniforms.INPUT_PIXEL_SIZE = value
        case "CHROMA_RADIUS": uniforms.CHROMA_RADIUS = value
        case "PAL_BLEND": uniforms.PAL_BLEND = value
        case "CHROMA_GAIN": uniforms.CHROMA_GAIN = value

        case "BRIGHTNESS": uniforms.BRIGHTNESS = value
        case "GLOW": uniforms.GLOW = value
        case "GRID_WIDTH": uniforms.GRID_WIDTH = value
        case "GRID_HEIGHT": uniforms.GRID_HEIGHT = value
        case "MIN_DOT_WIDTH": uniforms.MIN_DOT_WIDTH = value
        case "MAX_DOT_WIDTH": uniforms.MAX_DOT_WIDTH = value
        case "MIN_DOT_HEIGHT": uniforms.MIN_DOT_HEIGHT = value
        case "MAX_DOT_HEIGHT": uniforms.MAX_DOT_HEIGHT = value
        case "SHAPE": uniforms.SHAPE = value
        case "FEATHER": uniforms.FEATHER = value

        default:
            NSSound.beep()
        }
    }

    override func activate() {

        super.activate()
        pass1 = PlaygroundKernel1(sampler: ShaderLibrary.linear)
        pass2 = PlaygroundKernel2(sampler: ShaderLibrary.linear)
        smoothPass = SmoothChroma(sampler: ShaderLibrary.linear)
    }

    func crop(commandBuffer: MTLCommandBuffer, input: MTLTexture, output: MTLTexture, rect: CGRect) {

        let scaleX = Double(output.width) / (Double(rect.width) * Double(input.width))
        let scaleY = Double(output.height) / (Double(rect.height) * Double(input.height))
        let transX = (-Double(rect.minX) * Double(input.width)) * scaleX
        let transY = (-Double(rect.minY) * Double(input.height)) * scaleY

        // let filter = MPSImageLanczosScale(device: PlaygroundShader.device)
        let filter = MPSImageBilinearScale(device: PlaygroundShader.device)

        var transform = MPSScaleTransform(scaleX: scaleX,
                                          scaleY: scaleY,
                                          translateX: transX,
                                          translateY: transY)

        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in
            filter.scaleTransform = transformPtr
            filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
        }
    }


    override func apply(commandBuffer: MTLCommandBuffer,
                        in inTexture: MTLTexture, out outTexture: MTLTexture) {

        // Get the effect window size
        let width = outTexture.width
        let height = outTexture.height

        // Estimate the size of the retro image under the effect window
        let inputWidth = width / Int(uniforms.INPUT_PIXEL_SIZE)
        let inputHeight = height / Int(uniforms.INPUT_PIXEL_SIZE)

        // Create helper textures if needed
        if ycc?.width != inputWidth || ycc?.height != inputHeight {

            print("Creating textures of size \(inputWidth) x \(inputHeight)")
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: outTexture.pixelFormat,
                width: inputWidth,
                height: inputHeight,
                mipmapped: false
            )
            desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
            ycc = outTexture.device.makeTexture(descriptor: desc)
            luma = outTexture.device.makeTexture(descriptor: desc)
            source = outTexture.device.makeTexture(descriptor: desc)
            blur = outTexture.device.makeTexture(descriptor: desc)
            image = outTexture.device.makeTexture(descriptor: desc)
        }

        //
        // Pass 1: Crop and downsample the input area
        //

        let tr = app.windowController!.metalView!.uniforms.texRect

        let rect = CGRect(x: CGFloat(tr.x),
                          y: CGFloat(tr.y),
                          width: CGFloat(tr.z - tr.x),
                          height: CGFloat(tr.w - tr.y))

        crop(commandBuffer: commandBuffer, input: inTexture, output: source, rect: rect)


        //
        // Pass 2: Convert RGB to YUV or YIQ
        //

        /*
        pass1.apply(commandBuffer: commandBuffer,
                    textures: [source, ycc],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)
         */

        //
        // Pass 2: Low-pass filter the chroma channels
        //

        /*
        let kernelWidth = Int(4 * uniforms.CHROMA_RADIUS) | 1
        let kernelHeight = 1
        let blurFilter = MPSImageBox(device: PlaygroundShader.device,
                               kernelWidth: kernelWidth, kernelHeight: kernelHeight)
        blurFilter.encode(commandBuffer: commandBuffer, sourceTexture: ycc, destinationTexture: blur)

         */

        //
        // Pass 2: Apply edge compensation
        //

        /*
        smoothPass.apply(commandBuffer: commandBuffer,
                    textures: [ycc, blur, source, image],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)
        */
        // blur = chroma;

        //
        // Pass 3: Emulate CRT artifacts
        //


        pass2.apply(commandBuffer: commandBuffer,
                    textures: [source, outTexture],
                    options: &app.windowController!.metalView!.uniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    options2: &uniforms,
                    length2: MemoryLayout<PlaygroundUniforms>.stride)

    }
}
