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

protocol Shader {

    var id: String { get }
    var name: String { get }
    var settings: [ShaderSetting] { get }

    func setup(device: MTLDevice)
    func get(key: String) -> Float
    func set(key: String, value: Float)
    func apply(to encoder: MTLRenderCommandEncoder)
}
