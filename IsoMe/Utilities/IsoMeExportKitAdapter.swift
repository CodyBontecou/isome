import Foundation
import ExportKit

/// App-local bridge from iso.me's SwiftData models and export settings into the
/// domain-free ExportKit primitives. ExportKit never sees `Visit`,
/// `LocationPoint`, or iso.me's UI/settings copy except through this adapter.
struct IsoMeExportSnapshot: ExportRecord {
    let id: String
    let exportDate: Date
    let visits: [Visit]
    let points: [LocationPoint]
    let options: ExportOptions
    let dataKind: ExportOptions.DataKind
    let isSplitByDay: Bool

    var exportRecordID: String { id }
}

enum IsoMeExportKitError: LocalizedError, Equatable {
    case missingFormat(String)
    case nonUTF8Payload(formatID: String)
    case noDestination

    var errorDescription: String? {
        switch self {
        case .missingFormat(let id):
            return "Unsupported export format: \(id)"
        case .nonUTF8Payload(let formatID):
            return "Export payload for \(formatID) was not valid UTF-8 text."
        case .noDestination:
            return "No export destination was provided."
        }
    }
}

enum IsoMeExportPathPlanner {
    static func plannedRelativePath(
        pattern: String,
        dataKind: ExportOptions.DataKind,
        format: ExportFormat,
        date: Date = Date(),
        safetyPolicy: ExportPathSafetyPolicy = .rejectTraversalAndAbsolutePaths
    ) throws -> String {
        let expandedPath = FilenameTemplate.stem(
            pattern: pattern,
            dataKind: dataKind,
            format: format,
            date: date
        )

        // Validate the raw user-expanded pattern before applying filename/path
        // sanitization so obvious traversal/absolute-path attempts are rejected
        // instead of silently rewritten into a surprising destination. Forward
        // slashes are intentionally preserved as folder separators.
        let rawPath = FilenameTemplate.appendingFormatExtensionIfNeeded(
            to: expandedPath,
            format: format
        )
        .replacingOccurrences(of: "\\", with: "/")
        _ = try ExportPathSafetyPolicy.rejectTraversalAndAbsolutePaths.pathSegments(from: rawPath)

        let sanitizedPath = FilenameTemplate.sanitizePath(rawPath)
        return try safetyPolicy.pathSegments(from: sanitizedPath).joined(separator: "/")
    }
}

enum IsoMeExportKitAdapter {
    static let allFormats: [ExportFormat] = ExportFormat.allCases

    static func descriptor(for format: ExportFormat) -> ExportFormatDescriptor {
        ExportFormatDescriptor(
            id: format.exportKitFormatID,
            displayName: format.displayName,
            fileExtension: format.fileExtension,
            contentType: format.mimeType,
            defaultSortKey: format.defaultSortKey
        )
    }

    static func rendererRegistry() throws -> ExportRendererRegistry<IsoMeExportSnapshot> {
        try ExportRendererRegistry(renderers: allFormats.map { format in
            AnyExportRenderer<IsoMeExportSnapshot>(descriptor: descriptor(for: format)) { snapshot, _ in
                let data = try renderData(
                    visits: snapshot.visits,
                    points: snapshot.points,
                    dataKind: snapshot.dataKind,
                    format: format,
                    options: snapshot.options
                )
                guard let content = String(data: data, encoding: .utf8) else {
                    throw IsoMeExportKitError.nonUTF8Payload(formatID: format.exportKitFormatID)
                }
                return RenderedExport(content: content, contentType: format.mimeType)
            }
        })
    }

    static func render(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions,
        filenamePattern: String = FilenameTemplate.defaultPattern
    ) throws -> (data: Data, fileName: String) {
        guard let file = try plannedFiles(
            visits: visits,
            points: points,
            options: options,
            filenamePattern: filenamePattern,
            forceSplitByDay: false
        ).first else {
            let effectiveKind = effectiveDataKind(for: options)
            let fileName = try IsoMeExportPathPlanner.plannedRelativePath(
                pattern: filenamePattern,
                dataKind: effectiveKind,
                format: options.format
            )
            return (Data(), fileName)
        }

        return (Data(file.content.utf8), file.relativePath)
    }

    static func renderPerDay(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions,
        filenamePattern: String = FilenameTemplate.defaultPattern
    ) throws -> [(data: Data, fileName: String)] {
        try plannedFiles(
            visits: visits,
            points: points,
            options: options,
            filenamePattern: filenamePattern,
            forceSplitByDay: true
        ).map { (Data($0.content.utf8), $0.relativePath) }
    }

    static func plannedFiles(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions,
        filenamePattern: String = FilenameTemplate.defaultPattern,
        forceSplitByDay: Bool? = nil
    ) throws -> [PlannedExportFile] {
        let splitByDay = forceSplitByDay ?? options.splitByDay
        let snapshots = try exportSnapshots(
            visits: visits,
            points: points,
            options: options,
            splitByDay: splitByDay
        )
        let registry = try rendererRegistry()
        var usedNames = Set<String>()

        return try snapshots.map { snapshot in
            let descriptor = descriptor(for: options.format)
            let rendered = try registry.render(
                record: snapshot,
                formatID: descriptor.id,
                context: .default
            )
            var fileName = try IsoMeExportPathPlanner.plannedRelativePath(
                pattern: filenamePattern,
                dataKind: snapshot.dataKind,
                format: options.format,
                date: snapshot.exportDate
            )
            if snapshot.isSplitByDay {
                fileName = uniqueFilename(fileName, in: &usedNames, day: snapshot.exportDate, format: options.format)
            }
            return PlannedExportFile(
                id: "\(snapshot.exportRecordID)-\(descriptor.id)",
                role: .aggregate(formatID: descriptor.id),
                relativePath: fileName,
                content: rendered.content,
                format: descriptor,
                contentType: rendered.contentType,
                displayName: descriptor.displayName,
                estimatedByteCount: rendered.content.utf8.count
            )
        }
    }

    static func preview(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions,
        filenamePattern: String = FilenameTemplate.defaultPattern
    ) async throws -> ExportPreview {
        let snapshots = try exportSnapshots(
            visits: visits,
            points: points,
            options: options,
            splitByDay: options.splitByDay
        )
        let registry = try rendererRegistry()
        var usedNames = Set<String>()

        let dataSource = AnyExportRecordDataSource<IsoMeExportSnapshot, IsoMeExportSnapshot> { snapshot in
            ExportFetchedRecord(record: snapshot)
        }

        let request = ExportPreviewRequest(
            recordInputs: snapshots,
            selectedFormatIDs: [options.format.exportKitFormatID],
            dataSource: dataSource,
            rendererRegistry: registry,
            recordReference: { snapshot in
                ExportRecordReference(
                    id: snapshot.exportRecordID,
                    date: snapshot.exportDate,
                    displayName: snapshot.exportRecordID
                )
            },
            planAggregateFile: { snapshot, descriptor, rendered in
                guard let format = ExportFormat(exportKitFormatID: descriptor.id) else {
                    throw IsoMeExportKitError.missingFormat(descriptor.id)
                }
                var fileName = try IsoMeExportPathPlanner.plannedRelativePath(
                    pattern: filenamePattern,
                    dataKind: snapshot.dataKind,
                    format: format,
                    date: snapshot.exportDate,
                    safetyPolicy: .preserveCurrentBehavior
                )
                if snapshot.isSplitByDay {
                    fileName = uniqueFilename(fileName, in: &usedNames, day: snapshot.exportDate, format: format)
                }
                return PlannedExportFile(
                    id: "\(snapshot.exportRecordID)-\(descriptor.id)",
                    role: .aggregate(formatID: descriptor.id),
                    relativePath: fileName,
                    content: rendered.content,
                    format: descriptor,
                    contentType: rendered.contentType,
                    displayName: descriptor.displayName,
                    estimatedByteCount: rendered.content.utf8.count
                )
            }
        )

        return try await ExportPreviewBuilder<IsoMeExportSnapshot, IsoMeExportSnapshot>().buildPreview(request)
    }

    static func writeTemporaryFiles(_ files: [PlannedExportFile]) throws -> [URL] {
        let destination = ExportDestination(
            rootURL: FileManager.default.temporaryDirectory,
            displayName: "Temporary Exports"
        )
        let writer = ExportFileWriter(
            fileSystem: FileManagerExportFileSystem(),
            safetyPolicy: .rejectTraversalAndAbsolutePaths
        )
        return try writer.write(files, to: destination, mode: .overwrite).map(\.url)
    }

    static func run(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions,
        filenamePattern: String = FilenameTemplate.defaultPattern,
        destination: ExportDestination?,
        writeMode: ExportWriteMode = .overwrite
    ) async -> ExportRunResult {
        let splitByDay = options.splitByDay
        let snapshots: [IsoMeExportSnapshot]
        do {
            snapshots = try exportSnapshots(visits: visits, points: points, options: options, splitByDay: splitByDay)
        } catch {
            return ExportRunResult(
                successCount: 0,
                totalCount: 1,
                filesWritten: 0,
                failedRecords: [ExportFailedRecord(
                    record: ExportRecordReference(id: "iso.me-export"),
                    failure: failure(for: error)
                )],
                formatsPerRecord: 1
            )
        }

        var usedNames = Set<String>()
        let dataSource = AnyExportRecordDataSource<IsoMeExportSnapshot, IsoMeExportSnapshot> { snapshot in
            ExportFetchedRecord(record: snapshot)
        }
        let fileWriter = ExportFileWriter(
            fileSystem: FileManagerExportFileSystem(),
            safetyPolicy: .rejectTraversalAndAbsolutePaths
        )

        let writer = AnyExportRecordWriter<IsoMeExportSnapshot> { snapshot, context in
            guard let destination = context.destination else {
                throw IsoMeExportKitError.noDestination
            }
            let descriptor = descriptor(for: options.format)
            let registry = try rendererRegistry()
            let rendered = try registry.render(record: snapshot, formatID: descriptor.id)
            var fileName = try IsoMeExportPathPlanner.plannedRelativePath(
                pattern: filenamePattern,
                dataKind: snapshot.dataKind,
                format: options.format,
                date: snapshot.exportDate
            )
            if snapshot.isSplitByDay {
                fileName = uniqueFilename(fileName, in: &usedNames, day: snapshot.exportDate, format: options.format)
            }
            let file = PlannedExportFile(
                id: "\(snapshot.exportRecordID)-\(descriptor.id)",
                role: .aggregate(formatID: descriptor.id),
                relativePath: fileName,
                content: rendered.content,
                format: descriptor,
                contentType: rendered.contentType,
                displayName: descriptor.displayName,
                estimatedByteCount: rendered.content.utf8.count
            )
            let results = try fileWriter.write([file], to: destination, mode: context.writeMode)
            return ExportRecordWriteSummary(filesWritten: results.count)
        }

        let orchestrator = ExportRunOrchestrator(
            dataSource: dataSource,
            writer: writer,
            failureMapper: failure(for:)
        )
        let request = ExportRunRequest(
            recordInputs: snapshots,
            formatIDs: [options.format.exportKitFormatID],
            destination: destination,
            writeMode: writeMode,
            recordReference: { snapshot in
                ExportRecordReference(id: snapshot.exportRecordID, date: snapshot.exportDate)
            }
        )
        return await orchestrator.run(request)
    }

    private static func exportSnapshots(
        visits: [Visit],
        points: [LocationPoint],
        options: ExportOptions,
        splitByDay: Bool
    ) throws -> [IsoMeExportSnapshot] {
        let filteredVisits = options.filterVisits(visits)
        let filteredPoints = options.filterPoints(points)
        let effectiveKind = effectiveDataKind(for: options)

        guard splitByDay else {
            return [IsoMeExportSnapshot(
                id: "iso.me-\(effectiveKind.rawValue)",
                exportDate: Date(),
                visits: filteredVisits,
                points: filteredPoints,
                options: options,
                dataKind: effectiveKind,
                isSplitByDay: false
            )]
        }

        return options.groupByDay(visits: filteredVisits, points: filteredPoints).map { group in
            var dayOptions = options
            dayOptions.datePreset = .allTime
            dayOptions.timeOfDayEnabled = false
            dayOptions.excludeOutliers = false
            dayOptions.onlyCompletedVisits = false
            dayOptions.minVisitDurationMinutes = 0
            dayOptions.maxAccuracyMeters = 0
            dayOptions.splitByDay = false
            let dayKind = effectiveDataKind(for: dayOptions)
            return IsoMeExportSnapshot(
                id: dayIdentifier(for: group.day, dataKind: dayKind),
                exportDate: group.day,
                visits: group.visits,
                points: group.points,
                options: dayOptions,
                dataKind: dayKind,
                isSplitByDay: true
            )
        }
    }

    private static func renderData(
        visits: [Visit],
        points: [LocationPoint],
        dataKind: ExportOptions.DataKind,
        format: ExportFormat,
        options: ExportOptions
    ) throws -> Data {
        switch dataKind {
        case .visits:
            switch format {
            case .json: return try ExportService.exportToJSON(visits: visits, options: options)
            case .csv: return ExportService.exportToCSV(visits: visits, options: options)
            case .markdown: return ExportService.exportToMarkdown(visits: visits, options: options)
            case .owntracks, .overland: return try ExportService.exportToJSON(visits: visits, options: options)
            case .gpx: return ExportService.exportVisitsToGPX(visits: visits, options: options)
            case .kml: return ExportService.exportVisitsToKML(visits: visits, options: options)
            case .geojson: return try ExportService.exportVisitsToGeoJSON(visits: visits, options: options)
            }
        case .points:
            switch format {
            case .json: return try ExportService.exportLocationPointsToJSON(points: points, options: options)
            case .csv: return ExportService.exportLocationPointsToCSV(points: points, options: options)
            case .markdown: return ExportService.exportLocationPointsToMarkdown(points: points, options: options)
            case .owntracks: return try ExportService.exportLocationPointsToOwnTracks(points: points, options: options)
            case .overland: return try ExportService.exportLocationPointsToOverland(points: points, options: options)
            case .gpx: return ExportService.exportLocationPointsToGPX(points: points, options: options)
            case .kml: return ExportService.exportLocationPointsToKML(points: points, options: options)
            case .geojson: return try ExportService.exportLocationPointsToGeoJSON(points: points, options: options)
            }
        case .all:
            return try ExportService.combinedData(visits: visits, points: points, format: format, options: options)
        }
    }

    private static func effectiveDataKind(for options: ExportOptions) -> ExportOptions.DataKind {
        options.format.isPointsOnly ? .points : options.dataKind
    }

    private static func failure(for error: Error) -> ExportRunFailure {
        if error as? IsoMeExportKitError == .noDestination {
            return ExportRunFailure(reason: .noDestination, errorDescription: error.localizedDescription)
        }
        if error is ExportPathTemplateError {
            return ExportRunFailure(reason: .writeError, errorDescription: error.localizedDescription)
        }
        if error is ExportFolderError {
            return ExportRunFailure(reason: .accessDenied, errorDescription: error.localizedDescription)
        }
        return ExportRunFailure(reason: .unknown, errorDescription: error.localizedDescription)
    }

    private static func dayIdentifier(for day: Date, dataKind: ExportOptions.DataKind) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "iso.me-\(dataKind.rawValue)-\(formatter.string(from: day))"
    }

    private static func uniqueFilename(
        _ baseName: String,
        in used: inout Set<String>,
        day: Date,
        format: ExportFormat
    ) -> String {
        if !used.contains(baseName) {
            used.insert(baseName)
            return baseName
        }

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.dateFormat = "yyyy-MM-dd"
        let isoDay = dateFmt.string(from: day)

        let ext = ".\(format.fileExtension)"
        let splitIndex = baseName.lastIndex(of: "/")
        let directoryPrefix: String
        let filename: String
        if let splitIndex {
            directoryPrefix = String(baseName[...splitIndex])
            filename = String(baseName[baseName.index(after: splitIndex)...])
        } else {
            directoryPrefix = ""
            filename = baseName
        }

        let stem: String
        if filename.lowercased().hasSuffix(ext.lowercased()) {
            stem = String(filename.dropLast(ext.count))
        } else {
            stem = filename
        }

        var candidate = "\(directoryPrefix)\(isoDay)_\(stem)\(ext)"
        var counter = 2
        while used.contains(candidate) {
            candidate = "\(directoryPrefix)\(isoDay)_\(stem)_\(counter)\(ext)"
            counter += 1
        }
        used.insert(candidate)
        return candidate
    }
}

extension ExportFormat {
    var exportKitFormatID: String { token }

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .markdown: return "Markdown"
        case .owntracks: return "OwnTracks"
        case .overland: return "Overland"
        case .gpx: return "GPX"
        case .kml: return "KML"
        case .geojson: return "GeoJSON"
        }
    }

    var defaultSortKey: String {
        switch self {
        case .json: return "10-json"
        case .csv: return "20-csv"
        case .markdown: return "30-markdown"
        case .owntracks: return "40-owntracks"
        case .overland: return "50-overland"
        case .gpx: return "60-gpx"
        case .kml: return "70-kml"
        case .geojson: return "80-geojson"
        }
    }

    init?(exportKitFormatID: String) {
        guard let format = Self.allCases.first(where: { $0.exportKitFormatID == exportKitFormatID }) else {
            return nil
        }
        self = format
    }
}
