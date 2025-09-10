// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Foundation

enum LogLevel: String {
    
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

protocol Loggable {
    
    static var logging: Bool { get }
    func log(_ message: String, _ level: LogLevel)
}

extension Loggable {
    
    private static var logtime: String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    static func log(_ message: String, _ level: LogLevel = .info) {
        
        switch level {
            
        case .info:
            
#if DEBUG
            guard Self.logging else { return }
            print("[\(logtime)] \(message)")
#endif
            
        case .warning, .error:
            
            print("\(level.rawValue): \(message)")
        }
    }
    
    func log(_ message: String, _ level: LogLevel  = .info) {
        Self.log(message, level)
    }
}
