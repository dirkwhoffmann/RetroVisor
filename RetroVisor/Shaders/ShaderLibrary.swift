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

/* `ShaderLibrary` is the central hub for all available GPU shaders.
 * It maintains an ordered list of `Shader` instances that can be queried by
 * index. It is responsible for providing the currently selected shader to the
 * rendering pipeline and serves as a registry for all shaders the application
 * supports.
 *
 *   - The `shared` singleton instance is the primary global access point
 *     for retrieving, adding, and managing shaders.
 *
 *   - The `passthroughShader` is always stored in the library and acts as a
 *     guaranteed fallback. It is returned whenever a requested shader is
 *     unavailable or an effect should be disabled.
 */

@MainActor
final class ShaderLibrary {

    // static let shared = ShaderLibrary()
    static let shared: ShaderLibrary = {
          
        let lib = ShaderLibrary()
        lib.register(Phosbite())
        lib.register(CRTEasy())
        // lib.register(ColorFilter())
        lib.register(ColorSplitter())
        lib.selectShader(at: 0)
        return lib
    }()
    
    static let lanczos = LanczosShader()
    static let bilinear = BilinearShader()

    static let device: MTLDevice = {
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal device not available")
            }
            return device
        }()

    static let library: MTLLibrary = {
            guard let lib = device.makeDefaultLibrary() else {
                fatalError("Could not load default Metal library")
            }
            return lib
        }()

    static var linear: MTLSamplerState = {
        let desc = MTLSamplerDescriptor()
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.mipFilter = .notMipmapped
        desc.sAddressMode = .repeat
        desc.tAddressMode = .repeat
        return device.makeSamplerState(descriptor: desc)!
    }()

     static var nearest: MTLSamplerState = {
         let desc = MTLSamplerDescriptor()
         desc.minFilter = .nearest
         desc.magFilter = .nearest
         desc.mipFilter = .notMipmapped
         desc.sAddressMode = .repeat
         desc.tAddressMode = .repeat
         return device.makeSamplerState(descriptor: desc)!
     }()

    static var mipmapLinear: MTLSamplerState = {
        let desc = MTLSamplerDescriptor()
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.mipFilter = .linear
        desc.sAddressMode = .clampToEdge
        desc.tAddressMode = .clampToEdge
        return device.makeSamplerState(descriptor: desc)!
    }()

    // The shader library
    private(set) var shaders: [Shader] = []

    var currentShader: Shader {
        didSet {
            if currentShader !== oldValue {
                oldValue.retire()
                currentShader.activate()
            }
        }
    }

    var count: Int { shaders.count }

    private init() {

        print ("ShaderLibrary: init")
        shaders.append(Passthrough())
        currentShader = shaders[0]
    }

    func register(_ shader: Shader) {

        shaders.append(shader)
    }

    func shader(at index: Int) -> Shader? {

        guard index >= 0 && index < shaders.count else { return nil }
        return shaders[index]
    }

    func selectShader(at index: Int) {

        currentShader = shader(at: index) ?? shaders[0]
    }
}

extension Shader {

    var id: Int? { ShaderLibrary.shared.shaders.firstIndex { $0 === self } }
}
