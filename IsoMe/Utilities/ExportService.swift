import Foundation
import UIKit

enum ExportFormat {
    case json
    case csv
    case markdown

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .markdown: return "text/markdown"
        }
    }
}

struct ExportService {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - JSON Export

    struct ExportableVisit: Codable {
        let latitude: Double
        let longitude: Double
        let arrivedAt: String
        let departedAt: String?
        let durationMinutes: Double?
        let locationName: String?
        let address: String?
        let notes: String?
    }

    struct ExportData: Codable {
        let exportDate: String
        let visits: [ExportableVisit]
    }

    static func exportToJSON(visits: [Visit]) throws -> Data {
        let exportableVisits = visits.map { visit in
            ExportableVisit(
                latitude: visit.latitude,
                longitude: visit.longitude,
                arrivedAt: iso8601Formatter.string(from: visit.arrivedAt),
                departedAt: visit.departedAt.map { iso8601Formatter.string(from: $0) },
                durationMinutes: visit.durationMinutes,
                locationName: visit.locationName,
                address: visit.address,
                notes: visit.notes
            )
        }

        let exportData = ExportData(
            exportDate: iso8601Formatter.string(from: Date()),
            visits: exportableVisits
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(exportData)
    }

    // MARK: - CSV Export

    static func exportToCSV(visits: [Visit]) -> Data {
        var csvString = "arrived_at,departed_at,duration_minutes,latitude,longitude,location_name,address,notes\n"

        for visit in visits {
            let arrivedAt = iso8601Formatter.string(from: visit.arrivedAt)
            let departedAt = visit.departedAt.map { iso8601Formatter.string(from: $0) } ?? ""
            let duration = visit.durationMinutes.map { String(format: "%.1f", $0) } ?? ""
            let locationName = escapeCSVField(visit.locationName ?? "")
            let address = escapeCSVField(visit.address ?? "")
            let notes = escapeCSVField(visit.notes ?? "")

            let row = "\(arrivedAt),\(departedAt),\(duration),\(visit.latitude),\(visit.longitude),\(locationName),\(address),\(notes)\n"
            csvString.append(row)
        }

        return csvString.data(using: .utf8) ?? Data()
    }

    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    // MARK: - Markdown Export

    static func exportToMarkdown(visits: [Visit]) -> Data {
        var md = "# iso.me Export\n\n"
        md += "**Export Date:** \(formattedDateReadable())\n\n"
        md += "**Total Visits:** \(visits.count)\n\n"
        md += "---\n\n"

        // Group visits by date
        let grouped = Dictionary(grouping: visits) { visit in
            Calendar.current.startOfDay(for: visit.arrivedAt)
        }

        let sortedDates = grouped.keys.sorted(by: >)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        for date in sortedDates {
            guard let dayVisits = grouped[date] else { continue }

            md += "## \(dateFormatter.string(from: date))\n\n"

            for visit in dayVisits.sorted(by: { $0.arrivedAt < $1.arrivedAt }) {
                let locationName = visit.locationName ?? "Unknown Location"
                let arrivedTime = timeFormatter.string(from: visit.arrivedAt)

                md += "### \(locationName)\n\n"
                md += "- **Arrived:** \(arrivedTime)\n"

                if let departedAt = visit.departedAt {
                    md += "- **Departed:** \(timeFormatter.string(from: departedAt))\n"
                }

                if let duration = visit.durationMinutes {
                    let hours = Int(duration) / 60
                    let minutes = Int(duration) % 60
                    if hours > 0 {
                        md += "- **Duration:** \(hours)h \(minutes)m\n"
                    } else {
                        md += "- **Duration:** \(minutes)m\n"
                    }
                }

                if let address = visit.address, !address.isEmpty {
                    md += "- **Address:** \(address)\n"
                }

                md += "- **Coordinates:** \(String(format: "%.6f", visit.latitude)), \(String(format: "%.6f", visit.longitude))\n"

                if let notes = visit.notes, !notes.isEmpty {
                    md += "\n> \(notes)\n"
                }

                md += "\n"
            }
        }

        return md.data(using: .utf8) ?? Data()
    }

    private static func formattedDateReadable() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    // MARK: - Share/Save

    static func createTemporaryFile(data: Data, format: ExportFormat) throws -> URL {
        let fileName = "isome_export_\(formattedDate()).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try data.write(to: tempURL)
        return tempURL
    }

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
    }

    @MainActor
    static func share(visits: [Visit], format: ExportFormat, from viewController: UIViewController? = nil) throws {
        let data: Data
        switch format {
        case .json:
            data = try exportToJSON(visits: visits)
        case .csv:
            data = exportToCSV(visits: visits)
        case .markdown:
            data = exportToMarkdown(visits: visits)
        }

        let fileURL = try createTemporaryFile(data: data, format: format)

        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )

        // Get the presenting view controller
        guard let presenter = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        presenter.present(activityVC, animated: true)
    }
    
    // MARK: - Direct Export to Default Folder
    
    /// Export visits directly to the default export folder
    /// - Returns: The URL where the file was saved
    @MainActor
    static func exportToDefaultFolder(visits: [Visit], format: ExportFormat) throws -> URL {
        let data: Data
        switch format {
        case .json:
            data = try exportToJSON(visits: visits)
        case .csv:
            data = exportToCSV(visits: visits)
        case .markdown:
            data = exportToMarkdown(visits: visits)
        }
        
        let fileName = "isome_visits_\(formattedDate()).\(format.fileExtension)"
        
        guard let savedURL = try ExportFolderManager.shared.saveToDefaultFolder(data: data, fileName: fileName) else {
            throw ExportFolderError.noDefaultFolder
        }
        
        return savedURL
    }
}

// MARK: - Location Points Export (for continuous tracking data)

extension ExportService {
    struct ExportableLocationPoint: Codable {
        let latitude: Double
        let longitude: Double
        let timestamp: String
        let timestampUnix: Double
        let altitude: Double?
        let speed: Double?
        let course: Double?
        let horizontalAccuracy: Double
        let verticalAccuracy: Double?
    }

    struct LocationPointsExportData: Codable {
        let exportDate: String
        let totalPoints: Int
        let dateRange: DateRangeInfo?
        let points: [ExportableLocationPoint]
        
        struct DateRangeInfo: Codable {
            let earliest: String
            let latest: String
            let durationSeconds: Double
        }
    }

    static func exportLocationPointsToJSON(points: [LocationPoint]) throws -> Data {
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        
        let exportablePoints = sortedPoints.map { point in
            ExportableLocationPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: iso8601Formatter.string(from: point.timestamp),
                timestampUnix: point.timestamp.timeIntervalSince1970,
                altitude: point.altitude,
                speed: point.speed,
                course: nil,
                horizontalAccuracy: point.horizontalAccuracy,
                verticalAccuracy: nil
            )
        }
        
        var dateRangeInfo: LocationPointsExportData.DateRangeInfo? = nil
        if let first = sortedPoints.first, let last = sortedPoints.last {
            dateRangeInfo = LocationPointsExportData.DateRangeInfo(
                earliest: iso8601Formatter.string(from: first.timestamp),
                latest: iso8601Formatter.string(from: last.timestamp),
                durationSeconds: last.timestamp.timeIntervalSince(first.timestamp)
            )
        }

        let exportData = LocationPointsExportData(
            exportDate: iso8601Formatter.string(from: Date()),
            totalPoints: exportablePoints.count,
            dateRange: dateRangeInfo,
            points: exportablePoints
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(exportData)
    }
    
    static func exportLocationPointsToCSV(points: [LocationPoint]) -> Data {
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        
        var csvString = "timestamp,timestamp_unix,latitude,longitude,altitude,speed,horizontal_accuracy\n"
        
        for point in sortedPoints {
            let timestamp = iso8601Formatter.string(from: point.timestamp)
            let timestampUnix = String(format: "%.3f", point.timestamp.timeIntervalSince1970)
            let altitude = point.altitude.map { String(format: "%.2f", $0) } ?? ""
            let speed = point.speed.map { String(format: "%.2f", $0) } ?? ""
            
            let row = "\(timestamp),\(timestampUnix),\(point.latitude),\(point.longitude),\(altitude),\(speed),\(point.horizontalAccuracy)\n"
            csvString.append(row)
        }
        
        return csvString.data(using: .utf8) ?? Data()
    }
    
    static func exportLocationPointsToMarkdown(points: [LocationPoint]) -> Data {
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        
        var md = "# iso.me Location Points Export\n\n"
        md += "**Export Date:** \(formattedDateReadable())\n\n"
        md += "**Total Points:** \(sortedPoints.count)\n\n"
        
        if let first = sortedPoints.first, let last = sortedPoints.last {
            let duration = last.timestamp.timeIntervalSince(first.timestamp)
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            
            md += "**Time Range:** \(dateFormatter.string(from: first.timestamp)) → \(dateFormatter.string(from: last.timestamp))\n\n"
            md += "**Duration:** \(hours)h \(minutes)m\n\n"
        }
        
        md += "---\n\n"
        
        // Group by date
        let grouped = Dictionary(grouping: sortedPoints) { point in
            Calendar.current.startOfDay(for: point.timestamp)
        }
        
        let sortedDates = grouped.keys.sorted()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium
        
        for date in sortedDates {
            guard let dayPoints = grouped[date] else { continue }
            let sortedDayPoints = dayPoints.sorted { $0.timestamp < $1.timestamp }
            
            md += "## \(dateFormatter.string(from: date))\n\n"
            md += "| Time | Lat | Lon | Speed | Altitude |\n"
            md += "|------|-----|-----|-------|----------|\n"
            
            for point in sortedDayPoints {
                let time = timeFormatter.string(from: point.timestamp)
                let lat = String(format: "%.6f", point.latitude)
                let lon = String(format: "%.6f", point.longitude)
                let speed = point.speed.map { String(format: "%.1f m/s", $0) } ?? "-"
                let altitude = point.altitude.map { String(format: "%.1f m", $0) } ?? "-"
                
                md += "| \(time) | \(lat) | \(lon) | \(speed) | \(altitude) |\n"
            }
            
            md += "\n"
        }
        
        return md.data(using: .utf8) ?? Data()
    }
    
    @MainActor
    static func shareLocationPoints(points: [LocationPoint], format: ExportFormat, from viewController: UIViewController? = nil) throws {
        let data: Data
        switch format {
        case .json:
            data = try exportLocationPointsToJSON(points: points)
        case .csv:
            data = exportLocationPointsToCSV(points: points)
        case .markdown:
            data = exportLocationPointsToMarkdown(points: points)
        }
        
        let fileName = "isome_location_points_export_\(formattedDate()).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        
        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        
        guard let presenter = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        presenter.present(activityVC, animated: true)
    }
    
    /// Export location points directly to the default export folder
    /// - Returns: The URL where the file was saved
    @MainActor
    static func exportLocationPointsToDefaultFolder(points: [LocationPoint], format: ExportFormat) throws -> URL {
        let data: Data
        switch format {
        case .json:
            data = try exportLocationPointsToJSON(points: points)
        case .csv:
            data = exportLocationPointsToCSV(points: points)
        case .markdown:
            data = exportLocationPointsToMarkdown(points: points)
        }
        
        let fileName = "isome_location_points_export_\(formattedDate()).\(format.fileExtension)"
        
        guard let savedURL = try ExportFolderManager.shared.saveToDefaultFolder(data: data, fileName: fileName) else {
            throw ExportFolderError.noDefaultFolder
        }
        
        return savedURL
    }
}
