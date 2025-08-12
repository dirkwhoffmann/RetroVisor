// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

struct Shadowed<T> {

    var rawValue: T
    var shadowed: Bool
    var value: T? {
        get { shadowed ? nil : rawValue }
        set { if let newValue = newValue { rawValue = newValue } }
    }

    init(_ value: T, shadowed: Bool = false) {

        self.rawValue = value
        self.shadowed = shadowed
    }
}
