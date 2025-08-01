// -----------------------------------------------------------------------------
// This file is part of RetroVision
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

struct AnimatedValue<T: BinaryFloatingPoint> {
    
    var current: T
    var delta: T = 0
    var steps: Int = 1 {
        didSet {
            let s = T(steps == 0 ? 1 : steps)
            delta = (target - current) / s
        }
    }
    
    var target: T {
        didSet {
            let s = T(steps == 0 ? 1 : steps)
            delta = (target - current) / s
        }
    }
    
    var animates: Bool {
        current != target
    }
    
    var clamped: T {
        min(max(current, 0), 1)
    }
    
    init(current: T = 0, target: T = 0) {
        self.current = current
        self.target = target
        self.steps = 1
        delta = target - current
    }
    
    init(_ value: T) {
        self.init(current: value, target: value)
    }
    
    mutating func set(_ value: T) {
        current = value
        target = value
    }
}
