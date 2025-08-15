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

    var pipelineState2: MTLRenderPipelineState!

    override init() {

        super.init()

        name = "Secret"
    }

    override func get(key: String) -> Float { return 0 }
    override func set(key: String, value: Float) { }

    override var passes: Int { return 2 }

    override func activate() {

        super.activate(fragmentShader: "fragment_secret")

        // Create a second pipeline state
        let device = MTLCreateSystemDefaultDevice()!
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexFunc = defaultLibrary.makeFunction(name: "vertex_main")!
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_secret2")!

        // Create the pipeline state
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState2 = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    override func apply(to encoder: MTLRenderCommandEncoder, pass: Int = 1) {

        switch pass {

        case 1:
            encoder.setRenderPipelineState(pipelineState)

        case 2:
            encoder.setRenderPipelineState(pipelineState2)

        default:
            break
        }
    }
}
