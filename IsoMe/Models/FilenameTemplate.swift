import Foundation

struct FilenameTemplate {
    static let readablePattern = "iso.me - {day} {date} - {type}"
    static let compactPattern = "isome_{type}_{datetime}"
    static let datedFoldersPattern = "{year}/{year}-{month}/Daily Track - {date}"
    static let defaultPattern = readablePattern

    static let allTokens: [(token: String, description: String)] = [
        ("{date}", "2026-04-30"),
        ("{year}", "2026"),
        ("{month}", "04"),
        ("{dayNumber}", "30"),
        ("{weekday}", "Thursday"),
        ("{monthName}", "April"),
        ("{quarter}", "Q2"),
        ("{datetime}", "2026-04-30_14-30-15"),
        ("{time}", "14-30-15"),
        ("{day}", "Thursday"),
        ("{type}", "visits / points / outings / all"),
        ("{title}", "Outing title, or data type when unavailable"),
        ("{name}", "Outing title, or data type when unavailable"),
        ("{format}", "json / csv / md / owntracks / overland / gpx / kml / geojson"),
    ]

    static func resolve(
        pattern: String,
        dataKind: ExportOptions.DataKind,
        format: ExportFormat,
        date: Date = Date(),
        title: String? = nil
    ) -> String {
        let rawPath = appendingFormatExtensionIfNeeded(
            to: stem(pattern: pattern, dataKind: dataKind, format: format, date: date, title: title),
            format: format,
            fallbackBasename: dataKind.rawValue
        )
        return sanitizePath(rawPath)
    }

    static func stem(
        pattern: String,
        dataKind: ExportOptions.DataKind,
        format: ExportFormat,
        date: Date = Date(),
        title: String? = nil
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

        let yearFmt = DateFormatter()
        yearFmt.locale = Locale(identifier: "en_US_POSIX")
        yearFmt.dateFormat = "yyyy"

        let monthFmt = DateFormatter()
        monthFmt.locale = Locale(identifier: "en_US_POSIX")
        monthFmt.dateFormat = "MM"

        let dayNumberFmt = DateFormatter()
        dayNumberFmt.locale = Locale(identifier: "en_US_POSIX")
        dayNumberFmt.dateFormat = "dd"

        let monthNameFmt = DateFormatter()
        monthNameFmt.locale = Locale(identifier: "en_US_POSIX")
        monthNameFmt.dateFormat = "MMMM"

        let monthNumber = Calendar.current.component(.month, from: date)
        let quarterText = "Q\((monthNumber - 1) / 3 + 1)"

        let typeText = dataKind.rawValue
        let titleText: String
        if let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedTitle.isEmpty {
            titleText = trimmedTitle
        } else {
            titleText = typeText
        }

        var output = pattern
        output = output.replacingOccurrences(of: "{datetime}", with: datetimeFmt.string(from: date))
        output = output.replacingOccurrences(of: "{date}", with: dateFmt.string(from: date))
        output = output.replacingOccurrences(of: "{year}", with: yearFmt.string(from: date))
        output = output.replacingOccurrences(of: "{month}", with: monthFmt.string(from: date))
        output = output.replacingOccurrences(of: "{dayNumber}", with: dayNumberFmt.string(from: date))
        output = output.replacingOccurrences(of: "{weekday}", with: dayFmt.string(from: date))
        output = output.replacingOccurrences(of: "{monthName}", with: monthNameFmt.string(from: date))
        output = output.replacingOccurrences(of: "{quarter}", with: quarterText)
        output = output.replacingOccurrences(of: "{time}", with: timeFmt.string(from: date))
        output = output.replacingOccurrences(of: "{day}", with: dayFmt.string(from: date))
        output = output.replacingOccurrences(of: "{type}", with: typeText)
        output = output.replacingOccurrences(of: "{title}", with: titleText)
        output = output.replacingOccurrences(of: "{name}", with: titleText)
        output = output.replacingOccurrences(of: "{format}", with: format.token)
        return output
    }

    static func appendingFormatExtensionIfNeeded(
        to rawPath: String,
        format: ExportFormat,
        fallbackBasename: String = "iso.me-export"
    ) -> String {
        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExtension = format.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !normalizedExtension.isEmpty else { return trimmedPath }

        let normalizedPath = trimmedPath.replacingOccurrences(of: "\\", with: "/")
        let fallbackFilename = "\(sanitize(fallbackBasename)).\(normalizedExtension)"
        guard !normalizedPath.isEmpty else { return fallbackFilename }

        if normalizedPath.hasSuffix("/") {
            return "\(normalizedPath)\(fallbackFilename)"
        }

        let directoryPrefix: String
        let lastComponent: String
        if let splitIndex = normalizedPath.lastIndex(of: "/") {
            directoryPrefix = String(normalizedPath[...splitIndex])
            lastComponent = String(normalizedPath[normalizedPath.index(after: splitIndex)...])
        } else {
            directoryPrefix = ""
            lastComponent = normalizedPath
        }

        let extensionSuffix = ".\(normalizedExtension)"
        if lastComponent.lowercased() == extensionSuffix.lowercased() {
            return "\(directoryPrefix)\(fallbackFilename)"
        }
        if lastComponent.lowercased().hasSuffix(extensionSuffix.lowercased()) {
            return normalizedPath
        }
        return "\(normalizedPath).\(normalizedExtension)"
    }

    static func sanitizePath(_ rawPath: String) -> String {
        let normalizedPath = rawPath.replacingOccurrences(of: "\\", with: "/")
        let components = normalizedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        let cleanedComponents = components
            .map { sanitizePathComponent($0) }
            .filter { !$0.isEmpty }

        return cleanedComponents.isEmpty ? "iso.me-export" : cleanedComponents.joined(separator: "/")
    }

    static func sanitize(_ raw: String) -> String {
        let cleaned = sanitizeComponent(raw, preservingSlash: false)
        return cleaned.isEmpty ? "iso.me-export" : cleaned
    }

    private static func sanitizePathComponent(_ raw: String) -> String {
        sanitizeComponent(raw, preservingSlash: true)
    }

    private static func sanitizeComponent(_ raw: String, preservingSlash: Bool) -> String {
        var illegal: Set<Character> = ["\\", ":", "*", "?", "\"", "<", ">", "|", "\0"]
        if !preservingSlash { illegal.insert("/") }

        var cleaned = String(raw.map { illegal.contains($0) ? "-" : $0 })
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        return cleaned
    }
}
