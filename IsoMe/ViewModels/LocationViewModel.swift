import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
@Observable
final class LocationViewModel {
    var locationManager: LocationManager
    private var modelContext: ModelContext

    // Cached data
    var todayVisits: [Visit] = []
    var allVisits: [Visit] = []
    /// Full point history. Loaded lazily for export so the map does not hydrate
    /// tens of thousands of SwiftData models on launch.
    var locationPoints: [LocationPoint] = []
    var todayLocationPoints: [LocationPoint] = []
    /// Downsampled points used by the map for the currently selected date range.
    var mapLocationPoints: [LocationPoint] = []
    /// Raw count for the current map date range, before downsampling.
    var mapLocationPointCount: Int = 0
    var totalLocationPointCount: Int = 0

    // UI State
    var mapDateRange: ClosedRange<Date> = Calendar.current.startOfDay(for: Date())...Date()
    var showingExportSheet = false
    var showingClearConfirmation = false
    var exportError: String?

    private var hasLoadedAllLocationPoints = false
    private var sessionLocationPointsCache: [LocationPoint] = []
    private var todayDistanceTraveledCache: Double = 0
    private var sessionDistanceTraveledCache: Double = 0
    private var cancellables = Set<AnyCancellable>()

    private let maximumMapPointCount = 2_500
    private let maximumRawMapPointFetchCount = 10_000
    private let mapFetchBatchSize = 500

    init(modelContext: ModelContext, locationManager: LocationManager) {
        self.modelContext = modelContext
        self.locationManager = locationManager
        locationManager.setModelContext(modelContext)

        loadData()

        // Observe location manager for new data points. Append the saved point to
        // in-memory caches instead of refetching the entire day on every update.
        locationManager.$lastSavedLocationPoints
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] points in
                self?.handleSavedLocationPoints(points)
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() {
        loadTodayVisits()
        loadAllVisits()
        refreshLocationPointCount()
        if locationManager.isTrackingEnabled {
            loadTodayLocationPoints()
        } else {
            todayLocationPoints = []
            refreshDerivedPointCaches()
        }
        loadMapLocationPoints(in: mapDateRange)
    }

    func loadTodayVisits() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<Visit> { visit in
            visit.arrivedAt >= startOfDay && visit.arrivedAt < endOfDay
        }

        var descriptor = FetchDescriptor<Visit>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .forward)]

        do {
            todayVisits = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch today's visits: \(error)")
            todayVisits = []
        }
    }

    func loadAllVisits() {
        var descriptor = FetchDescriptor<Visit>()
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .reverse)]

        do {
            allVisits = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch all visits: \(error)")
            allVisits = []
        }
    }

    func refreshLocationPointCount() {
        do {
            totalLocationPointCount = try modelContext.fetchCount(FetchDescriptor<LocationPoint>())
        } catch {
            print("Failed to count location points: \(error)")
            totalLocationPointCount = hasLoadedAllLocationPoints ? locationPoints.count : mapLocationPointCount
        }
    }

    func ensureAllLocationPointsLoaded() {
        guard !hasLoadedAllLocationPoints else { return }
        loadLocationPoints()
    }

    func loadLocationPoints() {
        var descriptor = FetchDescriptor<LocationPoint>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        do {
            locationPoints = try modelContext.fetch(descriptor)
            hasLoadedAllLocationPoints = true
            totalLocationPointCount = locationPoints.count
        } catch {
            print("Failed to fetch location points: \(error)")
            locationPoints = []
            hasLoadedAllLocationPoints = false
        }
    }

    func loadMapLocationPoints(in range: ClosedRange<Date>? = nil) {
        let range = range ?? mapDateRange
        let start = range.lowerBound
        let end = range.upperBound

        let predicate = #Predicate<LocationPoint> { point in
            point.timestamp >= start && point.timestamp <= end
        }

        do {
            let countDescriptor = FetchDescriptor<LocationPoint>(predicate: predicate)
            let rawCount = try modelContext.fetchCount(countDescriptor)

            let points: [LocationPoint]
            if rawCount > maximumRawMapPointFetchCount {
                points = try fetchSampledMapPoints(predicate: predicate, rawCount: rawCount)
            } else {
                var descriptor = FetchDescriptor<LocationPoint>(predicate: predicate)
                descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
                points = try modelContext.fetch(descriptor)
            }
            mapLocationPointCount = rawCount
            mapLocationPoints = downsample(points: points, maxCount: maximumMapPointCount)
        } catch {
            print("Failed to fetch map location points: \(error)")
            mapLocationPointCount = 0
            mapLocationPoints = []
        }
    }

    func loadTodayLocationPoints() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<LocationPoint> { point in
            point.timestamp >= startOfDay && point.timestamp < endOfDay
        }

        var descriptor = FetchDescriptor<LocationPoint>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        do {
            todayLocationPoints = try modelContext.fetch(descriptor)
            refreshDerivedPointCaches()
        } catch {
            print("Failed to fetch today's location points: \(error)")
            todayLocationPoints = []
            refreshDerivedPointCaches()
        }
    }

    private func fetchSampledMapPoints(
        predicate: Predicate<LocationPoint>,
        rawCount: Int
    ) throws -> [LocationPoint] {
        let batchCount = max(1, Int(ceil(Double(maximumRawMapPointFetchCount) / Double(mapFetchBatchSize))))
        let maxOffset = max(0, rawCount - mapFetchBatchSize)
        var sampled: [LocationPoint] = []
        sampled.reserveCapacity(min(maximumRawMapPointFetchCount, rawCount))
        var usedOffsets = Set<Int>()

        for batchIndex in 0..<batchCount {
            let offset: Int
            if batchCount == 1 {
                offset = 0
            } else {
                offset = Int((Double(batchIndex) * Double(maxOffset) / Double(batchCount - 1)).rounded())
            }

            guard usedOffsets.insert(offset).inserted else { continue }

            var descriptor = FetchDescriptor<LocationPoint>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = mapFetchBatchSize
            sampled.append(contentsOf: try modelContext.fetch(descriptor))
        }

        return sampled.sorted { $0.timestamp < $1.timestamp }
    }

    private func fetchLocationPoints(in range: ClosedRange<Date>? = nil) -> [LocationPoint] {
        var descriptor: FetchDescriptor<LocationPoint>

        if let range {
            let start = range.lowerBound
            let end = range.upperBound
            let predicate = #Predicate<LocationPoint> { point in
                point.timestamp >= start && point.timestamp <= end
            }
            descriptor = FetchDescriptor<LocationPoint>(predicate: predicate)
        } else {
            descriptor = FetchDescriptor<LocationPoint>()
        }

        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch location points: \(error)")
            return []
        }
    }

    private func handleSavedLocationPoints(_ points: [LocationPoint]) {
        guard !points.isEmpty else {
            refreshLocationPointCount()
            loadTodayLocationPoints()
            loadMapLocationPoints(in: mapDateRange)
            if hasLoadedAllLocationPoints {
                loadLocationPoints()
            }
            return
        }

        let orderedPoints = points.sorted { $0.timestamp < $1.timestamp }
        totalLocationPointCount += orderedPoints.count

        if hasLoadedAllLocationPoints {
            locationPoints.append(contentsOf: orderedPoints)
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        var didAppendMapPoint = false

        for point in orderedPoints {
            if point.timestamp >= startOfToday && point.timestamp < endOfToday {
                let previousTodayPoint = todayLocationPoints.last
                todayLocationPoints.append(point)

                if let previousTodayPoint {
                    todayDistanceTraveledCache += previousTodayPoint.distance(to: point)
                }

                if let sessionStart = locationManager.trackingStartTime,
                   point.timestamp >= sessionStart {
                    if let previousSessionPoint = sessionLocationPointsCache.last {
                        sessionDistanceTraveledCache += previousSessionPoint.distance(to: point)
                    }
                    sessionLocationPointsCache.append(point)
                }
            }

            if mapDateRange.contains(point.timestamp) {
                mapLocationPointCount += 1
                mapLocationPoints.append(point)
                didAppendMapPoint = true
            }
        }

        if didAppendMapPoint {
            mapLocationPoints.sort { $0.timestamp < $1.timestamp }
            mapLocationPoints = downsample(points: mapLocationPoints, maxCount: maximumMapPointCount)
        }
    }

    private func refreshDerivedPointCaches() {
        todayDistanceTraveledCache = totalDistance(in: todayLocationPoints)

        guard let sessionStart = locationManager.trackingStartTime else {
            sessionLocationPointsCache = []
            sessionDistanceTraveledCache = 0
            return
        }

        sessionLocationPointsCache = todayLocationPoints.filter { $0.timestamp >= sessionStart }
        sessionDistanceTraveledCache = totalDistance(in: sessionLocationPointsCache)
    }

    private func totalDistance(in points: [LocationPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var total: Double = 0
        for index in 1..<points.count {
            total += points[index - 1].distance(to: points[index])
        }
        return total
    }

    private func downsample(points: [LocationPoint], maxCount: Int) -> [LocationPoint] {
        guard points.count > maxCount else { return points }
        guard maxCount > 1 else { return Array(points.prefix(max(0, maxCount))) }

        let lastIndex = points.count - 1
        let denominator = Double(maxCount - 1)
        var sampled: [LocationPoint] = []
        sampled.reserveCapacity(maxCount)

        for outputIndex in 0..<maxCount {
            let sourceIndex = Int((Double(outputIndex) * Double(lastIndex) / denominator).rounded())
            sampled.append(points[sourceIndex])
        }

        return sampled
    }

    // MARK: - Computed Properties

    var currentVisit: Visit? {
        todayVisits.first { $0.isCurrentVisit }
    }

    // Session-specific location points (only points from current tracking session)
    var sessionLocationPoints: [LocationPoint] {
        guard locationManager.trackingStartTime != nil else { return [] }
        return sessionLocationPointsCache
    }

    var sessionMapLocationPoints: [LocationPoint] {
        downsample(points: sessionLocationPoints, maxCount: maximumMapPointCount)
    }

    // Session tracking stats
    var sessionTrackingDuration: TimeInterval {
        guard let sessionStart = locationManager.trackingStartTime else { return 0 }
        return Date().timeIntervalSince(sessionStart)
    }

    var sessionDistanceTraveled: Double {
        sessionDistanceTraveledCache
    }

    var formattedSessionTrackingDuration: String {
        let totalSeconds = Int(sessionTrackingDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes < 60 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, seconds)
        }
    }

    var formattedSessionDistance: String {
        formatDistance(sessionDistanceTraveled)
    }

    var sessionAccessibilitySummary: String {
        let pointCount = sessionLocationPoints.count
        guard pointCount > 0 else {
            return "No active session path points."
        }

        var parts = [
            "\(pointCount) \(pointCount == 1 ? "point" : "points")",
            "Duration \(formattedSessionTrackingDuration)",
            "Distance \(formattedSessionDistance)"
        ]

        if let first = sessionLocationPoints.first {
            parts.append("Started \(first.accessibilityTimestamp)")
        }

        if let last = sessionLocationPoints.last, pointCount > 1 {
            parts.append("Latest point \(last.accessibilityTimestamp)")
        }

        return parts.joined(separator: ". ")
    }

    // Today's tracking stats (kept for other views)
    var todayTrackingDuration: TimeInterval {
        guard let first = todayLocationPoints.first,
              let last = todayLocationPoints.last else { return 0 }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }

    var todayDistanceTraveled: Double {
        todayDistanceTraveledCache
    }

    var formattedTodayTrackingDuration: String {
        let minutes = Int(todayTrackingDuration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }

    var formattedTodayDistance: String {
        formatDistance(todayDistanceTraveled)
    }

    private var usesMetricDistanceUnits: Bool {
        let key = "usesMetricDistanceUnits"
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func formatDistance(_ meters: Double) -> String {
        DistanceFormatter.format(meters: meters, usesMetric: usesMetricDistanceUnits)
    }

    func visitsInDateRange(_ range: ClosedRange<Date>) -> [Visit] {
        allVisits.filter { range.contains($0.arrivedAt) }
    }

    func locationPointsInDateRange(_ range: ClosedRange<Date>) -> [LocationPoint] {
        fetchLocationPoints(in: range)
    }

    // MARK: - Visit Management

    func deleteVisit(_ visit: Visit) {
        modelContext.delete(visit)
        try? modelContext.save()
        loadData()
    }

    func updateVisitName(_ visit: Visit, customName: String) {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == visit.automaticDisplayName {
            visit.customName = nil
        } else {
            visit.customName = trimmed
        }
        try? modelContext.save()
        loadTodayVisits()
        loadAllVisits()
    }

    func clearVisitName(_ visit: Visit) {
        visit.customName = nil
        try? modelContext.save()
        loadTodayVisits()
        loadAllVisits()
    }

    func updateVisitNotes(_ visit: Visit, notes: String) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.notes = trimmed.isEmpty ? nil : notes
        try? modelContext.save()
    }

    // MARK: - Export

    func exportVisits(format: ExportFormat, dateRange: ClosedRange<Date>? = nil) {
        let visitsToExport: [Visit]
        if let range = dateRange {
            visitsToExport = visitsInDateRange(range)
        } else {
            visitsToExport = allVisits
        }

        do {
            try ExportService.share(
                visits: visitsToExport,
                format: format,
                completion: Self.recordSuccessfulShareExportForReviewPrompt
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    func exportLocationPoints(format: ExportFormat, dateRange: ClosedRange<Date>? = nil) {
        let pointsToExport = fetchLocationPoints(in: dateRange)

        if dateRange == nil {
            locationPoints = pointsToExport
            hasLoadedAllLocationPoints = true
            totalLocationPointCount = pointsToExport.count
        }

        do {
            try ExportService.shareLocationPoints(
                points: pointsToExport,
                format: format,
                completion: Self.recordSuccessfulShareExportForReviewPrompt
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    func exportAllData(format: ExportFormat) {
        let pointsToExport = fetchLocationPoints()
        locationPoints = pointsToExport
        hasLoadedAllLocationPoints = true
        totalLocationPointCount = pointsToExport.count

        do {
            try ExportService.shareCombined(
                visits: allVisits,
                points: pointsToExport,
                format: format,
                completion: Self.recordSuccessfulShareExportForReviewPrompt
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    @MainActor
    func exportWithOptions(_ options: ExportOptions) {
        let needsPoints = options.dataKind != .visits || options.format.isPointsOnly
        let pointsToExport = needsPoints ? fetchLocationPoints(in: options.resolvedDateRange()) : []

        if needsPoints && options.resolvedDateRange() == nil {
            locationPoints = pointsToExport
            hasLoadedAllLocationPoints = true
            totalLocationPointCount = pointsToExport.count
        }

        do {
            try ExportService.share(
                visits: allVisits,
                points: pointsToExport,
                options: options,
                completion: Self.recordSuccessfulShareExportForReviewPrompt
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    private static func recordSuccessfulShareExportForReviewPrompt(completed: Bool) {
        guard completed else { return }
        Task { @MainActor in
            AppReviewPromptCoordinator.shared.recordSuccessfulFileExport()
        }
    }

    // MARK: - Import

    func importData(from url: URL) throws -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.invalidData("Cannot access file")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let format = ImportService.detectFormat(url: url) else {
            throw ImportError.unsupportedFormat
        }

        let data = try Data(contentsOf: url)
        let result = try ImportService.importFile(data: data, format: format)

        for imported in result.visits {
            let visit = Visit(
                latitude: imported.latitude,
                longitude: imported.longitude,
                arrivedAt: imported.arrivedAt,
                departedAt: imported.departedAt,
                locationName: imported.locationName,
                address: imported.address,
                notes: imported.notes,
                geocodingCompleted: imported.locationName != nil || imported.address != nil
            )
            modelContext.insert(visit)
        }

        for imported in result.points {
            let point = LocationPoint(
                latitude: imported.latitude,
                longitude: imported.longitude,
                timestamp: imported.timestamp,
                altitude: imported.altitude,
                speed: imported.speed,
                horizontalAccuracy: imported.horizontalAccuracy,
                isOutlier: imported.isOutlier
            )
            modelContext.insert(point)
        }

        try modelContext.save()
        if !result.points.isEmpty {
            locationPoints = []
            hasLoadedAllLocationPoints = false
        }
        loadData()

        return ImportResult(visitCount: result.visits.count, pointCount: result.points.count)
    }

    // MARK: - Clear Data

    func clearAllData() {
        do {
            try modelContext.delete(model: Visit.self)
            try modelContext.delete(model: LocationPoint.self)
            try modelContext.save()
            locationPoints = []
            todayLocationPoints = []
            mapLocationPoints = []
            sessionLocationPointsCache = []
            mapLocationPointCount = 0
            totalLocationPointCount = 0
            todayDistanceTraveledCache = 0
            sessionDistanceTraveledCache = 0
            hasLoadedAllLocationPoints = false
            loadData()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }

    // MARK: - Tracking Control

    func startTracking() {
        locationManager.startTracking()
        refreshDerivedPointCaches()
    }

    func stopTracking() {
        locationManager.stopTracking()
        refreshDerivedPointCaches()
    }
}
