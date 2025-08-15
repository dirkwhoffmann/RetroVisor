// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

// This shader is my personal playground for developing self-made CRT effects.

final class SecretShader: Shader {

    override init() {

        super.init()

        name = "Secret"
    }

    var pipelineState: MTLRenderPipelineState!

    override func get(key: String) -> Float { return 0 }
    override func set(key: String, value: Float) { }

    override func activate() {

        super.activate()
        
        let device = MTLCreateSystemDefaultDevice()!

        // Load shaders from the default library
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexFunc = defaultLibrary.makeFunction(name: "vertex_main")!
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_secret")!

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
