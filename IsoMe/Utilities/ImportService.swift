import Foundation

enum ImportError: LocalizedError {
    case unsupportedFormat
    case invalidData(String)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format. Please use JSON, CSV, or Markdown files exported from iso.me."
        case .invalidData(let detail):
            return "Invalid data: \(detail)"
        case .parsingFailed(let detail):
            return "Parsing failed: \(detail)"
        }
    }
}

enum ImportDataType {
    case visits
    case locationPoints
}

struct ImportedVisit {
    let latitude: Double
    let longitude: Double
    let arrivedAt: Date
    let departedAt: Date?
    let locationName: String?
    let address: String?
    let notes: String?
}

struct ImportedLocationPoint {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitude: Double?
    let speed: Double?
    let horizontalAccuracy: Double
    let isOutlier: Bool
}

struct ImportResult {
    let visitCount: Int
    let pointCount: Int

    var summary: String {
        var parts: [String] = []
        if visitCount > 0 { parts.append("\(visitCount) visit\(visitCount == 1 ? "" : "s")") }
        if pointCount > 0 { parts.append("\(pointCount) point\(pointCount == 1 ? "" : "s")") }
        return "Imported \(parts.joined(separator: " and "))."
    }
}

struct ImportService {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Format Detection

    static func detectFormat(url: URL) -> ExportFormat? {
        switch url.pathExtension.lowercased() {
        case "json": return .json
        case "csv": return .csv
        case "md", "markdown": return .markdown
        default: return nil
        }
    }

    static func detectDataType(from data: Data, format: ExportFormat) -> ImportDataType {
        switch format {
        case .json:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if json["visits"] != nil { return .visits }
                if json["points"] != nil { return .locationPoints }
            }
        case .csv:
            if let header = String(data: data, encoding: .utf8)?.components(separatedBy: "\n").first {
                if header.contains("arrived_at") { return .visits }
                if header.contains("timestamp") { return .locationPoints }
            }
        case .markdown:
            if let text = String(data: data, encoding: .utf8) {
                if text.contains("# iso.me Location Points Export") { return .locationPoints }
                if text.contains("# iso.me Export") { return .visits }
            }
        }
        return .visits
    }

    // MARK: - Unified Import

    static func importFile(data: Data, format: ExportFormat) throws -> (visits: [ImportedVisit], points: [ImportedLocationPoint]) {
        let dataType = detectDataType(from: data, format: format)

        switch dataType {
        case .visits:
            let visits = try importVisits(data: data, format: format)
            return (visits: visits, points: [])
        case .locationPoints:
            let points = try importLocationPoints(data: data, format: format)
            return (visits: [], points: points)
        }
    }

    // MARK: - Visit Import

    static func importVisits(data: Data, format: ExportFormat) throws -> [ImportedVisit] {
        switch format {
        case .json: return try importVisitsFromJSON(data: data)
        case .csv: return try importVisitsFromCSV(data: data)
        case .markdown: return try importVisitsFromMarkdown(data: data)
        }
    }

    // MARK: - Location Point Import

    static func importLocationPoints(data: Data, format: ExportFormat) throws -> [ImportedLocationPoint] {
        switch format {
        case .json: return try importLocationPointsFromJSON(data: data)
        case .csv: return try importLocationPointsFromCSV(data: data)
        case .markdown: return try importLocationPointsFromMarkdown(data: data)
        }
    }

    // MARK: - JSON Visit Import

    private static func importVisitsFromJSON(data: Data) throws -> [ImportedVisit] {
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ImportError.invalidData("Expected JSON object at root")
            }
            json = parsed
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.parsingFailed("Invalid JSON: \(error.localizedDescription)")
        }

        guard let visitsArray = json["visits"] as? [[String: Any]] else {
            throw ImportError.invalidData("Missing 'visits' array")
        }

        return try visitsArray.enumerated().map { index, dict in
            guard let latitude = dict["latitude"] as? Double,
                  let longitude = dict["longitude"] as? Double,
                  let arrivedAtStr = dict["arrivedAt"] as? String,
                  let arrivedAt = parseISO8601Date(arrivedAtStr) else {
                throw ImportError.invalidData("Visit at index \(index) missing required fields (latitude, longitude, arrivedAt)")
            }

            let departedAt: Date? = (dict["departedAt"] as? String).flatMap { parseISO8601Date($0) }

            return ImportedVisit(
                latitude: latitude,
                longitude: longitude,
                arrivedAt: arrivedAt,
                departedAt: departedAt,
                locationName: dict["locationName"] as? String,
                address: dict["address"] as? String,
                notes: dict["notes"] as? String
            )
        }
    }

    // MARK: - JSON Location Point Import

    private static func importLocationPointsFromJSON(data: Data) throws -> [ImportedLocationPoint] {
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ImportError.invalidData("Expected JSON object at root")
            }
            json = parsed
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.parsingFailed("Invalid JSON: \(error.localizedDescription)")
        }

        guard let pointsArray = json["points"] as? [[String: Any]] else {
            throw ImportError.invalidData("Missing 'points' array")
        }

        return try pointsArray.enumerated().map { index, dict in
            guard let latitude = dict["latitude"] as? Double,
                  let longitude = dict["longitude"] as? Double else {
                throw ImportError.invalidData("Point at index \(index) missing latitude/longitude")
            }

            let timestamp: Date
            if let tsStr = dict["timestamp"] as? String, let ts = parseISO8601Date(tsStr) {
                timestamp = ts
            } else if let tsUnix = dict["timestampUnix"] as? Double {
                timestamp = Date(timeIntervalSince1970: tsUnix)
            } else {
                throw ImportError.invalidData("Point at index \(index) missing timestamp")
            }

            return ImportedLocationPoint(
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
                altitude: dict["altitude"] as? Double,
                speed: dict["speed"] as? Double,
                horizontalAccuracy: dict["horizontalAccuracy"] as? Double ?? 0,
                isOutlier: dict["isOutlier"] as? Bool ?? false
            )
        }
    }

    // MARK: - CSV Visit Import

    private static func importVisitsFromCSV(data: Data) throws -> [ImportedVisit] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidData("Could not read file as UTF-8 text")
        }

        let rows = parseCSVRows(content)
        guard rows.count > 1 else {
            throw ImportError.invalidData("CSV file has no data rows")
        }

        let header = rows[0]
        guard header.contains("arrived_at") && header.contains("latitude") else {
            throw ImportError.invalidData("CSV header doesn't match expected visit format")
        }

        let colIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })

        return try rows.dropFirst().enumerated().compactMap { rowIndex, fields in
            guard fields.count >= header.count else { return nil }

            guard let arrivedAtCol = colIndex["arrived_at"],
                  let latCol = colIndex["latitude"],
                  let lonCol = colIndex["longitude"] else {
                throw ImportError.invalidData("Missing required columns")
            }

            guard let arrivedAt = parseISO8601Date(fields[arrivedAtCol]) else {
                throw ImportError.invalidData("Row \(rowIndex + 2): invalid arrived_at date")
            }

            let latitude = Double(fields[latCol]) ?? 0
            let longitude = Double(fields[lonCol]) ?? 0

            let departedAt: Date? = colIndex["departed_at"].flatMap { col in
                let val = fields[col]
                return val.isEmpty ? nil : parseISO8601Date(val)
            }

            let locationName: String? = colIndex["location_name"].flatMap { col in
                let val = fields[col]
                return val.isEmpty ? nil : val
            }

            let address: String? = colIndex["address"].flatMap { col in
                let val = fields[col]
                return val.isEmpty ? nil : val
            }

            let notes: String? = colIndex["notes"].flatMap { col in
                let val = fields[col]
                return val.isEmpty ? nil : val
            }

            return ImportedVisit(
                latitude: latitude,
                longitude: longitude,
                arrivedAt: arrivedAt,
                departedAt: departedAt,
                locationName: locationName,
                address: address,
                notes: notes
            )
        }
    }

    // MARK: - CSV Location Point Import

    private static func importLocationPointsFromCSV(data: Data) throws -> [ImportedLocationPoint] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidData("Could not read file as UTF-8 text")
        }

        let rows = parseCSVRows(content)
        guard rows.count > 1 else {
            throw ImportError.invalidData("CSV file has no data rows")
        }

        let header = rows[0]
        guard header.contains("timestamp") && header.contains("latitude") else {
            throw ImportError.invalidData("CSV header doesn't match expected location point format")
        }

        let colIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })

        return try rows.dropFirst().enumerated().compactMap { rowIndex, fields in
            guard fields.count >= header.count else { return nil }

            guard let tsCol = colIndex["timestamp"],
                  let latCol = colIndex["latitude"],
                  let lonCol = colIndex["longitude"] else {
                throw ImportError.invalidData("Missing required columns")
            }

            let timestamp: Date
            if let ts = parseISO8601Date(fields[tsCol]) {
                timestamp = ts
            } else if let unixCol = colIndex["timestamp_unix"], let unix = Double(fields[unixCol]) {
                timestamp = Date(timeIntervalSince1970: unix)
            } else {
                throw ImportError.invalidData("Row \(rowIndex + 2): invalid timestamp")
            }

            let latitude = Double(fields[latCol]) ?? 0
            let longitude = Double(fields[lonCol]) ?? 0

            let altitude: Double? = colIndex["altitude"].flatMap { col in
                let val = fields[col]
                return val.isEmpty ? nil : Double(val)
            }

            let speed: Double? = colIndex["speed"].flatMap { col in
                let val = fields[col]
                return val.isEmpty ? nil : Double(val)
            }

            let horizontalAccuracy: Double = colIndex["horizontal_accuracy"].flatMap { col in
                Double(fields[col])
            } ?? 0

            let isOutlier: Bool = colIndex["is_outlier"].map { col in
                fields[col].lowercased() == "true"
            } ?? false

            return ImportedLocationPoint(
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
                altitude: altitude,
                speed: speed,
                horizontalAccuracy: horizontalAccuracy,
                isOutlier: isOutlier
            )
        }
    }

    // MARK: - Markdown Visit Import

    private static func importVisitsFromMarkdown(data: Data) throws -> [ImportedVisit] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidData("Could not read file as UTF-8 text")
        }

        var visits: [ImportedVisit] = []
        let lines = content.components(separatedBy: "\n")

        var currentDate: Date?
        var currentLocationName: String?
        var arrivedAt: Date?
        var departedAt: Date?
        var address: String?
        var latitude: Double?
        var longitude: Double?
        var notes: String?

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        func flushVisit() {
            if let lat = latitude, let lon = longitude, let arrived = arrivedAt {
                visits.append(ImportedVisit(
                    latitude: lat,
                    longitude: lon,
                    arrivedAt: arrived,
                    departedAt: departedAt,
                    locationName: currentLocationName,
                    address: address,
                    notes: notes
                ))
            }
            arrivedAt = nil
            departedAt = nil
            address = nil
            latitude = nil
            longitude = nil
            notes = nil
            currentLocationName = nil
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Date header: ## Thursday, April 3, 2026
            if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
                let dateStr = String(trimmed.dropFirst(3))
                if let date = dateFormatter.date(from: dateStr) {
                    currentDate = date
                }
                continue
            }

            // Location name: ### Blue Bottle Coffee
            if trimmed.hasPrefix("### ") {
                flushVisit()
                currentLocationName = String(trimmed.dropFirst(4))
                continue
            }

            // Fields
            if trimmed.hasPrefix("- **Arrived:**") {
                let timeStr = trimmed.replacingOccurrences(of: "- **Arrived:** ", with: "")
                if let date = currentDate, let time = timeFormatter.date(from: timeStr) {
                    arrivedAt = combineDateAndTime(date: date, time: time)
                }
            } else if trimmed.hasPrefix("- **Departed:**") {
                let timeStr = trimmed.replacingOccurrences(of: "- **Departed:** ", with: "")
                if let date = currentDate, let time = timeFormatter.date(from: timeStr) {
                    departedAt = combineDateAndTime(date: date, time: time)
                }
            } else if trimmed.hasPrefix("- **Address:**") {
                address = trimmed.replacingOccurrences(of: "- **Address:** ", with: "")
            } else if trimmed.hasPrefix("- **Coordinates:**") {
                let coordStr = trimmed.replacingOccurrences(of: "- **Coordinates:** ", with: "")
                let parts = coordStr.components(separatedBy: ", ")
                if parts.count == 2 {
                    latitude = Double(parts[0].trimmingCharacters(in: .whitespaces))
                    longitude = Double(parts[1].trimmingCharacters(in: .whitespaces))
                }
            } else if trimmed.hasPrefix("> ") {
                let noteText = String(trimmed.dropFirst(2))
                if !noteText.isEmpty {
                    notes = noteText
                }
            }
        }

        flushVisit()

        if visits.isEmpty {
            throw ImportError.invalidData("No visits found in Markdown file")
        }

        return visits
    }

    // MARK: - Markdown Location Point Import

    private static func importLocationPointsFromMarkdown(data: Data) throws -> [ImportedLocationPoint] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidData("Could not read file as UTF-8 text")
        }

        var points: [ImportedLocationPoint] = []
        let lines = content.components(separatedBy: "\n")

        var currentDate: Date?

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Date header: ## Thursday, April 7, 2026
            if trimmed.hasPrefix("## ") {
                let dateStr = String(trimmed.dropFirst(3))
                if let date = dateFormatter.date(from: dateStr) {
                    currentDate = date
                }
                continue
            }

            // Table row: | 9:00:15 AM | 37.775000 | -122.419400 | 1.5 m/s | 10.5 m |
            if trimmed.hasPrefix("|") && !trimmed.contains("---") && !trimmed.contains("Time") {
                guard let date = currentDate else { continue }
                let cells = trimmed.components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                guard cells.count >= 5 else { continue }

                guard let time = timeFormatter.date(from: cells[0]) else { continue }
                guard let lat = Double(cells[1]), let lon = Double(cells[2]) else { continue }

                let timestamp = combineDateAndTime(date: date, time: time)

                let speed: Double? = {
                    let val = cells[3].replacingOccurrences(of: " m/s", with: "")
                    return val == "-" ? nil : Double(val)
                }()

                let altitude: Double? = {
                    let val = cells[4].replacingOccurrences(of: " m", with: "")
                    return val == "-" ? nil : Double(val)
                }()

                let isOutlier: Bool = cells.count >= 6 && cells[5].lowercased() == "yes"

                points.append(ImportedLocationPoint(
                    latitude: lat,
                    longitude: lon,
                    timestamp: timestamp,
                    altitude: altitude,
                    speed: speed,
                    horizontalAccuracy: 0,
                    isOutlier: isOutlier
                ))
            }
        }

        if points.isEmpty {
            throw ImportError.invalidData("No location points found in Markdown file")
        }

        return points
    }

    // MARK: - Helpers

    private static func parseISO8601Date(_ string: String) -> Date? {
        iso8601Formatter.date(from: string) ?? iso8601FallbackFormatter.date(from: string)
    }

    private static func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second

        return calendar.date(from: combined) ?? date
    }

    // MARK: - CSV Parser (RFC 4180)

    private static func parseCSVRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentField = ""
        var currentRow: [String] = []
        var inQuotes = false
        let chars = Array(content)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            if inQuotes {
                if char == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(char)
                    i += 1
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                    i += 1
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                } else if char == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) || rows.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    i += 1
                } else if char == "\r" {
                    i += 1
                    continue
                } else {
                    currentField.append(char)
                    i += 1
                }
            }
        }

        // Last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}
