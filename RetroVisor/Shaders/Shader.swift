// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

struct ShaderSetting {

    let name: String
    let key: String
    let range: ClosedRange<Double>?
    let step: Float
    let help: String?

    var formatString: String {
        return step < 0.1 ? "%.2f" : step < 1.0 ? "%.1f" : "%.0f"
    }
}

class Shader {

    var name: String = ""
    var settings: [ShaderSetting] = []

    var vertexDescriptor: MTLVertexDescriptor!

    func activate() {

        // Setup a vertex descriptor
        vertexDescriptor = MTLVertexDescriptor()

        // Single interleaved buffer
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex

        // Positions
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // Texture coordinates
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0

        print("Activating \(name)")
    }

    func retire() {

        print("Retiring \(name)")
    }

    func get(key: String) -> Float { return 0 }
    func set(key: String, value: Float) {}
    func apply(to encoder: MTLRenderCommandEncoder) {}
}
