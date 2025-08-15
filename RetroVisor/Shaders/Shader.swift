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

@MainActor
class Shader {

    static var device: MTLDevice { MTLCreateSystemDefaultDevice()! }
    
    var name: String = ""
    var settings: [ShaderSetting] = []

    var vertexDescriptor: MTLVertexDescriptor!
    var pipelineState: MTLRenderPipelineState!

    var passes: Int { return 1 }

    func activate() {

        fatalError("To be implemented by a subclass")
    }

    func activate(fragmentShader: String) {

        let device = MTLCreateSystemDefaultDevice()!

        print("Activating \(name)")

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

        // Load shaders from the default library
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertex_main")!
        let fragmentFunc = library.makeFunction(name: fragmentShader)!

        // Create the pipeline state
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    func retire() {

        print("Retiring \(name)")
    }

    func apply(commandBuffer: MTLCommandBuffer,
               in inTexture: MTLTexture, out outTexture: MTLTexture) {

        var vertexBuffer1: MTLBuffer! { app.windowController?.metalView?.vertexBuffer1! }
        var vertexBuffer2: MTLBuffer! { app.windowController?.metalView?.vertexBuffer2! }
        var linearSampler: MTLSamplerState! { app.windowController?.metalView?.linearSampler! }
        // var uniforms: Uniforms { app.windowController?.metalView?.uniforms! }

        let renderPass1 = MTLRenderPassDescriptor()
        renderPass1.colorAttachments[0].loadAction = .clear
        renderPass1.colorAttachments[0].storeAction = .store
        renderPass1.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        renderPass1.colorAttachments[0].texture = outTexture

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass1) {

            encoder.setVertexBuffer(vertexBuffer1, offset: 0, index: 0)
            encoder.setFragmentTexture(inTexture, index: 0)
            encoder.setFragmentSamplerState(linearSampler, index: 0)
            encoder.setFragmentBytes(&app.windowController!.metalView!.uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: 0)

            apply(to: encoder, pass: 1)

            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }
    }

    func get(key: String) -> Float { return 0 }
    func set(key: String, value: Float) {}
    func apply(to encoder: MTLRenderCommandEncoder, pass: Int = 1) { }
}
