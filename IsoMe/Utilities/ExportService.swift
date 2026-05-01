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
        let latitude: Double?
        let longitude: Double?
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

    static func exportToJSON(visits: [Visit], options: ExportOptions = ExportOptions()) throws -> Data {
        let exportableVisits = visits.map { visit in
            ExportableVisit(
                latitude: options.includeVisitCoordinates ? visit.latitude : nil,
                longitude: options.includeVisitCoordinates ? visit.longitude : nil,
                arrivedAt: iso8601Formatter.string(from: visit.arrivedAt),
                departedAt: visit.departedAt.map { iso8601Formatter.string(from: $0) },
                durationMinutes: options.includeVisitDuration ? visit.durationMinutes : nil,
                locationName: options.includeVisitLocationName ? visit.locationName : nil,
                address: options.includeVisitAddress ? visit.address : nil,
                notes: options.includeVisitNotes ? visit.notes : nil
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

    static func exportToCSV(visits: [Visit], options: ExportOptions = ExportOptions()) -> Data {
        var headers = ["arrived_at", "departed_at"]
        if options.includeVisitDuration { headers.append("duration_minutes") }
        if options.includeVisitCoordinates {
            headers.append("latitude")
            headers.append("longitude")
        }
        if options.includeVisitLocationName { headers.append("location_name") }
        if options.includeVisitAddress { headers.append("address") }
        if options.includeVisitNotes { headers.append("notes") }

        var csvString = headers.joined(separator: ",") + "\n"

        for visit in visits {
            var fields: [String] = []
            fields.append(iso8601Formatter.string(from: visit.arrivedAt))
            fields.append(visit.departedAt.map { iso8601Formatter.string(from: $0) } ?? "")
            if options.includeVisitDuration {
                fields.append(visit.durationMinutes.map { String(format: "%.1f", $0) } ?? "")
            }
            if options.includeVisitCoordinates {
                fields.append(String(visit.latitude))
                fields.append(String(visit.longitude))
            }
            if options.includeVisitLocationName {
                fields.append(escapeCSVField(visit.locationName ?? ""))
            }
            if options.includeVisitAddress {
                fields.append(escapeCSVField(visit.address ?? ""))
            }
            if options.includeVisitNotes {
                fields.append(escapeCSVField(visit.notes ?? ""))
            }
            csvString.append(fields.joined(separator: ",") + "\n")
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

    static func exportToMarkdown(visits: [Visit], options: ExportOptions = ExportOptions()) -> Data {
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
                let heading: String
                if options.includeVisitLocationName, let name = visit.locationName, !name.isEmpty {
                    heading = name
                } else {
                    heading = timeFormatter.string(from: visit.arrivedAt)
                }
                let arrivedTime = timeFormatter.string(from: visit.arrivedAt)

                md += "### \(heading)\n\n"
                md += "- **Arrived:** \(arrivedTime)\n"

                if let departedAt = visit.departedAt {
                    md += "- **Departed:** \(timeFormatter.string(from: departedAt))\n"
                }

                if options.includeVisitDuration, let duration = visit.durationMinutes {
                    let hours = Int(duration) / 60
                    let minutes = Int(duration) % 60
                    if hours > 0 {
                        md += "- **Duration:** \(hours)h \(minutes)m\n"
                    } else {
                        md += "- **Duration:** \(minutes)m\n"
                    }
                }

                if options.includeVisitAddress, let address = visit.address, !address.isEmpty {
                    md += "- **Address:** \(address)\n"
                }

                if options.includeVisitCoordinates {
                    md += "- **Coordinates:** \(String(format: "%.6f", visit.latitude)), \(String(format: "%.6f", visit.longitude))\n"
                }

                if options.includeVisitNotes, let notes = visit.notes, !notes.isEmpty {
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
        let horizontalAccuracy: Double?
        let verticalAccuracy: Double?
        // True when the app's GPS-glitch detector flagged this point as an outlier.
        let isOutlier: Bool?
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

    static func exportLocationPointsToJSON(points: [LocationPoint], options: ExportOptions = ExportOptions()) throws -> Data {
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }

        let exportablePoints = sortedPoints.map { point in
            ExportableLocationPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: iso8601Formatter.string(from: point.timestamp),
                timestampUnix: point.timestamp.timeIntervalSince1970,
                altitude: options.includePointAltitude ? point.altitude : nil,
                speed: options.includePointSpeed ? point.speed : nil,
                course: nil,
                horizontalAccuracy: options.includePointAccuracy ? point.horizontalAccuracy : nil,
                verticalAccuracy: nil,
                isOutlier: options.includePointOutlierFlag ? point.isOutlier : nil
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
    
    static func exportLocationPointsToCSV(points: [LocationPoint], options: ExportOptions = ExportOptions()) -> Data {
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }

        var headers = ["timestamp", "timestamp_unix", "latitude", "longitude"]
        if options.includePointAltitude { headers.append("altitude") }
        if options.includePointSpeed { headers.append("speed") }
        if options.includePointAccuracy { headers.append("horizontal_accuracy") }
        if options.includePointOutlierFlag { headers.append("is_outlier") }

        var csvString = headers.joined(separator: ",") + "\n"

        for point in sortedPoints {
            var fields: [String] = []
            fields.append(iso8601Formatter.string(from: point.timestamp))
            fields.append(String(format: "%.3f", point.timestamp.timeIntervalSince1970))
            fields.append(String(point.latitude))
            fields.append(String(point.longitude))
            if options.includePointAltitude {
                fields.append(point.altitude.map { String(format: "%.2f", $0) } ?? "")
            }
            if options.includePointSpeed {
                fields.append(point.speed.map { String(format: "%.2f", $0) } ?? "")
            }
            if options.includePointAccuracy {
                fields.append(String(point.horizontalAccuracy))
            }
            if options.includePointOutlierFlag {
                fields.append(point.isOutlier ? "true" : "false")
            }
            csvString.append(fields.joined(separator: ",") + "\n")
        }

        return csvString.data(using: .utf8) ?? Data()
    }
    
    static func exportLocationPointsToMarkdown(points: [LocationPoint], options: ExportOptions = ExportOptions()) -> Data {
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

        var headerCols: [String] = ["Time", "Lat", "Lon"]
        if options.includePointSpeed { headerCols.append("Speed") }
        if options.includePointAltitude { headerCols.append("Altitude") }
        if options.includePointAccuracy { headerCols.append("Accuracy") }
        if options.includePointOutlierFlag { headerCols.append("Outlier") }

        for date in sortedDates {
            guard let dayPoints = grouped[date] else { continue }
            let sortedDayPoints = dayPoints.sorted { $0.timestamp < $1.timestamp }

            md += "## \(dateFormatter.string(from: date))\n\n"
            md += "| " + headerCols.joined(separator: " | ") + " |\n"
            md += "|" + headerCols.map { _ in "------" }.joined(separator: "|") + "|\n"

            for point in sortedDayPoints {
                var cells: [String] = []
                cells.append(timeFormatter.string(from: point.timestamp))
                cells.append(String(format: "%.6f", point.latitude))
                cells.append(String(format: "%.6f", point.longitude))
                if options.includePointSpeed {
                    cells.append(point.speed.map { String(format: "%.1f m/s", $0) } ?? "-")
                }
                if options.includePointAltitude {
                    cells.append(point.altitude.map { String(format: "%.1f m", $0) } ?? "-")
                }
                if options.includePointAccuracy {
                    cells.append(String(format: "%.1f m", point.horizontalAccuracy))
                }
                if options.includePointOutlierFlag {
                    cells.append(point.isOutlier ? "yes" : "-")
                }
                md += "| " + cells.joined(separator: " | ") + " |\n"
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

// MARK: - Combined Export (visits + location points in a single file)

extension ExportService {
    struct CombinedExportData: Codable {
        let exportDate: String
        let totalVisits: Int
        let totalPoints: Int
        let dateRange: LocationPointsExportData.DateRangeInfo?
        let visits: [ExportableVisit]
        let points: [ExportableLocationPoint]
    }

    static func exportCombinedToJSON(visits: [Visit], points: [LocationPoint], options: ExportOptions = ExportOptions()) throws -> Data {
        let exportableVisits = visits.map { visit in
            ExportableVisit(
                latitude: options.includeVisitCoordinates ? visit.latitude : nil,
                longitude: options.includeVisitCoordinates ? visit.longitude : nil,
                arrivedAt: iso8601Formatter.string(from: visit.arrivedAt),
                departedAt: visit.departedAt.map { iso8601Formatter.string(from: $0) },
                durationMinutes: options.includeVisitDuration ? visit.durationMinutes : nil,
                locationName: options.includeVisitLocationName ? visit.locationName : nil,
                address: options.includeVisitAddress ? visit.address : nil,
                notes: options.includeVisitNotes ? visit.notes : nil
            )
        }

        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        let exportablePoints = sortedPoints.map { point in
            ExportableLocationPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: iso8601Formatter.string(from: point.timestamp),
                timestampUnix: point.timestamp.timeIntervalSince1970,
                altitude: options.includePointAltitude ? point.altitude : nil,
                speed: options.includePointSpeed ? point.speed : nil,
                course: nil,
                horizontalAccuracy: options.includePointAccuracy ? point.horizontalAccuracy : nil,
                verticalAccuracy: nil,
                isOutlier: options.includePointOutlierFlag ? point.isOutlier : nil
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

        let exportData = CombinedExportData(
            exportDate: iso8601Formatter.string(from: Date()),
            totalVisits: exportableVisits.count,
            totalPoints: exportablePoints.count,
            dateRange: dateRangeInfo,
            visits: exportableVisits,
            points: exportablePoints
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(exportData)
    }

    static func exportCombinedToCSV(visits: [Visit], points: [LocationPoint], options: ExportOptions = ExportOptions()) -> Data {
        var csvString = "# iso.me Combined Export\n"
        csvString.append("# Generated: \(iso8601Formatter.string(from: Date()))\n\n")

        csvString.append("# VISITS (\(visits.count))\n")
        let visitsCSV = String(data: exportToCSV(visits: visits, options: options), encoding: .utf8) ?? ""
        csvString.append(visitsCSV)

        csvString.append("\n# LOCATION POINTS (\(points.count))\n")
        let pointsCSV = String(data: exportLocationPointsToCSV(points: points, options: options), encoding: .utf8) ?? ""
        csvString.append(pointsCSV)

        return csvString.data(using: .utf8) ?? Data()
    }

    static func exportCombinedToMarkdown(visits: [Visit], points: [LocationPoint], options: ExportOptions = ExportOptions()) -> Data {
        var md = "# iso.me Complete Export\n\n"
        md += "**Export Date:** \(formattedDateReadable())\n\n"
        md += "**Total Visits:** \(visits.count)\n\n"
        md += "**Total Location Points:** \(points.count)\n\n"
        md += "---\n\n"

        md += String(data: exportToMarkdown(visits: visits, options: options), encoding: .utf8)?
            .replacingOccurrences(of: "# iso.me Export\n\n", with: "# Visits\n\n") ?? ""

        md += "\n---\n\n"

        md += String(data: exportLocationPointsToMarkdown(points: points, options: options), encoding: .utf8)?
            .replacingOccurrences(of: "# iso.me Location Points Export\n\n", with: "# Location Points\n\n") ?? ""

        return md.data(using: .utf8) ?? Data()
    }

    @MainActor
    static func shareCombined(visits: [Visit], points: [LocationPoint], format: ExportFormat, from viewController: UIViewController? = nil) throws {
        let data = try combinedData(visits: visits, points: points, format: format)

        let fileName = "isome_complete_export_\(formattedDate()).\(format.fileExtension)"
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

    @MainActor
    static func exportCombinedToDefaultFolder(visits: [Visit], points: [LocationPoint], format: ExportFormat) throws -> URL {
        let data = try combinedData(visits: visits, points: points, format: format)
        let fileName = "isome_complete_export_\(formattedDate()).\(format.fileExtension)"

        guard let savedURL = try ExportFolderManager.shared.saveToDefaultFolder(data: data, fileName: fileName) else {
            throw ExportFolderError.noDefaultFolder
        }

        return savedURL
    }

    private static func combinedData(visits: [Visit], points: [LocationPoint], format: ExportFormat, options: ExportOptions = ExportOptions()) throws -> Data {
        switch format {
        case .json: return try exportCombinedToJSON(visits: visits, points: points, options: options)
        case .csv: return exportCombinedToCSV(visits: visits, points: points, options: options)
        case .markdown: return exportCombinedToMarkdown(visits: visits, points: points, options: options)
        }
    }
}

// MARK: - Options-Driven Entrypoints

extension ExportService {
    /// Resolves the data, applies filters, and returns the encoded payload + suggested filename.
    static func render(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions
    ) throws -> (data: Data, fileName: String) {
        let filteredVisits = options.filterVisits(visits)
        let filteredPoints = options.filterPoints(points)

        let data: Data
        let prefix: String
        switch options.dataKind {
        case .visits:
            switch options.format {
            case .json: data = try exportToJSON(visits: filteredVisits, options: options)
            case .csv: data = exportToCSV(visits: filteredVisits, options: options)
            case .markdown: data = exportToMarkdown(visits: filteredVisits, options: options)
            }
            prefix = "isome_visits"
        case .points:
            switch options.format {
            case .json: data = try exportLocationPointsToJSON(points: filteredPoints, options: options)
            case .csv: data = exportLocationPointsToCSV(points: filteredPoints, options: options)
            case .markdown: data = exportLocationPointsToMarkdown(points: filteredPoints, options: options)
            }
            prefix = "isome_location_points"
        case .all:
            data = try combinedData(
                visits: filteredVisits,
                points: filteredPoints,
                format: options.format,
                options: options
            )
            prefix = "isome_complete_export"
        }

        let fileName = "\(prefix)_\(formattedDate()).\(options.format.fileExtension)"
        return (data, fileName)
    }

    @MainActor
    static func share(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions,
        from viewController: UIViewController? = nil
    ) throws {
        let rendered = try render(visits: visits, points: points, options: options)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(rendered.fileName)
        try rendered.data.write(to: tempURL)

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

    @MainActor
    static func saveToDefaultFolder(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions
    ) throws -> URL {
        let rendered = try render(visits: visits, points: points, options: options)
        guard let savedURL = try ExportFolderManager.shared.saveToDefaultFolder(data: rendered.data, fileName: rendered.fileName) else {
            throw ExportFolderError.noDefaultFolder
        }
        return savedURL
    }
}
