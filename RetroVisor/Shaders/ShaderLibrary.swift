// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

final class ShaderLibrary {

    static let shared = ShaderLibrary()
    private var shaders: [String: Shader] = [:]

    private init() {}

    func register(_ shader: Shader) {
        shaders[shader.id] = shader
    }

    func shader(for id: String) -> Shader? {
        shaders[id]
    }

    var allShaders: [Shader] {
        Array(shaders.values)
    }
}
