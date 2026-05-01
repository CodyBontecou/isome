import Foundation

struct FilenameTemplate {
    static let readablePattern = "iso.me - {day} {date} - {type}"
    static let compactPattern = "isome_{type}_{datetime}"
    static let defaultPattern = readablePattern

    static let allTokens: [(token: String, description: String)] = [
        ("{date}", "2026-04-30"),
        ("{datetime}", "2026-04-30_14-30-15"),
        ("{time}", "14-30-15"),
        ("{day}", "Thursday"),
        ("{type}", "visits / points / all"),
        ("{format}", "json / csv / md"),
    ]

    static func resolve(
        pattern: String,
        dataKind: ExportOptions.DataKind,
        format: ExportFormat,
        date: Date = Date()
    ) -> String {
        let raw = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = raw.isEmpty ? defaultPattern : raw

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.dateFormat = "yyyy-MM-dd"

        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "en_US_POSIX")
        timeFmt.dateFormat = "HH-mm-ss"

        let datetimeFmt = DateFormatter()
        datetimeFmt.locale = Locale(identifier: "en_US_POSIX")
        datetimeFmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "en_US_POSIX")
        dayFmt.dateFormat = "EEEE"

        let typeText: String = {
            switch dataKind {
            case .visits: return "visits"
            case .points: return "points"
            case .all: return "all"
            }
        }()

        var output = pattern
        output = output.replacingOccurrences(of: "{datetime}", with: datetimeFmt.string(from: date))
        output = output.replacingOccurrences(of: "{date}", with: dateFmt.string(from: date))
        output = output.replacingOccurrences(of: "{time}", with: timeFmt.string(from: date))
        output = output.replacingOccurrences(of: "{day}", with: dayFmt.string(from: date))
        output = output.replacingOccurrences(of: "{type}", with: typeText)
        output = output.replacingOccurrences(of: "{format}", with: format.fileExtension)

        let sanitized = sanitize(output)
        return "\(sanitized).\(format.fileExtension)"
    }

    private static func sanitize(_ raw: String) -> String {
        let illegal: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\0"]
        var cleaned = String(raw.map { illegal.contains($0) ? "-" : $0 })
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "iso.me-export" : cleaned
    }
}
