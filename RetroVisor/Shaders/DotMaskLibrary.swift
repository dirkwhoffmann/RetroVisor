/// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit
import MetalPerformanceShaders

struct DotMaskDescriptor: Equatable {

    var type: Int32
    var cellWidth: Int32
    var cellHeight: Int32
    var brightness: Float
    var blur: Float
}

@MainActor
class DotMaskLibrary {

    var descriptor = DotMaskDescriptor(type: 0,
                                       cellWidth: 0,
                                       cellHeight: 0,
                                       brightness: 0.0,
                                       blur: 0.0)

    // GPU kernel
    var kernel: DotMaskFilter = DotMaskFilter(sampler: ShaderLibrary.linear)!

    var bilinearFilter: MPSImageBilinearScale!
    var lanczosFilter: MPSImageLanczosScale!

    init() {

    }

    func create(commandBuffer: MTLCommandBuffer,
                descriptor: DotMaskDescriptor,
                texture: inout MTLTexture) {

        // Exit if the texture is up to date
        if self.descriptor == descriptor { return }

        self.descriptor = descriptor

        let brightness = descriptor.brightness
        let type = Int(descriptor.type)
        // let blur = descriptor.blur

        let max  = UInt8(clamping: Int(85 + brightness * 170))
        let base = UInt8(clamping: Int((1 - brightness) * 85))
        let none = UInt8(clamping: Int(30 + (1 - brightness) * 55))

        let R = UInt32(r: max, g: base, b: base)
        let G = UInt32(r: base, g: max, b: base)
        let B = UInt32(r: base, g: base, b: max)
        let M = UInt32(r: max, g: base, b: max)
        let W = UInt32(r: max, g: max, b: max)
        let N = UInt32(r: none, g: none, b: none)

        /*
         let maskSize = [
         CGSize(width: 1, height: 1),
         CGSize(width: 3, height: 1),
         CGSize(width: 4, height: 2),
         CGSize(width: 3, height: 9),
         CGSize(width: 4, height: 8)
         ]
         */

        let maskData = [

            [ [ W ] ],

            [ [ M, G, N ],
              [ M, G, N ],
              [ M, G, N ] ],

            [ [ R, G, B, N ],
              [ R, G, B, N ],
              [ R, G, B, N ],
              [ R, G, B, N ] ],

            [ [ M, G, N ],
              [ M, G, N ],
              [ N, N, N ],
              [ N, M, G ],
              [ N, M, G ],
              [ N, N, N ],
              [ G, N, M ],
              [ G, N, M ],
              [ N, N, N ] ],

            [ [ R, G, B, N ],
              [ R, G, B, N ],
              [ R, G, B, N ],
              [ N, N, N, N ],
              [ B, N, R, G ],
              [ B, N, R, G ],
              [ B, N, R, G ],
              [ N, N, N, N ] ]
        ]

        // Create image representation in memory
        let mask = maskData[type]
        let height = mask.count
        let width = mask[0].count
        let maskSize = width * height
        let mem = calloc(maskSize, MemoryLayout<UInt32>.size)!
        let ptr = mem.bindMemory(to: UInt32.self, capacity: maskSize)
        for h in 0...height - 1 {
            for w in 0...width - 1 {
                ptr[h * width + w] = mask[h][w]
            }
        }

        // Create image
        let image = NSImage.make(data: mem, rect: CGSize(width: width, height: height))!

        // Convert image to texture
        let imageTexture = image.toTexture(device: ShaderLibrary.device)!

        // Create the dot mask texture
        kernel.apply(commandBuffer: commandBuffer,
                     source: imageTexture, target: texture,
                     options: &self.descriptor,
                     length: MemoryLayout<DotMaskDescriptor>.stride)

        // Blur the texture
        // let filter = MPSImageGaussianBlur(device: imageTexture.device, sigma: blur)
        // filter.encode(commandBuffer: commandBuffer, inPlaceTexture: &texture)
    }
}
