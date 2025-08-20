// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Metal
import MetalKit

//
// Base class for all compute kernels
//

@MainActor
class Kernel {

    var kernel: MTLComputePipelineState!
    var sampler: MTLSamplerState?

    convenience init?(name: String, sampler: MTLSamplerState? = nil) {

        self.init()

        self.sampler = sampler

        // Lookup kernel function in library
        guard let function = ShaderLibrary.library.makeFunction(name: name) else {
            print("Cannot find kernel function '\(name)' in library.")
            return nil
        }

        // Create kernel
        do {
            try kernel = ShaderLibrary.device.makeComputePipelineState(function: function)
        } catch {
            print("Cannot create compute kernel '\(name)'.")
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.icon = NSImage(named: "metal")
            alert.messageText = "Failed to create compute kernel."
            alert.informativeText = "Kernel '\(name)' will be ignored when selected."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return nil
        }
    }

    func apply(commandBuffer: MTLCommandBuffer,
               source: MTLTexture, target: MTLTexture,
               options: UnsafeRawPointer? = nil, length: Int = 0,
               options2: UnsafeRawPointer? = nil, length2: Int = 0) {

        if let encoder = commandBuffer.makeComputeCommandEncoder() {

            encoder.setTexture(source, index: 0)
            encoder.setTexture(target, index: 1)

            apply(encoder: encoder, width: target.width, height: target.height,
                  options: options, length: length,
                  options2: options2, length2: length2)
        }
    }

    func apply(commandBuffer: MTLCommandBuffer, textures: [MTLTexture],
               options: UnsafeRawPointer? = nil, length: Int = 0,
               options2: UnsafeRawPointer? = nil, length2: Int = 0) {

        if let encoder = commandBuffer.makeComputeCommandEncoder() {

            for (index, texture) in textures.enumerated() {
                encoder.setTexture(texture, index: index)
            }
            apply(encoder: encoder, width: textures.last!.width, height: textures.last!.height,
                  options: options, length: length,
                  options2: options2, length2: length2)
        }
    }

    private func apply(encoder: MTLComputeCommandEncoder,
                       width: Int, height: Int,
                       options: UnsafeRawPointer?, length: Int = 0,
                       options2: UnsafeRawPointer?, length2: Int = 0) {

        // Select sampler
        encoder.setSamplerState(sampler ?? ShaderLibrary.linear, index: 0)

        // Bind pipeline
        encoder.setComputePipelineState(kernel)

        // Pass in shader options
        if let opt = options { encoder.setBytes(opt, length: length, index: 0) }
        if let opt2 = options2 { encoder.setBytes(opt2, length: length2, index: 1) }

        // Choose a fixed, GPU-friendly group size
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)

        // Compute how many groups are needed (rounding up to cover all pixels)
        let threadgroupsPerGrid = MTLSize(
            width: (width + threadsPerThreadgroup.width  - 1) / threadsPerThreadgroup.width,
            height: (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )

        // Dispatch
        encoder.dispatchThreadgroups(threadgroupsPerGrid,
                                     threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
    }
}

//
// Passthrough kernel
//

class BypassFilter: Kernel {

    convenience init?(sampler: MTLSamplerState) {

        self.init(name: "bypass", sampler: sampler)
    }
}

//
// CrtEasy kernel
//

class CrtEasyKernel: Kernel {

    convenience init?(sampler: MTLSamplerState) {

        self.init(name: "crtEasy", sampler: sampler)
    }
}


//
// My personal playground. Nothing to see here. Move on.
//

class ColorSpaceFilter: Kernel {

    convenience init?(sampler: MTLSamplerState) {

        self.init(name: "playground::colorSpace", sampler: sampler)
    }
}

class CompositeFilter: Kernel {

    convenience init?(sampler: MTLSamplerState) {

        self.init(name: "playground::composite", sampler: sampler)
    }
}

class CrtFilter: Kernel {

    convenience init?(sampler: MTLSamplerState) {

        self.init(name: "playground::crt", sampler: sampler)
    }
}

