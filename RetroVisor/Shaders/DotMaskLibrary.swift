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
    var color: Int32
    var cellWidth: Int32
    var cellHeight: Int32
    var saturation: Float
    var brightness: Float
    var blur: Float
}

@MainActor
class DotMaskLibrary {
    
    var descriptor = DotMaskDescriptor(type: 0,
                                       color: 0,
                                       cellWidth: 0,
                                       cellHeight: 0,
                                       saturation: 0.0,
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
        
        let s = Double(descriptor.saturation)
        let b = Double(descriptor.brightness)
        let type = Int(descriptor.type)
        
        
        let R = UInt32(color: NSColor(hue: 0.0, saturation: s, brightness: 1.0, alpha: 1.0))
        let G = UInt32(color: NSColor(hue: 0.333, saturation: s, brightness: 1.0, alpha: 1.0))
        let B = UInt32(color: NSColor(hue: 0.666, saturation: s, brightness: 1.0, alpha: 1.0))
        let M = UInt32(color: NSColor(hue: 0.833, saturation: s, brightness: 1.0, alpha: 1.0))
        let N = UInt32(color: NSColor(red: b, green: b, blue: b, alpha: 1.0))
        
        let maskData = [
            [ apertureGrille(M, G, N), apertureGrille(R, G, B, N) ],
            [ slotMask      (M, G, N),       slotMask(R, G, B, N) ],
            [ shadowMask    (M, G, N),     shadowMask(R, G, B, N) ]
        ]
        
        // Create image representation in memory
        let mask = maskData[Int(descriptor.type)][Int(descriptor.color)]
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

extension DotMaskLibrary {
    
    func apertureGrille(_ M: UInt32, _ G: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ M, G, N ],
          [ M, G, N ] ]
    }
    
    func apertureGrille(_ R: UInt32, _ G: UInt32, _ B: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ R, G, B, N ],
          [ R, G, B, N ],
          [ R, G, B, N ],
          [ R, G, B, N ] ]
    }

    func shadowMask(_ M: UInt32, _ G: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ M, G, N ],
          [ M, G, N ],
          [ N, N, N ],
          [ N, M, G ],
          [ N, M, G ],
          [ N, N, N ],
          [ G, N, M ],
          [ G, N, M ],
          [ N, N, N ] ]
    }

    func shadowMask(_ R: UInt32, _ G: UInt32, _ B: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ R, G, B, N ],
          [ R, G, B, N ],
          [ R, G, B, N ],
          [ N, N, N, N ],
          [ B, N, R, G ],
          [ B, N, R, G ],
          [ B, N, R, G ],
          [ N, N, N, N ] ]
    }
    
    func slotMask(_ M: UInt32, _ G: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ M, G, N, M, G, N ],
          [ M, G, N, N, N, N ],
          [ M, G, N, M, G, N ],
          [ N, N, N, M, G, N ] ]
    }
    
    func slotMask(_ R: UInt32, _ G: UInt32, _ B: UInt32, _ N: UInt32) -> [[UInt32]] {
        
        [ [ R, G, B, N, R, G, B, N ],
          [ R, G, B, N, R, G, B, N ],
          [ R, G, B, N, N, N, N, N ],
          [ R, G, B, N, R, G, B, N ],
          [ R, G, B, N, R, G, B, N ],
          [ N, N, N, N, R, G, B, N ] ]
    }
}
