// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

struct Animated<T: BinaryFloatingPoint> {
    
    var current: T
    var delta: T = 0
    var steps: Int = 1 { didSet { delta = (target - current) / T(steps == 0 ? 1 : steps) } }
    var target: T { didSet { delta = (target - current) / T(steps == 0 ? 1 : steps) } }
    var animates: Bool { current != target }
    var clamped: T { min(max(current, 0), 1) }

    init(current: T = 0, target: T = 0) {

        self.current = current
        self.target = target
    }
    
    init(_ value: T) {

        self.init(current: value, target: value)
    }
    
    mutating func set(_ value: T) {

        self.current = value
        self.target = value
    }

    mutating func set(from: T, to: T, steps: Int) {

        self.current = from
        self.target = to
        self.steps = steps
    }

    mutating func move() {

        if abs(current - target) < abs(delta) {
            current = target
        } else {
            current += delta
        }
    }
}
