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

    var device: MTLDevice!
    var kernel: MTLComputePipelineState!

    // The rectangle the compute kernel is applied to
    var cutout = (256, 256)

    convenience init?(name: String, cutout: (Int, Int)) {

        self.init()

        self.device = ShaderLibrary.device
        self.cutout = cutout

        // Lookup kernel function in library
        guard let function = ShaderLibrary.library.makeFunction(name: name) else {
            print("Cannot find kernel function '\(name)' in library.")
            return nil
        }

        // Create kernel
        do {
            try kernel = device.makeComputePipelineState(function: function)
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
               options: UnsafeRawPointer? = nil, length: Int = 0) {

        if let encoder = commandBuffer.makeComputeCommandEncoder() {

            encoder.setTexture(source, index: 0)
            encoder.setTexture(target, index: 1)

            apply(encoder: encoder, width: target.width, height: target.height,
                  options: options, length: length)
        }
    }

    func apply(commandBuffer: MTLCommandBuffer, textures: [MTLTexture],
               options: UnsafeRawPointer? = nil, length: Int = 0) {

        if let encoder = commandBuffer.makeComputeCommandEncoder() {

            for (index, texture) in textures.enumerated() {
                encoder.setTexture(texture, index: index)
            }
            apply(encoder: encoder, width: textures.last!.width, height: textures.last!.height,
                  options: options, length: length)
        }
    }

    private func apply(encoder: MTLComputeCommandEncoder,
                       width: Int, height: Int,
                       options: UnsafeRawPointer?, length: Int) {

        // Bind pipeline
        encoder.setSamplerState(app.windowController!.metalView!.linearSampler, index: 0)
        encoder.setComputePipelineState(kernel)

        // Pass in shader options
        if let opt = options { encoder.setBytes(opt, length: length, index: 0) }

        // Choose a fixed, GPU-friendly group size
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)

        // Compute how many groups are needed (rounding up to cover all pixels)
        let threadgroupsPerGrid = MTLSize(
            width: (width  + threadsPerThreadgroup.width  - 1) / threadsPerThreadgroup.width,
            height: (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )

        // Dispatch
        encoder.dispatchThreadgroups(threadgroupsPerGrid,
                                     threadsPerThreadgroup: threadsPerThreadgroup)

        /*
        // Determine thread group size and number of groups
        let groupW = kernel.threadExecutionWidth
        let groupH = kernel.maxTotalThreadsPerThreadgroup / groupW
        let threadsPerGroup = MTLSizeMake(groupW, groupH, 1)

        let countW = (cutout.0) / groupW + 1
        let countH = (cutout.1) / groupH + 1
        let threadgroupCount = MTLSizeMake(countW, countH, 1)

        // Finally, we're ready to dispatch
        encoder.dispatchThreadgroups(threadgroupCount,
                                     threadsPerThreadgroup: threadsPerGroup)
        */
        encoder.endEncoding()
    }
}

//
// Bypass filter
//

class BypassFilter: Kernel {

    convenience init?(cutout: (Int, Int)) {
        self.init(name: "bypass", cutout: cutout)
    }
}
