// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import Foundation

enum LogLevel {

    case debug
    case info
    case warning
    case error
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
    
#if DEBUG
    static func logDebug(_ message: String) { if Self.logging { print("[\(logtime)] \(message)") } }
#else
    static func logDebug(_ message: String) { }
#endif
    static func logInfo(_ message: String) { print("\(message)") }
    static func logWarning(_ message: String) { print("WARNING: \(message)") }
    static func logError(_ message: String) { print("ERROR: \(message)") }
    
    static func log(_ message: String, _ level: LogLevel = .debug) {

        switch level {
            
        case .debug: logDebug(message)
        case .info: logInfo(message)
        case .warning: logWarning(message)
        case .error: logError(message)
        }
    }
    
    func log(_ message: String, _ level: LogLevel  = .info) {
        
        Self.log(message, level)
    }
}
