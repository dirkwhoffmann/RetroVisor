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
final class ColorSplitShader: Shader {

    var kernel: Kernel!

    struct Uniforms {

        var COLOR_SPACE: Int32
        var FILTER: Int32

        var X_ENABLE: Int32
        var X_VALUE: Float

        var Y_ENABLE: Int32
        var Y_VALUE: Float

        var Z_ENABLE: Int32
        var Z_VALUE: Float

        static let defaults = Uniforms(

            COLOR_SPACE: 0,
            FILTER: 3,
            
            X_ENABLE: 0,
            X_VALUE: 0.5,

            Y_ENABLE: 0,
            Y_VALUE: 0.5,

            Z_ENABLE: 0,
            Z_VALUE: 0.5,
        )
    }

    var uniforms = Uniforms.defaults

    // Textures
    var src: MTLTexture!

    // Filters
    var resampler = ResampleFilter()
    var hsvFilter = ColorSplitFilter()

    init() {

        super.init(name: "Color Splitter")

        delegate = self
        
        settings = [

            Group(title: "Color Space", [

                ShaderSetting(
                    title: "Color Space",
                    items: [("RGB", 0), ("HSV", 1), ("YUV", 2), ("YIQ", 3)],
                    value: Binding(
                        key: "COLOR_SPACE",
                        get: { [unowned self] in Float(self.uniforms.COLOR_SPACE) },
                        set: { [unowned self] in self.uniforms.COLOR_SPACE = Int32($0) }),
                ),

                ShaderSetting(
                    title: "Channel Filter",
                    items: [("Extract 1", 0), ("Extract 2", 1), ("Extract 3", 2), ("Recombine", 3)],
                    value: Binding(
                        key: "FILTER",
                        get: { [unowned self] in Float(self.uniforms.FILTER) },
                        set: { [unowned self] in self.uniforms.FILTER = Int32($0) }),
                ),

                ShaderSetting(
                    title: "Red",
                    range: 0.0...1.0,
                    step: 0.01,
                    enable: Binding(
                        key: "X_ENABLE",
                        get: { [unowned self] in Float(self.uniforms.X_ENABLE) },
                        set: { [unowned self] in self.uniforms.X_ENABLE = Int32($0) }),
                    value: Binding(
                        key: "X_VALUE",
                        get: { [unowned self] in self.uniforms.X_VALUE },
                        set: { [unowned self] in self.uniforms.X_VALUE = $0 }),
                ),

                ShaderSetting(
                    title: "Green",
                    range: 0.0...1.0,
                    step: 0.01,
                    enable: Binding(
                        key: "Y_ENABLE",
                        get: { [unowned self] in Float(self.uniforms.Y_ENABLE) },
                        set: { [unowned self] in self.uniforms.Y_ENABLE = Int32($0) }),
                    value: Binding(
                        key: "Y_VALUE",
                        get: { [unowned self] in self.uniforms.Y_VALUE },
                        set: { [unowned self] in self.uniforms.Y_VALUE = $0 }),
                ),

                ShaderSetting(
                    title: "Blue",
                    range: 0.0...1.0,
                    step: 0.01,
                    enable: Binding(
                        key: "Z_ENABLE",
                        get: { [unowned self] in Float(self.uniforms.Z_ENABLE) },
                        set: { [unowned self] in self.uniforms.Z_ENABLE = Int32($0) }),
                    value: Binding(
                        key: "Z_VALUE",
                        get: { [unowned self] in self.uniforms.Z_VALUE },
                        set: { [unowned self] in self.uniforms.Z_VALUE = $0 }),
                ),
            ]),
        ]
    }

    override func activate() {

        super.activate()
        kernel = ColorSplitFilter(sampler: ShaderLibrary.linear)
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

        // Apply the color split filter
        kernel.apply(commandBuffer: commandBuffer,
                        textures: [src, output],
                        options: &uniforms,
                        length: MemoryLayout<PlaygroundUniforms>.stride)
    }
}

extension ColorSplitShader: ShaderDelegate {
    
    func isHidden(setting: ShaderSetting) -> Bool {
        
        switch setting.valueKey {
            
        case "X_VALUE", "Y_VALUE", "Z_VALUE":
            return uniforms.FILTER < 3
        default:
            return false
        }
    }
    
    func uniformsDidChange(setting: ShaderSetting) {
        
        if (setting.valueKey == "COLOR_SPACE") {

            let x = findSetting(key: "X_ENABLE")!
            let y = findSetting(key: "Y_ENABLE")!
            let z = findSetting(key: "Z_ENABLE")!

            print("COLOR SPACE")

            switch (setting.intValue) {
                
            case 0: x.title = "Red"; y.title = "Green"; z.title = "Blue"
            case 1: x.title = "Hue"; y.title = "Saturation"; z.title = "Value"
            case 2: x.title = "Luma"; y.title = "Chroma (U)"; z.title = "Chroma (Y)"
            case 3: x.title = "Luma"; y.title = "Chroma (I)"; z.title = "Chroma (Q)"
            default: x.title = "X"; y.title = "Y"; z.title = "Z"
            }
        }
    }
}
