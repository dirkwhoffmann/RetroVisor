// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Foundation

/* The Parser class provides means of parsing simple INI files.
 */

class Parser {

    enum ParseError: LocalizedError {
        
        case generic(_ message: String, line: Int? = nil)
        
        var errorDescription: String? {
            
            switch self {
            case let .generic(message, line):
                if let line = line {
                    return "\(message) (line \(line))"
                } else {
                    return message
                }
            }
        }
    }

    static func loadINI(contents: String) -> [String: [String: String]] {
        
        var section = ""
        var result: [String: [String: String]] = [:]
        
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        
        do {
            
            for line in lines {
                
                var input = String(line)
                
                // Remove comments
                if let index = input.firstIndex(of: "#") { input = String(input[..<index]) }
                
                // Remove spaces
                input.removeAll { $0 == " " }
                
                // Ignore empty lines
                if input.isEmpty { continue }
                
                // Section marker?
                if input.first == "[", input.last == "]" {
                    
                    section = String(input.dropFirst().dropLast()).lowercased()
                    continue
                }
                
                // Key-value pair?
                if let index = input.firstIndex(of: "=") {
                    
                    let key = String(input[..<index])
                    let value = String(input[input.index(after: index)...])
                    
                    // Insert into nested dictionary
                    if result[section] == nil {
                        result[section] = [:]
                    }
                    result[section]![key] = value
                }
            }
        }
        
        return result
    }
    
    static func saveINI(_ dict: [String: [String: String]], to url: URL) throws {
        
        var lines: [String] = []
        
        for section in dict.keys.sorted() {

            lines.append("[\(section)]")
            lines.append("")
            
            if let keyValues = dict[section] {
                
                for key in keyValues.keys.sorted() {

                    let value = keyValues[key]!
                    lines.append("\(key)=\(value)")
                }
            }
            
            lines.append("")
        }
        
        let contents = lines.joined(separator: "\n")
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
