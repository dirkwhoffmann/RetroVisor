// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import AppKit

extension UInt32 {

    init(rgba: (UInt8, UInt8, UInt8, UInt8)) {

        let r = UInt32(rgba.0)
        let g = UInt32(rgba.1)
        let b = UInt32(rgba.2)
        let a = UInt32(rgba.3)

        self.init(bigEndian: r << 24 | g << 16 | b << 8 | a)
    }

    init(rgba: (UInt8, UInt8, UInt8)) {

        self.init(rgba: (rgba.0, rgba.1, rgba.2, 0xFF))
     }

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) { self.init(rgba: (r, g, b, a)) }
    init(r: UInt8, g: UInt8, b: UInt8) { self.init(rgba: (r, g, b)) }
}

extension CGRect {

    static var unity = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)

    static var scaleFactor: Int { Int(NSScreen.main?.backingScaleFactor ?? 2) }
}

extension NSScreen {

    static var scaleFactor: Int { Int(NSScreen.main?.backingScaleFactor ?? 2) }
}

extension NSWindow {

    func removeAccessory<T: NSTitlebarAccessoryViewController>(ofType type: T.Type) {
        
        if let index = titlebarAccessoryViewControllers.firstIndex(where: { $0 is T }) {
            removeTitlebarAccessoryViewController(at: index)
        }
    }
}

extension Dictionary where Key == String {

    var prettify: String {

        func format(_ dict: [String: Any], level: Int) -> String {

            let maxKeyLength = dict.keys.map { $0.count }.max() ?? 0

            return dict.keys.sorted().map { key in

                let value = dict[key]!
                let paddedKey = key.padding(toLength: maxKeyLength, withPad: " ", startingAt: 0)
                let prefix = String(repeating: "  ", count: level)

                if let subDict = value as? [String: Any] {
                    return "\(prefix)\(paddedKey) :\n\(format(subDict, level: level + 1))"
                } else {
                    return "\(prefix)\(paddedKey) : \(value)"
                }
            }.joined(separator: "\n")
        }

        return format(self, level: 0)
    }
}
