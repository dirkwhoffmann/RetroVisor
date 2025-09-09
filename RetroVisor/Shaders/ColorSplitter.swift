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
final class ColorSplitter: Shader {

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

    override func revertToPreset(nr: Int) {
        
        uniforms = Uniforms.defaults
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
        // resampler.apply(commandBuffer: commandBuffer, in: input, out: src, rect: rect)

        src = input
        
        // Apply the color split filter
        kernel.apply(commandBuffer: commandBuffer,
                        textures: [src, output],
                        options: &uniforms,
                        length: MemoryLayout<Uniforms>.stride)
    }
}

extension ColorSplitter: ShaderDelegate {
    
    func title(setting: ShaderSetting) -> String {
     
        let x = [ "Red",    "Hue",         "Luma",        "Luma"       ]
        let y = [ "Green",  "Saturation",  "Chroma (U)",  "Chroma (I)" ]
        let z = [ "Blue",   "Value",       "Chroma (V)",  "Chroma (Q)" ]

        let i = max(0, min(Int(uniforms.COLOR_SPACE), 3));
        
        switch setting.valueKey {
            
        case "X_VALUE": return x[i]
        case "Y_VALUE": return y[i]
        case "Z_VALUE": return z[i]

        default:
            return setting.title
        }
    }
    
    func isHidden(setting: ShaderSetting) -> Bool {
        
        switch setting.valueKey {
            
        case "X_VALUE", "Y_VALUE", "Z_VALUE":
            return uniforms.FILTER < 3
        default:
            return false
        }
    }
}

extension ColorSplitter {
    
    class ColorSplitFilter: Kernel {

        convenience init?(sampler: MTLSamplerState) {

            self.init(name: "colorsplit::splitter", sampler: sampler)
        }
    }
}
