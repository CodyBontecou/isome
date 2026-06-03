import Foundation
import SwiftData
import SwiftUI
import Combine
import CoreLocation

@MainActor
@Observable
final class LocationViewModel {
    var locationManager: LocationManager
    private var modelContext: ModelContext
    private let placeSearchService: any PlaceSearching
    private let now: () -> Date

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
    var visitMutationError: String?

    private var hasLoadedAllLocationPoints = false
    private var sessionLocationPointsCache: [LocationPoint] = []
    private var todayDistanceTraveledCache: Double = 0
    private var sessionDistanceTraveledCache: Double = 0
    private var cancellables = Set<AnyCancellable>()

    private let maximumMapPointCount = 2_500
    private let maximumRawMapPointFetchCount = 10_000
    private let mapFetchBatchSize = 500

    init(
        modelContext: ModelContext,
        locationManager: LocationManager,
        placeSearchService: any PlaceSearching = PlaceSearchService(),
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.locationManager = locationManager
        self.placeSearchService = placeSearchService
        self.now = now
        locationManager.setModelContext(modelContext)

        loadData()

        // Observe location manager for new data points. Append the saved point to
        // in-memory caches instead of refetching the entire day on every update.
        locationManager.$locationPointsSavedCount
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSavedLocationPoint()
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

    private func handleSavedLocationPoint() {
        guard let point = locationManager.lastSavedLocationPoint else {
            refreshLocationPointCount()
            loadTodayLocationPoints()
            loadMapLocationPoints(in: mapDateRange)
            if hasLoadedAllLocationPoints {
                loadLocationPoints()
            }
            return
        }

        totalLocationPointCount += 1

        if hasLoadedAllLocationPoints {
            locationPoints.append(point)
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

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

    func updateVisitNotes(_ visit: Visit, notes: String) {
        visit.notes = notes.isEmpty ? nil : notes
        visit.updatedAt = now()
        try? modelContext.save()
    }

    func confirmVisit(_ visit: Visit) {
        let timestamp = now()
        visit.confirmationStatus = .confirmed
        visit.confirmedAt = timestamp
        visit.updatedAt = timestamp
        visit.geocodingCompleted = true
        saveVisitMutation()
    }

    func correctVisit(_ visit: Visit, with update: VisitPlaceUpdate) throws {
        if visit.originalLatitude == nil || visit.originalLongitude == nil {
            visit.originalLatitude = visit.latitude
            visit.originalLongitude = visit.longitude
            visit.originalLocationName = visit.locationName
            visit.originalAddress = visit.address
        }

        let timestamp = now()
        visit.latitude = update.latitude
        visit.longitude = update.longitude
        visit.locationName = normalizedOptional(update.locationName)
        visit.address = normalizedOptional(update.address)
        visit.placeSource = update.placeSource
        visit.placeCategoryRaw = normalizedOptional(update.placeCategoryRaw)
        visit.placeDistanceMeters = update.placeDistanceMeters
        visit.placeConfidence = update.placeConfidence
        visit.confirmationStatus = .corrected
        visit.confirmedAt = visit.confirmedAt ?? timestamp
        visit.updatedAt = timestamp
        visit.geocodingCompleted = true

        try saveVisitMutationThrowing()
    }

    func undoVisitCorrection(_ visit: Visit) throws {
        guard let originalLatitude = visit.originalLatitude,
              let originalLongitude = visit.originalLongitude else {
            throw VisitMutationError.noCorrectionToUndo
        }

        visit.latitude = originalLatitude
        visit.longitude = originalLongitude
        visit.locationName = visit.originalLocationName
        visit.address = visit.originalAddress
        visit.originalLatitude = nil
        visit.originalLongitude = nil
        visit.originalLocationName = nil
        visit.originalAddress = nil
        visit.placeSource = visit.detectedLocationName != nil || visit.detectedAddress != nil ? .coreLocationGeocode : nil
        visit.placeCategoryRaw = nil
        visit.placeDistanceMeters = nil
        visit.placeConfidence = nil
        visit.confirmationStatus = visit.source == .manual ? .confirmed : .unconfirmed
        visit.updatedAt = now()
        visit.geocodingCompleted = visit.locationName != nil || visit.address != nil

        try saveVisitMutationThrowing()
    }

    @discardableResult
    func createManualVisit(from draft: ManualVisitDraft) throws -> Visit {
        try validateTimeRange(arrivedAt: draft.arrivedAt, departedAt: draft.departedAt)
        guard try !hasOverlappingManualVisit(
            arrivedAt: draft.arrivedAt,
            departedAt: draft.departedAt
        ) else {
            throw VisitMutationError.overlappingManualVisit
        }

        let timestamp = now()
        let visit = Visit(
            latitude: draft.latitude,
            longitude: draft.longitude,
            arrivedAt: draft.arrivedAt,
            departedAt: draft.departedAt,
            locationName: normalizedOptional(draft.locationName),
            address: normalizedOptional(draft.address),
            notes: normalizedOptional(draft.notes),
            geocodingCompleted: true,
            source: .manual,
            confirmationStatus: .confirmed,
            confirmedAt: timestamp,
            updatedAt: timestamp,
            placeSource: draft.placeSource,
            placeCategoryRaw: normalizedOptional(draft.placeCategoryRaw),
            placeDistanceMeters: draft.placeDistanceMeters,
            placeConfidence: draft.placeConfidence
        )

        modelContext.insert(visit)
        try saveVisitMutationThrowing()
        return visit
    }

    @discardableResult
    func createManualVisitAtCurrentLocation(
        locationName: String? = nil,
        address: String? = nil,
        notes: String? = nil
    ) async throws -> Visit {
        let location = try await locationManager.requestOneShotCurrentLocation()
        let timestamp = now()
        return try createManualVisit(from: ManualVisitDraft(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            arrivedAt: timestamp,
            departedAt: nil,
            locationName: locationName,
            address: address,
            notes: notes,
            placeSource: .userEntered
        ))
    }

    func updateVisitTimes(_ visit: Visit, arrivedAt: Date, departedAt: Date?) throws {
        try validateTimeRange(arrivedAt: arrivedAt, departedAt: departedAt)
        if visit.source == .manual {
            guard try !hasOverlappingManualVisit(
                arrivedAt: arrivedAt,
                departedAt: departedAt,
                excluding: visit.id
            ) else {
                throw VisitMutationError.overlappingManualVisit
            }
        }

        visit.arrivedAt = arrivedAt
        visit.departedAt = departedAt
        visit.updatedAt = now()
        try saveVisitMutationThrowing()
    }

    func checkoutVisit(_ visit: Visit, at departedAt: Date? = nil) throws {
        guard visit.source == .manual else {
            throw VisitMutationError.checkoutRequiresManualVisit
        }
        guard visit.departedAt == nil else {
            throw VisitMutationError.visitAlreadyCheckedOut
        }
        try updateVisitTimes(visit, arrivedAt: visit.arrivedAt, departedAt: departedAt ?? now())
    }

    func searchPlaceCandidates(near coordinate: CLLocationCoordinate2D, query: String?) async -> [PlaceCandidate] {
        do {
            return try await placeSearchService.search(
                near: coordinate,
                query: query,
                allowNetworkGeocoding: allowNetworkGeocoding
            )
        } catch {
            return []
        }
    }

    private var allowNetworkGeocoding: Bool {
        let key = "allowNetworkGeocoding"
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func validateTimeRange(arrivedAt: Date, departedAt: Date?) throws {
        guard let departedAt else { return }
        guard departedAt >= arrivedAt else {
            throw VisitMutationError.invalidTimeRange
        }
    }

    private func hasOverlappingManualVisit(
        arrivedAt: Date,
        departedAt: Date?,
        excluding excludedID: UUID? = nil
    ) throws -> Bool {
        let visits = try modelContext.fetch(FetchDescriptor<Visit>())
        return visits.contains { visit in
            guard visit.source == .manual else { return false }
            guard visit.id != excludedID else { return false }
            return dateRangesOverlap(
                arrivedAt...manualRangeUpperBound(departedAt),
                visit.arrivedAt...manualRangeUpperBound(visit.departedAt)
            )
        }
    }

    private func manualRangeUpperBound(_ departedAt: Date?) -> Date {
        departedAt ?? Date.distantFuture
    }

    private func dateRangesOverlap(_ lhs: ClosedRange<Date>, _ rhs: ClosedRange<Date>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private func normalizedOptional(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func saveVisitMutation() {
        do {
            try saveVisitMutationThrowing()
        } catch {
            visitMutationError = error.localizedDescription
        }
    }

    private func saveVisitMutationThrowing() throws {
        try modelContext.save()
        loadData()
        locationManager.syncDataToWatch()
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
        let pointsToExport = fetchLocationPoints(in: dateRange)

        if dateRange == nil {
            locationPoints = pointsToExport
            hasLoadedAllLocationPoints = true
            totalLocationPointCount = pointsToExport.count
        }

        do {
            try ExportService.shareLocationPoints(points: pointsToExport, format: format)
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
            try ExportService.shareCombined(visits: allVisits, points: pointsToExport, format: format)
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
            try ExportService.share(visits: allVisits, points: pointsToExport, options: options)
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
                geocodingCompleted: true,
                source: VisitSource(rawValue: imported.sourceRaw ?? "") ?? .imported,
                confirmationStatus: VisitConfirmationStatus(rawValue: imported.confirmationStatusRaw ?? "") ?? .confirmed,
                confirmedAt: imported.confirmedAt,
                updatedAt: imported.updatedAt ?? now(),
                originalLatitude: imported.originalLatitude,
                originalLongitude: imported.originalLongitude,
                originalLocationName: imported.originalLocationName,
                originalAddress: imported.originalAddress,
                detectedLatitude: imported.detectedLatitude,
                detectedLongitude: imported.detectedLongitude,
                detectedLocationName: imported.detectedLocationName,
                detectedAddress: imported.detectedAddress,
                placeSource: VisitPlaceSource(rawValue: imported.placeSourceRaw ?? "") ?? .import,
                placeCategoryRaw: imported.placeCategoryRaw,
                placeDistanceMeters: imported.placeDistanceMeters,
                placeConfidence: imported.placeConfidence
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
