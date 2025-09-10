// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Foundation

 final class AtomicQueue<T> {
     
    private var items: [T] = []
    private let lock = NSLock()
    
    // Enqueue a new element
    func push(_ item: T) {
        
        lock.lock()
        items.append(item)
        lock.unlock()
    }
    
    // Dequeue all elements currently in the queue
    func popAll() -> [T] {
        
        lock.lock()
        let result = items
        items.removeAll(keepingCapacity: true)
        lock.unlock()
        return result
    }
    
    // Check if queue is empty
    var isEmpty: Bool {
        
        lock.lock()
        let result = items.isEmpty
        lock.unlock()
        return result
    }
}
