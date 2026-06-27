import Foundation
import SwiftData
import SwiftUI
import Combine
import CoreLocation

struct MapSessionFocusRequest: Equatable {
    let id = UUID()
    let sessionID: String
    let title: String
    let range: ClosedRange<Date>
}

@MainActor
@Observable
final class LocationViewModel {
    var locationManager: LocationManager
    private var modelContext: ModelContext

    // Cached data
    var todayVisits: [Visit] = []
    var allVisits: [Visit] = []
    var allRecordingSessions: [RecordingSession] = []
    var photoLibraryAccessState: PhotoLibraryAccessState = PhotoLibraryManager.shared.authorizationState
    /// Full point history. Loaded lazily for export so the map does not hydrate
    /// tens of thousands of SwiftData models on launch.
    var locationPoints: [LocationPoint] = []
    var todayLocationPoints: [LocationPoint] = []
    /// Downsampled points used by the map for the currently selected date range.
    var mapLocationPoints: [LocationPoint] = []
    var mapPhotoMoments: [PhotoMoment] = []
    /// Raw count for the current map date range, before downsampling.
    var mapLocationPointCount: Int = 0
    var mapPhotoMomentCount: Int = 0
    var totalLocationPointCount: Int = 0

    // UI State
    var mapDateRange: ClosedRange<Date> = Calendar.current.startOfDay(for: Date())...Date()
    var mapFocusRequest: MapSessionFocusRequest?
    var showingExportSheet = false
    var showingClearConfirmation = false
    var exportError: String?

    private var hasLoadedAllLocationPoints = false
    private var sessionLocationPointsCache: [LocationPoint] = []
    private var todayDistanceTraveledCache: Double = 0
    private var sessionDistanceTraveledCache: Double = 0
    private var cancellables = Set<AnyCancellable>()
    private var isAutomaticPhotoSyncInProgress = false
    private var lastAutomaticPhotoSyncAt: Date?

    static let automaticPhotoSyncEnabledKey = "automaticPhotoSyncEnabled"
    static let showPhotoMarkersKey = "showPhotoMarkers"
    static let showVisitSuggestionsKey = "showVisitSuggestions"

    private let maximumMapPointCount = 2_500
    private let maximumMapPhotoMomentCount = 500
    private let maximumRawMapPointFetchCount = 10_000
    private let mapFetchBatchSize = 500
    private let automaticPhotoSyncCooldown: TimeInterval = 10 * 60
    private let photoRouteInferenceWindow: TimeInterval = 15 * 60
    private let photoVisitInferenceGracePeriod: TimeInterval = 15 * 60

    static var isAutomaticPhotoSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: automaticPhotoSyncEnabledKey)
    }

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

        NotificationCenter.default.publisher(for: .photoLibraryDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.syncPhotosAutomaticallyIfAuthorized(ignoresCooldown: true)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() {
        loadTodayVisits()
        loadAllVisits()
        loadRecordingSessions()
        refreshLocationPointCount()
        refreshPhotoLibraryAuthorizationState()
        if locationManager.isTrackingEnabled {
            loadTodayLocationPoints()
        } else {
            todayLocationPoints = []
            refreshDerivedPointCaches()
        }
        loadMapLocationPoints(in: mapDateRange)
        loadMapPhotoMoments(in: mapDateRange)
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

    func loadRecordingSessions() {
        var descriptor = FetchDescriptor<RecordingSession>()
        descriptor.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]

        do {
            allRecordingSessions = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch recording sessions: \(error)")
            allRecordingSessions = []
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

    func refreshPhotoLibraryAuthorizationState() {
        photoLibraryAccessState = PhotoLibraryManager.shared.authorizationState
        if photoLibraryAccessState.canRead {
            PhotoLibraryManager.shared.startObservingChangesIfNeeded()
        } else {
            mapPhotoMomentCount = 0
            mapPhotoMoments = []
        }
    }

    func loadMapPhotoMoments(in range: ClosedRange<Date>? = nil) {
        refreshPhotoLibraryAuthorizationState()
        guard photoLibraryAccessState.canRead else { return }

        let moments = fetchPhotoMoments(in: range ?? mapDateRange)
        mapPhotoMomentCount = moments.count
        mapPhotoMoments = downsample(photoMoments: moments, maxCount: maximumMapPhotoMomentCount)
    }

    func requestPhotoLibraryAccessAndSync(in range: ClosedRange<Date>? = nil) async {
        photoLibraryAccessState = await PhotoLibraryManager.shared.requestAuthorization()
        guard photoLibraryAccessState.canRead else {
            mapPhotoMomentCount = 0
            mapPhotoMoments = []
            return
        }

        await syncPhotoMoments(in: range ?? mapDateRange)
    }

    func syncPhotoMomentsIfAuthorized(in range: ClosedRange<Date>? = nil) async {
        refreshPhotoLibraryAuthorizationState()
        guard photoLibraryAccessState.canRead else { return }
        await syncPhotoMoments(in: range ?? mapDateRange)
    }

    func setAutomaticPhotoSyncEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: Self.automaticPhotoSyncEnabledKey)
        UserDefaults.standard.set(isEnabled, forKey: Self.showPhotoMarkersKey)

        if !isEnabled {
            mapPhotoMomentCount = 0
            mapPhotoMoments = []
        }
    }

    func requestPhotoLibraryAccessAndStartAutomaticSync() async {
        setAutomaticPhotoSyncEnabled(true)
        await performAutomaticPhotoSync(requestAuthorizationIfNeeded: true, ignoresCooldown: true)

        if !photoLibraryAccessState.canRead {
            setAutomaticPhotoSyncEnabled(false)
        }
    }

    func syncPhotosAutomaticallyIfAuthorized(ignoresCooldown: Bool = false) async {
        guard Self.isAutomaticPhotoSyncEnabled else { return }
        await performAutomaticPhotoSync(requestAuthorizationIfNeeded: false, ignoresCooldown: ignoresCooldown)
    }

    private func performAutomaticPhotoSync(
        requestAuthorizationIfNeeded: Bool,
        ignoresCooldown: Bool
    ) async {
        guard !isAutomaticPhotoSyncInProgress else { return }

        let now = Date()
        if !ignoresCooldown,
           let lastAutomaticPhotoSyncAt,
           now.timeIntervalSince(lastAutomaticPhotoSyncAt) < automaticPhotoSyncCooldown {
            loadMapPhotoMoments(in: mapDateRange)
            return
        }

        isAutomaticPhotoSyncInProgress = true
        var didSync = false
        defer {
            isAutomaticPhotoSyncInProgress = false
            if didSync {
                lastAutomaticPhotoSyncAt = Date()
            }
        }

        photoLibraryAccessState = PhotoLibraryManager.shared.authorizationState
        if photoLibraryAccessState == .notDetermined {
            guard requestAuthorizationIfNeeded else { return }
            photoLibraryAccessState = await PhotoLibraryManager.shared.requestAuthorization()
        } else if photoLibraryAccessState.canRead {
            PhotoLibraryManager.shared.startObservingChangesIfNeeded()
        }

        guard photoLibraryAccessState.canRead else {
            mapPhotoMomentCount = 0
            mapPhotoMoments = []
            return
        }

        await syncPhotoMoments(in: automaticPhotoSyncRange(referenceDate: now))
        didSync = true
    }

    func syncPhotoMoments(in range: ClosedRange<Date>) async {
        photoLibraryAccessState = PhotoLibraryManager.shared.authorizationState
        guard photoLibraryAccessState.canRead else {
            mapPhotoMomentCount = 0
            mapPhotoMoments = []
            return
        }

        let libraryMetadata = PhotoLibraryManager.shared.fetchPhotoMetadata(in: range)
        let metadata = resolvedPhotoMoments(from: libraryMetadata, in: range)
        upsertPhotoMoments(metadata)

        if photoLibraryAccessState == .authorized {
            deleteMissingPhotoMoments(in: range, keeping: Set(metadata.map(\.assetLocalIdentifier)))
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save photo moments: \(error)")
        }

        loadMapPhotoMoments(in: mapDateRange)
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

    private func fetchPhotoMoments(in range: ClosedRange<Date>) -> [PhotoMoment] {
        let start = range.lowerBound
        let end = range.upperBound
        let predicate = #Predicate<PhotoMoment> { photo in
            photo.takenAt >= start && photo.takenAt <= end
        }

        var descriptor = FetchDescriptor<PhotoMoment>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.takenAt, order: .forward)]

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch photo moments: \(error)")
            return []
        }
    }

    private func resolvedPhotoMoments(
        from libraryMetadata: [PhotoAssetLibraryMetadata],
        in range: ClosedRange<Date>
    ) -> [PhotoAssetMetadata] {
        guard !libraryMetadata.isEmpty else { return [] }

        let pointRange = range.lowerBound.addingTimeInterval(-photoRouteInferenceWindow)...range.upperBound.addingTimeInterval(photoRouteInferenceWindow)
        let fetchedPoints = fetchLocationPoints(in: pointRange)
        let nonOutlierPoints = fetchedPoints.filter { !$0.isOutlier }
        let routePoints = nonOutlierPoints.isEmpty ? fetchedPoints : nonOutlierPoints
        let visits = allVisits.sorted { $0.arrivedAt < $1.arrivedAt }
        let referenceDate = Date()

        return libraryMetadata.compactMap { item in
            if let coordinate = item.photoGPSCoordinate {
                return PhotoAssetMetadata(
                    assetLocalIdentifier: item.assetLocalIdentifier,
                    takenAt: item.takenAt,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    coordinateSource: .photoGPS
                )
            }

            if let point = nearestLocationPoint(to: item.takenAt, in: routePoints),
               abs(point.timestamp.timeIntervalSince(item.takenAt)) <= photoRouteInferenceWindow {
                return PhotoAssetMetadata(
                    assetLocalIdentifier: item.assetLocalIdentifier,
                    takenAt: item.takenAt,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    coordinateSource: .inferredFromRoute
                )
            }

            if let visit = visitContainingPhoto(takenAt: item.takenAt, in: visits, referenceDate: referenceDate) {
                return PhotoAssetMetadata(
                    assetLocalIdentifier: item.assetLocalIdentifier,
                    takenAt: item.takenAt,
                    latitude: visit.latitude,
                    longitude: visit.longitude,
                    coordinateSource: .inferredFromVisit
                )
            }

            return nil
        }
    }

    private func nearestLocationPoint(to date: Date, in points: [LocationPoint]) -> LocationPoint? {
        guard !points.isEmpty else { return nil }

        var lowerBound = 0
        var upperBound = points.count
        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if points[midpoint].timestamp < date {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        let candidateIndices = [lowerBound - 1, lowerBound].filter { points.indices.contains($0) }
        return candidateIndices
            .map { points[$0] }
            .min { lhs, rhs in
                abs(lhs.timestamp.timeIntervalSince(date)) < abs(rhs.timestamp.timeIntervalSince(date))
            }
    }

    private func visitContainingPhoto(
        takenAt: Date,
        in visits: [Visit],
        referenceDate: Date
    ) -> Visit? {
        visits.first { visit in
            let start = visit.arrivedAt.addingTimeInterval(-photoVisitInferenceGracePeriod)
            let end = (visit.departedAt ?? referenceDate).addingTimeInterval(photoVisitInferenceGracePeriod)
            return takenAt >= start && takenAt <= end
        }
    }

    private func automaticPhotoSyncRange(referenceDate: Date = Date()) -> ClosedRange<Date> {
        let calendar = Calendar.current
        var dates: [Date] = [mapDateRange.lowerBound, mapDateRange.upperBound, referenceDate]

        for visit in allVisits {
            dates.append(visit.arrivedAt)
            if let departedAt = visit.departedAt {
                dates.append(departedAt)
            }
        }

        for session in allRecordingSessions {
            dates.append(session.startedAt)
            if let endedAt = session.endedAt {
                dates.append(endedAt)
            }
        }

        if let pointBounds = locationPointDateBounds() {
            dates.append(pointBounds.first)
            dates.append(pointBounds.last)
        }

        let earliest = dates.min() ?? calendar.startOfDay(for: referenceDate)
        let latest = max(dates.max() ?? referenceDate, referenceDate)
        let start = calendar.startOfDay(for: earliest)
        let endDay = calendar.startOfDay(for: latest)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? latest
        return start...end
    }

    private func locationPointDateBounds() -> (first: Date, last: Date)? {
        do {
            var firstDescriptor = FetchDescriptor<LocationPoint>()
            firstDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            firstDescriptor.fetchLimit = 1

            guard let firstPoint = try modelContext.fetch(firstDescriptor).first else {
                return nil
            }

            var lastDescriptor = FetchDescriptor<LocationPoint>()
            lastDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            lastDescriptor.fetchLimit = 1
            let lastPoint = try modelContext.fetch(lastDescriptor).first ?? firstPoint

            return (firstPoint.timestamp, lastPoint.timestamp)
        } catch {
            print("Failed to fetch location point date bounds: \(error)")
            return nil
        }
    }

    private func fetchPhotoMoment(assetLocalIdentifier: String) -> PhotoMoment? {
        let identifier = assetLocalIdentifier
        let predicate = #Predicate<PhotoMoment> { photo in
            photo.assetLocalIdentifier == identifier
        }

        var descriptor = FetchDescriptor<PhotoMoment>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Failed to fetch photo moment: \(error)")
            return nil
        }
    }

    private func upsertPhotoMoments(_ metadata: [PhotoAssetMetadata]) {
        let now = Date()
        for item in metadata {
            if let existing = fetchPhotoMoment(assetLocalIdentifier: item.assetLocalIdentifier) {
                existing.takenAt = item.takenAt
                existing.latitude = item.latitude
                existing.longitude = item.longitude
                existing.coordinateSource = item.coordinateSource
                existing.lastSyncedAt = now
            } else {
                modelContext.insert(PhotoMoment(
                    assetLocalIdentifier: item.assetLocalIdentifier,
                    takenAt: item.takenAt,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    coordinateSource: item.coordinateSource,
                    lastSyncedAt: now
                ))
            }
        }
    }

    private func deleteMissingPhotoMoments(in range: ClosedRange<Date>, keeping identifiers: Set<String>) {
        let cached = fetchPhotoMoments(in: range)
        for photo in cached where photo.coordinateSource == .photoGPS && !identifiers.contains(photo.assetLocalIdentifier) {
            modelContext.delete(photo)
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

    private func downsample(photoMoments: [PhotoMoment], maxCount: Int) -> [PhotoMoment] {
        guard photoMoments.count > maxCount else { return photoMoments }
        guard maxCount > 1 else { return Array(photoMoments.prefix(max(0, maxCount))) }

        let lastIndex = photoMoments.count - 1
        let denominator = Double(maxCount - 1)
        var sampled: [PhotoMoment] = []
        sampled.reserveCapacity(maxCount)

        for outputIndex in 0..<maxCount {
            let sourceIndex = Int((Double(outputIndex) * Double(lastIndex) / denominator).rounded())
            sampled.append(photoMoments[sourceIndex])
        }

        return sampled
    }

    // MARK: - Computed Properties

    var currentVisit: Visit? {
        allVisits
            .filter { $0.isCurrentVisit }
            .max { $0.arrivedAt < $1.arrivedAt }
    }

    func isCurrentVisit(_ visit: Visit) -> Bool {
        guard visit.departedAt == nil else { return false }
        return currentVisit?.id == visit.id
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

    func visitsOverlappingDateRange(_ range: ClosedRange<Date>, referenceDate: Date = Date()) -> [Visit] {
        allVisits
            .filter { visit in
                let visitEnd = visit.departedAt ?? referenceDate
                return visit.arrivedAt <= range.upperBound && visitEnd >= range.lowerBound
            }
            .sorted { $0.arrivedAt < $1.arrivedAt }
    }

    func locationPointsInDateRange(_ range: ClosedRange<Date>) -> [LocationPoint] {
        fetchLocationPoints(in: range)
    }

    func photosInDateRange(_ range: ClosedRange<Date>) -> [PhotoMoment] {
        guard photoLibraryAccessState.canRead else { return [] }
        return fetchPhotoMoments(in: range)
    }

    func recordingSessionSummaries(
        gapThreshold: TimeInterval = RecordingSessionBuilder.defaultGapThreshold,
        inferenceConfiguration: RecordingSessionInferenceConfiguration? = nil
    ) -> [RecordingSessionSummary] {
        RecordingSessionBuilder.summaries(
            storedSessions: allRecordingSessions,
            points: locationPoints,
            activeTrackingStart: locationManager.trackingStartTime,
            gapThreshold: gapThreshold,
            inferenceConfiguration: inferenceConfiguration
        )
    }

    func focusMap(on session: RecordingSessionSummary) {
        mapDateRange = session.dateRange
        loadMapLocationPoints(in: session.dateRange)
        loadMapPhotoMoments(in: session.dateRange)
        mapFocusRequest = MapSessionFocusRequest(
            sessionID: session.id,
            title: session.title,
            range: session.dateRange
        )
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
        visit.updatedAt = Date()
        try? modelContext.save()
        loadTodayVisits()
        loadAllVisits()
    }

    func clearVisitName(_ visit: Visit) {
        visit.customName = nil
        visit.updatedAt = Date()
        try? modelContext.save()
        loadTodayVisits()
        loadAllVisits()
    }

    func updateVisitNotes(_ visit: Visit, notes: String) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.notes = trimmed.isEmpty ? nil : notes
        visit.updatedAt = Date()
        try? modelContext.save()
    }

    func confirmVisit(_ visit: Visit) {
        let now = Date()
        visit.confirmationStatus = .confirmed
        visit.confirmedAt = now
        visit.updatedAt = now
        try? modelContext.save()
        loadTodayVisits()
        loadAllVisits()
    }

    func correctVisit(
        _ visit: Visit,
        name: String,
        address: String?,
        coordinate: CLLocationCoordinate2D,
        placeSource: VisitPlaceSource,
        distanceMeters: Double? = nil
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let now = Date()
        visit.preserveOriginalValuesIfNeeded()
        visit.latitude = coordinate.latitude
        visit.longitude = coordinate.longitude
        visit.customName = nil
        visit.locationName = trimmedName
        visit.address = address?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        visit.confirmationStatus = .corrected
        visit.confirmedAt = visit.confirmedAt ?? now
        visit.updatedAt = now
        visit.placeSource = placeSource
        visit.placeDistanceMeters = distanceMeters
        visit.geocodingCompleted = true

        try? modelContext.save()
        loadTodayVisits()
        loadAllVisits()
        loadMapLocationPoints(in: mapDateRange)
    }

    func undoVisitCorrection(_ visit: Visit) {
        guard let originalLatitude = visit.originalLatitude,
              let originalLongitude = visit.originalLongitude else { return }

        let now = Date()
        visit.latitude = originalLatitude
        visit.longitude = originalLongitude
        visit.locationName = visit.originalLocationName
        visit.address = visit.originalAddress
        visit.customName = nil
        visit.confirmationStatus = .unconfirmed
        visit.confirmedAt = nil
        visit.updatedAt = now
        visit.placeSource = nil
        visit.placeDistanceMeters = nil

        try? modelContext.save()
        loadTodayVisits()
        loadAllVisits()
        loadMapLocationPoints(in: mapDateRange)
    }

    @discardableResult
    func createManualVisit(
        name: String,
        address: String?,
        coordinate: CLLocationCoordinate2D,
        arrivedAt: Date,
        departedAt: Date?
    ) -> Visit? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        if let departedAt, departedAt < arrivedAt { return nil }

        let now = Date()
        let visit = Visit(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            arrivedAt: arrivedAt,
            departedAt: departedAt,
            locationName: trimmedName,
            address: address?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            geocodingCompleted: true,
            source: .manual,
            confirmationStatus: .confirmed,
            confirmedAt: now,
            updatedAt: now,
            placeSource: .userEntered
        )
        modelContext.insert(visit)
        try? modelContext.save()
        loadData()
        return visit
    }

    @discardableResult
    func updateVisitTimes(_ visit: Visit, arrivedAt: Date, departedAt: Date?) -> Bool {
        if let departedAt, departedAt < arrivedAt { return false }

        visit.arrivedAt = arrivedAt
        visit.departedAt = departedAt
        visit.updatedAt = Date()
        try? modelContext.save()
        loadTodayVisits()
        loadAllVisits()
        loadMapLocationPoints(in: mapDateRange)
        return true
    }

    // MARK: - Recording Session Management

    func updateRecordingSession(_ session: RecordingSession, customName: String, notes: String) {
        let trimmedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        session.customName = trimmedName.isEmpty ? nil : trimmedName

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        session.notes = trimmedNotes.isEmpty ? nil : notes

        try? modelContext.save()
        loadRecordingSessions()
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
                recordingSessions: allRecordingSessions,
                activeTrackingStart: locationManager.trackingStartTime,
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
            let source = imported.sourceRaw.flatMap(VisitSource.init(rawValue:)) ?? .imported
            let confirmationStatus = imported.confirmationStatusRaw.flatMap(VisitConfirmationStatus.init(rawValue:)) ?? .unconfirmed
            let placeSource = imported.placeSourceRaw.flatMap(VisitPlaceSource.init(rawValue:)) ?? (source == .imported ? .import : nil)
            let visit = Visit(
                latitude: imported.latitude,
                longitude: imported.longitude,
                arrivedAt: imported.arrivedAt,
                departedAt: imported.departedAt,
                customName: imported.customName,
                locationName: imported.locationName,
                address: imported.address,
                notes: imported.notes,
                geocodingCompleted: imported.locationName != nil || imported.address != nil,
                source: source,
                confirmationStatus: confirmationStatus,
                confirmedAt: imported.confirmedAt,
                updatedAt: imported.updatedAt,
                originalLatitude: imported.originalLatitude,
                originalLongitude: imported.originalLongitude,
                originalLocationName: imported.originalLocationName,
                originalAddress: imported.originalAddress,
                detectedLatitude: imported.detectedLatitude,
                detectedLongitude: imported.detectedLongitude,
                detectedLocationName: imported.detectedLocationName,
                detectedAddress: imported.detectedAddress,
                placeSource: placeSource,
                placeDistanceMeters: imported.placeDistanceMeters
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
        locationManager.reconcileOpenVisits()
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
            try modelContext.delete(model: RecordingSession.self)
            try modelContext.delete(model: PhotoMoment.self)
            try modelContext.save()
            allRecordingSessions = []
            locationPoints = []
            todayLocationPoints = []
            mapLocationPoints = []
            mapPhotoMoments = []
            sessionLocationPointsCache = []
            mapLocationPointCount = 0
            mapPhotoMomentCount = 0
            totalLocationPointCount = 0
            todayDistanceTraveledCache = 0
            sessionDistanceTraveledCache = 0
            hasLoadedAllLocationPoints = false
            mapFocusRequest = nil
            UserDefaults.standard.removeObject(forKey: "activeRecordingSessionID")
            loadData()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }

    // MARK: - Tracking Control

    func startTracking() {
        locationManager.startTracking()
        loadRecordingSessions()
        refreshDerivedPointCaches()
    }

    func stopTracking() {
        locationManager.stopTracking()
        loadRecordingSessions()
        refreshDerivedPointCaches()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
