import Foundation
import OSLog

@MainActor
final class LogManager: ObservableObject {
    static let shared = LogManager()

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let message: String

        enum Level: String {
            case info = "INFO"
            case warning = "WARN"
            case error = "ERROR"
        }

        var display: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return "[\(formatter.string(from: timestamp))] \(level.rawValue): \(message)"
        }
    }

    @Published private(set) var entries: [LogEntry] = []
    private let maxEntries = 500
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bontecou.isome", category: "app")

    private init() {}

    func log(_ message: String, level: LogEntry.Level = .info) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        switch level {
        case .info: logger.info("\(message)")
        case .warning: logger.warning("\(message)")
        case .error: logger.error("\(message)")
        }
    }

    func info(_ message: String) { log(message, level: .info) }
    func warning(_ message: String) { log(message, level: .warning) }
    func error(_ message: String) { log(message, level: .error) }

    func clear() { entries.removeAll() }

    var exportText: String {
        entries.map(\.display).joined(separator: "\n")
    }
}
