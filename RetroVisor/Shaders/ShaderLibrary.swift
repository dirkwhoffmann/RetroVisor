// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

/* `ShaderLibrary` is the central hub for all available GPU shaders.
 * It maintains an ordered list of `Shader` instances that can be queried by
 * index. It is responsible for providing the currently selected shader to the
 * rendering pipeline and serves as a registry for all shaders the application
 * supports.
 *
 *   - The `shared` singleton instance is the primary global access point
 *     for retrieving, adding, and managing shaders.
 *
 *   - The `passthroughShader` is always stored in the library and acts as a
 *     guaranteed fallback. It is returned whenever a requested shader is
 *     unavailable or an effect should be disabled.
 */
final class ShaderLibrary {

    static let shared = ShaderLibrary()
    private(set) var shaders: [Shader] = []

    var currentShader: Shader {
        didSet {
            if currentShader !== oldValue {
                oldValue.retire()
                currentShader.activate()
            }
        }
    }

    var count: Int { shaders.count }

    private init() {

        shaders.append(PassthroughShader())
        currentShader = shaders[0]
    }

    func register(_ shader: Shader) {

        shaders.append(shader)
    }

    func shader(at index: Int) -> Shader? {

        guard index >= 0 && index < shaders.count else { return nil }
        return shaders[index]
    }

    func selectShader(at index: Int) {

        currentShader = shader(at: index) ?? shaders[0]
    }
}

extension Shader {

    var id: Int? { ShaderLibrary.shared.shaders.firstIndex { $0 === self } }
}
