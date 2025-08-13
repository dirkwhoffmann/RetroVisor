import Foundation

enum LogLevel: String {

    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

protocol Loggable {

    var logging: Bool { get set }
    // var isLoggingEnabled: Bool { get }

    func log(_ message: String, level: LogLevel)
}

extension Loggable {

    func log(_ message: String, level: LogLevel = .info) {

        guard logging else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] \(message)")
    }
}
