// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit

@MainActor
final class PassthroughShader: Shader {

    var passthrough: Kernel!

    override init() {

        super.init()

        name = "Passthrough"
    }

    override func get(key: String) -> Float { return 0 }
    override func set(key: String, value: Float) { }

    override func activate() {

        super.activate(fragmentShader: "fragment_bypass")
        passthrough = BypassFilter(sampler: ShaderLibrary.linear)
    }

    override func apply(to encoder: MTLRenderCommandEncoder, pass: Int = 1) {

        switch pass {

        case 1:
            encoder.setRenderPipelineState(pipelineState)

        default:
            break
        }
    }
}
