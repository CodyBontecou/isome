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
    var locationPoints: [LocationPoint] = []
    var todayLocationPoints: [LocationPoint] = []

    // UI State
    var mapDateRange: ClosedRange<Date> = Date().addingTimeInterval(-86400 * 7)...Date()
    var showingExportSheet = false
    var showingClearConfirmation = false
    var exportError: String?

    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext, locationManager: LocationManager) {
        self.modelContext = modelContext
        self.locationManager = locationManager
        locationManager.setModelContext(modelContext)

        loadData()
        
        // Observe location manager for new data points and reload when they're saved
        locationManager.$locationPointsSavedCount
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadTodayLocationPoints()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() {
        loadTodayVisits()
        loadAllVisits()
        loadLocationPoints()
        loadTodayLocationPoints()
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

    func loadLocationPoints() {
        var descriptor = FetchDescriptor<LocationPoint>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        do {
            locationPoints = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch location points: \(error)")
            locationPoints = []
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
        } catch {
            print("Failed to fetch today's location points: \(error)")
            todayLocationPoints = []
        }
    }

    // MARK: - Computed Properties

    var currentVisit: Visit? {
        todayVisits.first { $0.isCurrentVisit }
    }

    // Session-specific location points (only points from current tracking session)
    var sessionLocationPoints: [LocationPoint] {
        guard let sessionStart = locationManager.continuousTrackingStartTime else {
            return []
        }
        return todayLocationPoints.filter { $0.timestamp >= sessionStart }
    }

    // Session tracking stats
    var sessionTrackingDuration: TimeInterval {
        guard let sessionStart = locationManager.continuousTrackingStartTime else { return 0 }
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
        locationPoints.filter { range.contains($0.timestamp) }
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
            pointsToExport = locationPoints
        }
        
        do {
            try ExportService.shareLocationPoints(points: pointsToExport, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Clear Data

    func clearAllData() {
        do {
            try modelContext.delete(model: Visit.self)
            try modelContext.delete(model: LocationPoint.self)
            try modelContext.save()
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

    func enableContinuousTracking() {
        locationManager.enableContinuousTracking()
    }

    func disableContinuousTracking() {
        locationManager.disableContinuousTracking()
    }
}
