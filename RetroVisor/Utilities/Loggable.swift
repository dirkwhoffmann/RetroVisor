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

    var logging: Bool { get }
    func log(_ message: String, _ level: LogLevel)
}

extension Loggable {

    var timestamp: String { ISO8601DateFormatter().string(from: Date()) }

    func log(_ message: String, _ level: LogLevel = .info) {

        switch level {

        case .info:

            guard logging else { return }
            print("[\(timestamp)] \(message)")

        case .warning, .error:

            print("\(level.rawValue): \(message)")
        }
    }
}
