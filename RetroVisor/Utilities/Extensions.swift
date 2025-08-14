// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import AppKit

extension NSScreen {

    static var scaleFactor: Int { Int(NSScreen.main?.backingScaleFactor ?? 2) }
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
