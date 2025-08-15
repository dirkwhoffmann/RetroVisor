// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

final class PassthroughShader: Shader {

    override init() {

        super.init()
        
        name = "Passthrough"
    }

    var pipelineState: MTLRenderPipelineState!

    override func get(key: String) -> Float { return 0 }
    override func set(key: String, value: Float) { }

    override func activate() {

        print("Activating passthrough shader")
        let device = MTLCreateSystemDefaultDevice()
        setup(device: device!)
    }

    override func retire() {

        print("Retiring passthrough shader")
    }

    override func setup(device: MTLDevice) {

        // Setup a vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()

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

        // Load shaders from the default library
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexFunc = defaultLibrary.makeFunction(name: "vertex_main")!
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_bypass")!

        // Create the pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    override func apply(to encoder: MTLRenderCommandEncoder) {

        encoder.setRenderPipelineState(pipelineState)
    }
}
