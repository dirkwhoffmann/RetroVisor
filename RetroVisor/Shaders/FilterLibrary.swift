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

enum ResampleFilterType: Int32 {

    case bilinear = 0
    case lanczos = 1

    init?(_ rawValue: Float) { self.init(rawValue: Int32(rawValue)) }
}

@MainActor
class ResampleFilter {

    var type = ResampleFilterType.bilinear

    var bilinearFilter: MPSImageBilinearScale!
    var lanczosFilter: MPSImageLanczosScale!

    init() {

        bilinearFilter = MPSImageBilinearScale(device: ShaderLibrary.device)
        lanczosFilter = MPSImageLanczosScale(device: ShaderLibrary.device)
    }

    convenience init(type: ResampleFilterType) {

        self.init()
        self.type = type
    }

    func apply(commandBuffer: MTLCommandBuffer,
               in input: MTLTexture, out output: MTLTexture,
               rect: CGRect = .unity) {

        let filter = type == .bilinear ? bilinearFilter! : lanczosFilter!
        var transform = MPSScaleTransform.init(in: input, out: output, rect: rect)

        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in

            filter.scaleTransform = transformPtr
            filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
        }
    }
    
    func apply(commandBuffer: MTLCommandBuffer, in input: [MTLTexture], out output: [MTLTexture]) {

        for i in 0..<input.count {
            apply(commandBuffer: commandBuffer, in: input[i], out: output[i])
        }
    }
}

enum BlurFilterType: Int32 {

    case box = 0
    case tent = 1
    case gaussian = 2

    init?(_ rawValue: Float) { self.init(rawValue: Int32(rawValue)) }
    var floatValue: Float { return Float(self.rawValue) }
}

@MainActor
class BlurFilter {

    var blurType = BlurFilterType.box
    var blurSize = (Float(1.0), Float(1.0))
    
    var resampler = ResampleFilter(type: .bilinear)
    var resampleXY = (Float(1.0), Float(1.0))

    private var down: MTLTexture?
    private var blur: MTLTexture?

    convenience init (type: BlurFilterType, resampler: ResampleFilter) {

        self.init()
        self.blurType = type
        self.resampler = resampler
    }

    func updateTextures(in input: MTLTexture, out output: MTLTexture) {

        let W = Int(ceil(Float(input.width) * resampleXY.0))
        let H = Int(ceil(Float(input.height) * resampleXY.1))

        if down?.width != W || down?.height != H {

            down = output.makeTexture(width: W, height: H)
            blur = output.makeTexture(width: W, height: H)
        }
    }

    func apply(commandBuffer: MTLCommandBuffer, in input: MTLTexture, out output: MTLTexture) {

        var rw: Int { Int(blurSize.0) | 1 }
        var rh: Int { Int(blurSize.1) | 1 }
        var sigma: Float { blurSize.0 / 4.0 }

        func applyBlur(in input: MTLTexture, out output: MTLTexture) {

            switch blurType {
            case .box:
                let filter = MPSImageBox(device: output.device, kernelWidth: rw, kernelHeight: rh)
                filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
            case .tent:
                let filter = MPSImageTent(device: output.device, kernelWidth: rw, kernelHeight: rh)
                filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
            case .gaussian:
                let filter = MPSImageGaussianBlur(device: output.device, sigma: sigma)
                filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
            }
        }

        if resampleXY == (1.0,1.0) {

            // Apply blur without scaling
            applyBlur(in: input, out: output)

        } else {

            // Prepare intermediate textures
            updateTextures(in: input, out: output)
            
            // Downscale the input texture
            resampler.apply(commandBuffer: commandBuffer, in: input, out: down!)

            // Blur the downsampled texture
            applyBlur(in: down!, out: blur!)

            // Upscale the blurred texture
            resampler.apply(commandBuffer: commandBuffer, in: blur!, out: output)
        }
    }
    
    func apply(commandBuffer: MTLCommandBuffer, in input: [MTLTexture], out output: [MTLTexture]) {

        for i in 0..<input.count {
            apply(commandBuffer: commandBuffer, in: input[i], out: output[i])
        }
    }
}

extension MPSScaleTransform {

    init(in input: MTLTexture, out output: MTLTexture, rect: CGRect) {

        let scaleX = Double(output.width) / (rect.width * Double(input.width))
        let scaleY = Double(output.height) / (rect.height * Double(input.height))
        let transX = (-rect.minX * Double(input.width)) * scaleX
        let transY = (-rect.minY * Double(input.height)) * scaleY

        self.init(scaleX: scaleX, scaleY: scaleY, translateX: transX, translateY: transY)
    }
}

extension MPSImageScale {

    func encode(commandBuffer: any MTLCommandBuffer,
                sourceTexture: any MTLTexture, destinationTexture: any MTLTexture,
                rect: CGRect) {

        var transform = MPSScaleTransform.init(in: sourceTexture,
                                               out: destinationTexture,
                                               rect: rect)

        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in

            scaleTransform = transformPtr
            encode(commandBuffer: commandBuffer,
                   sourceTexture: sourceTexture,
                   destinationTexture: destinationTexture)
            scaleTransform = nil
        }
    }
}

@MainActor
class DilationFilter {
    
    var size = (3,3) { didSet { if size != oldValue { setupFilter() } } }
    
    private var filter: MPSImageDilate!
    private var values: [Float]!
    
    init() { setupFilter() }
    
    func setupFilter() {
        
        let W = size.0 | 1
        let H = size.1 | 1
        values = [Float](repeating: 0, count: W * H)
        
        filter = MPSImageDilate(device: ShaderLibrary.device,
                                kernelWidth: W, kernelHeight: H, values: values)
    }
    
    func apply(commandBuffer: MTLCommandBuffer, in input: MTLTexture, out output: MTLTexture) {
        
        filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
    }

    func apply(commandBuffer: MTLCommandBuffer, in input: [MTLTexture], out output: [MTLTexture]) {

        for i in 0..<input.count {
            apply(commandBuffer: commandBuffer, in: input[i], out: output[i])
        }
    }
}
