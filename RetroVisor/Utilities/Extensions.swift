// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import AppKit

extension Bool {

    init(_ value: Int32) { self = value > 0 }
    var floatValue: Float { self ? 1.0 : 0.0 }
}

extension Int32 {
    
    init(_ value: Bool) { self = value ? 1 : 0 }
    var boolValue: Bool { self > 0 }
}

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
    
    init(color c: NSColor) {

        let r = UInt32(c.redComponent * 255.0)
        let g = UInt32(c.greenComponent * 255.0)
        let b = UInt32(c.blueComponent * 255.0)
        let a = UInt32(c.alphaComponent * 255.0)

        self.init(bigEndian: r << 24 | g << 16 | b << 8 | a)
    }
}

extension Float {

    var boolValue: Bool { self == 0.0 ? true : false }
    
    func formatted(min: Int, max: Int) -> String {

        var s = String(format: "%.0\(max)f", self)

        // Trim trailing zeros, but leave at least min digits
        if let dotIndex = s.firstIndex(of: ".") {
            var fracEnd = s.index(before: s.endIndex)
            while fracEnd > dotIndex && s[fracEnd] == "0" && s.distance(from: dotIndex, to: fracEnd) > min {
                fracEnd = s.index(before: fracEnd)
            }
            s = String(s[...fracEnd])
        }

        return s
    }
}

extension CGRect {

    static let unity = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)

    static var scaleFactor: Int { Int(NSScreen.main?.backingScaleFactor ?? 2) }
}

extension NSSize {
    
    static let unity = NSSize(width: 1.0, height: 1.0)
}

extension NSFont {
 
    static func monospaced(ofSize fontSize: CGFloat, weight: Weight) -> NSFont {
        
        if #available(macOS 10.15, *) {
            return NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        } else {
            return NSFont.systemFont(ofSize: fontSize)
        }
    }
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

extension NSImage {

    static func sfSymbol(name: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSImage? {

        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)

        return NSImage(systemSymbolName: name,
                       accessibilityDescription: name)?.withSymbolConfiguration(config)
    }

    static func chevronDown(size: CGFloat = 14, weight: NSFont.Weight = .regular) -> NSImage? {

        return sfSymbol(name: "chevron.down", size: size, weight: weight)
    }

    static func chevronRight(size: CGFloat = 14, weight: NSFont.Weight = .regular) -> NSImage? {

        return sfSymbol(name: "chevron.right", size: size, weight: weight)
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
