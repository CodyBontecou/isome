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
    /// Full point cache used by export flows. It is intentionally loaded on demand
    /// because long trips can contain tens of thousands of points.
    var locationPoints: [LocationPoint] = []
    /// Point cache for the currently selected map range.
    var mapLocationPoints: [LocationPoint] = []
    var todayLocationPoints: [LocationPoint] = []
    var locationPointCount = 0

    private var allLocationPointsLoaded = false
    private var todayLocationPointsDay = Calendar.current.startOfDay(for: Date())

    // UI State
    var activeMapPreset: MapDatePreset? = .today
    var mapDateRange: ClosedRange<Date> = MapDatePreset.today.range()
    var showingExportSheet = false
    var showingClearConfirmation = false
    var exportError: String?

    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext, locationManager: LocationManager) {
        self.modelContext = modelContext
        self.locationManager = locationManager
        locationManager.setModelContext(modelContext)

        loadData()
        
        // Observe location manager for new data points and append incrementally.
        // Re-fetching every stored point after each GPS update becomes expensive
        // once a user has a road trip worth of fixes saved locally.
        locationManager.$locationPointsSavedCount
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.appendLatestSavedLocationPoint()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() {
        loadTodayVisits()
        loadAllVisits()
        loadMapLocationPoints()
        loadTodayLocationPoints()
        loadLocationPointCount()
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

    private func fetchLocationPoints(in range: ClosedRange<Date>? = nil) throws -> [LocationPoint] {
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
        return try modelContext.fetch(descriptor)
    }

    /// Loads all stored points for export-related screens only.
    func loadLocationPoints() {
        do {
            locationPoints = try fetchLocationPoints()
            locationPointCount = locationPoints.count
            allLocationPointsLoaded = true
        } catch {
            print("Failed to fetch location points: \(error)")
            locationPoints = []
            allLocationPointsLoaded = false
        }
    }

    func selectMapPreset(_ preset: MapDatePreset, referenceDate: Date = Date()) {
        activeMapPreset = preset
        mapDateRange = preset.range(referenceDate: referenceDate)
        loadMapLocationPoints(referenceDate: referenceDate)
    }

    func setCustomMapDateRange(_ range: ClosedRange<Date>) {
        activeMapPreset = nil
        mapDateRange = range
        loadMapLocationPoints()
    }

    @discardableResult
    func refreshMapDateRangeIfUsingPreset(referenceDate: Date = Date()) -> Bool {
        guard let preset = activeMapPreset else { return false }

        let refreshedRange = preset.range(referenceDate: referenceDate)
        let didChange = mapDateRange.lowerBound != refreshedRange.lowerBound ||
            mapDateRange.upperBound != refreshedRange.upperBound
        guard didChange else { return false }

        mapDateRange = refreshedRange
        return true
    }

    func loadMapLocationPoints(referenceDate: Date = Date()) {
        refreshMapDateRangeIfUsingPreset(referenceDate: referenceDate)

        do {
            mapLocationPoints = try fetchLocationPoints(in: mapDateRange)
        } catch {
            print("Failed to fetch map location points: \(error)")
            mapLocationPoints = []
        }
    }

    func loadLocationPointCount() {
        do {
            let descriptor = FetchDescriptor<LocationPoint>()
            locationPointCount = try modelContext.fetchCount(descriptor)
        } catch {
            print("Failed to count location points: \(error)")
            locationPointCount = locationPoints.count
        }
    }

    func loadTodayLocationPoints(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        todayLocationPointsDay = startOfDay

        let predicate = #Predicate<LocationPoint> { point in
            point.timestamp >= startOfDay && point.timestamp < endOfDay
        }

        var descriptor = FetchDescriptor<LocationPoint>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        do {
            todayLocationPoints = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch today's location points: \(error)")
            todayLocationPoints = []
        }
    }

    func appendLatestSavedLocationPoint(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: referenceDate)
        let didCalendarDayChange = todayLocationPointsDay != currentDay

        if didCalendarDayChange {
            loadTodayLocationPoints(referenceDate: referenceDate)
        }

        guard let point = locationManager.latestSavedLocationPoint else {
            if !didCalendarDayChange {
                loadTodayLocationPoints(referenceDate: referenceDate)
            }
            loadMapLocationPoints(referenceDate: referenceDate)
            loadLocationPointCount()
            return
        }

        let mapReferenceDate = max(referenceDate, point.timestamp)
        let previousMapRange = mapDateRange
        let didRefreshMapRange = refreshMapDateRangeIfUsingPreset(referenceDate: mapReferenceDate)
        let shouldReloadMapCache = shouldReloadMapCacheAfterPresetRefresh(
            from: previousMapRange,
            didRefresh: didRefreshMapRange
        )

        locationPointCount += 1

        if allLocationPointsLoaded {
            append(point, to: &locationPoints)
        }

        if calendar.isDate(point.timestamp, inSameDayAs: referenceDate) {
            append(point, to: &todayLocationPoints)
        }

        if shouldReloadMapCache {
            loadMapLocationPoints(referenceDate: mapReferenceDate)
        } else if mapDateRange.contains(point.timestamp) {
            append(point, to: &mapLocationPoints)
        }
    }

    private func shouldReloadMapCacheAfterPresetRefresh(
        from previousRange: ClosedRange<Date>,
        didRefresh: Bool
    ) -> Bool {
        guard didRefresh, activeMapPreset != nil else { return false }
        return !Calendar.current.isDate(previousRange.lowerBound, inSameDayAs: mapDateRange.lowerBound)
    }

    private func append(_ point: LocationPoint, to points: inout [LocationPoint]) {
        if points.contains(where: { $0.id == point.id }) {
            return
        }

        if let last = points.last, last.timestamp > point.timestamp {
            points.append(point)
            points.sort { $0.timestamp < $1.timestamp }
        } else {
            points.append(point)
        }
    }

    // MARK: - Computed Properties

    var currentVisit: Visit? {
        todayVisits.first { $0.isCurrentVisit }
    }

    // Session-specific location points (only points from current tracking session)
    var sessionLocationPoints: [LocationPoint] {
        guard let sessionStart = locationManager.trackingStartTime else {
            return []
        }
        return todayLocationPoints.filter { $0.timestamp >= sessionStart }
    }

    // Session tracking stats
    var sessionTrackingDuration: TimeInterval {
        guard let sessionStart = locationManager.trackingStartTime else { return 0 }
        return Date().timeIntervalSince(sessionStart)
    }

    var sessionDistanceTraveled: Double {
        let points = sessionLocationPoints
        guard points.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<points.count {
            let prev = points[i-1]
            let curr = points[i]
            total += prev.distance(to: curr)
        }
        return total
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
        guard todayLocationPoints.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<todayLocationPoints.count {
            let prev = todayLocationPoints[i-1]
            let curr = todayLocationPoints[i]
            total += prev.distance(to: curr)
        }
        return total
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
        if allLocationPointsLoaded {
            return locationPoints.filter { range.contains($0.timestamp) }
        }

        do {
            return try fetchLocationPoints(in: range)
        } catch {
            print("Failed to fetch location points in range: \(error)")
            return []
        }
    }

    // MARK: - Visit Management

    func deleteVisit(_ visit: Visit) {
        modelContext.delete(visit)
        try? modelContext.save()
        loadData()
    }

    func updateVisitNotes(_ visit: Visit, notes: String) {
        visit.notes = notes.isEmpty ? nil : notes
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
            try ExportService.share(visits: visitsToExport, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }
    
    func exportLocationPoints(format: ExportFormat, dateRange: ClosedRange<Date>? = nil) {
        let pointsToExport: [LocationPoint]
        if let range = dateRange {
            pointsToExport = locationPointsInDateRange(range)
        } else {
            loadLocationPoints()
            pointsToExport = locationPoints
        }

        do {
            try ExportService.shareLocationPoints(points: pointsToExport, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }

    func exportAllData(format: ExportFormat) {
        loadLocationPoints()
        do {
            try ExportService.shareCombined(visits: allVisits, points: locationPoints, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }

    @MainActor
    func exportWithOptions(_ options: ExportOptions) {
        loadLocationPoints()
        do {
            try ExportService.share(visits: allVisits, points: locationPoints, options: options)
        } catch {
            exportError = error.localizedDescription
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
        locationPoints = []
        allLocationPointsLoaded = false
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
            mapLocationPoints = []
            todayLocationPoints = []
            locationPointCount = 0
            allLocationPointsLoaded = true
            loadData()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }

    // MARK: - Tracking Control

    func startTracking() {
        locationManager.startTracking()
    }

    func stopTracking() {
        locationManager.stopTracking()
    }
}
