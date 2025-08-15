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
    private(set) var shaders: [Shader] = []

    var currentShader: Shader {
        didSet {
            print("Setting current shader")
            if currentShader !== oldValue {
                print("Retiring \(oldValue.id ?? -1)")
                oldValue.retire()
                print("Activating \(currentShader.id ?? -1)")
                currentShader.activate()
            }
        }
    }

    var count: Int { shaders.count }

    private init() {

        // Add the passthrough shader as a fallback
        shaders.append(PassthroughShader())
        currentShader = shaders[0]
    }

    func register(_ shader: Shader) {

        shaders.append(shader)
    }

    /*
    func shader(for id: String) -> Shader? {
        return shaders.first { $0.id == id }
    }
    */

    func shader(at index: Int) -> Shader? {
        guard index >= 0 && index < shaders.count else { return nil }
        return shaders[index]
    }

    func selectShader(at index: Int) {
        currentShader = shader(at: index) ?? shaders[0]
    }
}

extension Shader {

    var id: Int? {
        ShaderLibrary.shared.shaders.firstIndex { $0 === self }
    }
}
