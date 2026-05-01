import Foundation
import CoreLocation
import SwiftData
import Combine
import ActivityKit
import WidgetKit
import UserNotifications

@MainActor
final class LocationManager: NSObject, ObservableObject {
    /// Latest live instance, used by App Intents so Siri/Shortcuts can drive tracking.
    static weak var shared: LocationManager?

    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?

    // Published state
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTrackingEnabled: Bool = false
    @Published var trackingStartTime: Date?
    @Published var stopAfterHours: Double = 0.0
    @Published var distanceFilter: Double = 5.0
    @Published var currentLocation: CLLocation?
    @Published var lastError: String?

    // Safety-net auto-stop timer (only runs when stopAfterHours > 0)
    private var stopTrackingTimer: Timer?

    // Geocoding service
    private let geocodingService = GeocodingService()

    // Publisher for data changes (fires when new location points are saved)
    @Published var locationPointsSavedCount: Int = 0

    // Live Activity manager
    private let liveActivityManager = LiveActivityManager.shared
    @Published var isLiveActivityEnabled: Bool = true

    // Daily distance history (recorded for stats; no longer drives auto-start)
    private let dailyDistanceTracker = DailyDistanceTracker.shared

    // Current location name for Live Activity
    private var currentLocationName: String?
    private var currentAddress: String?
    private var lastGeocodedLocation: CLLocation?

    // Sliding window of recently saved points for outlier detection
    private var pointBeforeLast: LocationPoint?
    private var lastSavedPoint: LocationPoint?

    private var usesMetricDistanceUnits: Bool {
        let key = "usesMetricDistanceUnits"
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private var allowNetworkGeocoding: Bool {
        let key = "allowNetworkGeocoding"
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    override init() {
        super.init()
        Self.shared = self
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        // Restore saved state
        isTrackingEnabled = UserDefaults.standard.bool(forKey: "isTrackingEnabled")
        if UserDefaults.standard.object(forKey: "stopAfterHours") != nil {
            stopAfterHours = UserDefaults.standard.double(forKey: "stopAfterHours")
        }
        if UserDefaults.standard.object(forKey: "distanceFilter") != nil {
            distanceFilter = UserDefaults.standard.double(forKey: "distanceFilter")
        }
        locationManager.distanceFilter = distanceFilter

        authorizationStatus = locationManager.authorizationStatus

        // Request notification permission for any future user-facing alerts.
        // Skipped in screenshot-seeding mode so the system prompt doesn't cover the UI.
        #if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("--seed-screenshot-data") {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        #else
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        #endif

        // Listen for stop notification from Live Activity deep link
        NotificationCenter.default.addObserver(
            forName: .stopTracking,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stopTracking()
            }
        }

        // If tracking was on at last launch, resume it (re-attaches CL APIs + Live Activity).
        if isTrackingEnabled && hasLocationPermission {
            startTracking()
        }
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Permission Handling

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    var canRequestAlwaysAuthorization: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .authorizedWhenInUse
    }

    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var hasAlwaysPermission: Bool {
        authorizationStatus == .authorizedAlways
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard hasLocationPermission else {
            requestAlwaysAuthorization()
            return
        }

        isTrackingEnabled = true
        UserDefaults.standard.set(true, forKey: "isTrackingEnabled")

        if trackingStartTime == nil {
            trackingStartTime = Date()
        }

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilter
        locationManager.startMonitoringVisits()
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()

        if isLiveActivityEnabled {
            let autoStopSeconds = stopAfterHours > 0 ? Int(stopAfterHours * 3600) : nil
            liveActivityManager.startActivity(autoStopSeconds: autoStopSeconds)
        }

        scheduleStopTrackingTimer()
        syncDataToWatch()
    }

    func stopTracking() {
        isTrackingEnabled = false
        UserDefaults.standard.set(false, forKey: "isTrackingEnabled")

        stopTrackingTimer?.invalidate()
        stopTrackingTimer = nil
        trackingStartTime = nil

        locationManager.stopMonitoringVisits()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingLocation()

        Task {
            await liveActivityManager.endActivity()
        }

        syncDataToWatch()
    }

    func setStopAfterHours(_ hours: Double) {
        stopAfterHours = hours
        UserDefaults.standard.set(hours, forKey: "stopAfterHours")
        scheduleStopTrackingTimer()

        if isTrackingEnabled, isLiveActivityEnabled {
            let autoStopSeconds = hours > 0 ? Int(hours * 3600) : nil
            liveActivityManager.updateActivity(
                location: nil,
                locationName: currentLocationName,
                remainingSeconds: autoStopSeconds
            )
        }
    }

    func setDistanceFilter(_ meters: Double) {
        distanceFilter = meters
        UserDefaults.standard.set(meters, forKey: "distanceFilter")
        if isTrackingEnabled {
            locationManager.distanceFilter = meters
        }
    }

    private func scheduleStopTrackingTimer() {
        stopTrackingTimer?.invalidate()
        stopTrackingTimer = nil

        guard isTrackingEnabled, stopAfterHours > 0, let start = trackingStartTime else { return }

        let elapsed = Date().timeIntervalSince(start)
        let total = stopAfterHours * 3600
        let remaining = total - elapsed
        guard remaining > 0 else {
            stopTracking()
            return
        }

        stopTrackingTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopTracking()
            }
        }
    }

    var remainingTime: TimeInterval? {
        guard stopAfterHours > 0, let start = trackingStartTime else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let total = stopAfterHours * 3600
        return max(0, total - elapsed)
    }

    // MARK: - Data Storage

    private func saveVisit(_ clVisit: CLVisit) {
        guard let context = modelContext else { return }

        // Check if this is a departure update for an existing visit
        let arrivalDate = clVisit.arrivalDate
        let latitude = clVisit.coordinate.latitude
        let longitude = clVisit.coordinate.longitude

        let predicate = #Predicate<Visit> { visit in
            visit.latitude == latitude &&
            visit.longitude == longitude &&
            visit.departedAt == nil
        }

        let descriptor = FetchDescriptor<Visit>(predicate: predicate)

        do {
            let existingVisits = try context.fetch(descriptor)

            if let existingVisit = existingVisits.first,
               clVisit.departureDate != Date.distantFuture {
                // Update departure time
                existingVisit.departedAt = clVisit.departureDate
            } else if clVisit.arrivalDate != Date.distantPast {
                // Create new visit
                let visit = Visit(
                    latitude: latitude,
                    longitude: longitude,
                    arrivedAt: arrivalDate
                )

                if clVisit.departureDate != Date.distantFuture {
                    visit.departedAt = clVisit.departureDate
                }

                context.insert(visit)

                // Trigger geocoding
                Task {
                    await geocodeVisit(visit)
                }
            }

            try context.save()
            syncDataToWatch()
        } catch {
            lastError = "Failed to save visit: \(error.localizedDescription)"
        }
    }

    private func saveLocationPoint(_ location: CLLocation) {
        guard let context = modelContext else { return }
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 else {
            return // Skip inaccurate readings
        }

        let point = LocationPoint(from: location)

        // Flag obvious teleports: implied speed from the last saved point exceeds
        // what a human moves (~40 m/s / ~90 mph). Cheap check, catches end-of-trail spikes.
        if let last = lastSavedPoint {
            let dt = point.timestamp.timeIntervalSince(last.timestamp)
            if dt > 0 {
                let impliedSpeed = last.distance(to: point) / dt
                if impliedSpeed > 40 {
                    point.isOutlier = true
                }
            }
        }

        context.insert(point)

        // Re-evaluate the previously saved point now that we have a point after it.
        // An out-and-back spike looks like: prev→last jumps far, last→new returns near prev.
        if let before = pointBeforeLast, let last = lastSavedPoint, !last.isOutlier {
            let spikeOut = before.distance(to: last)
            let spikeBack = last.distance(to: point)
            let endpointGap = before.distance(to: point)
            if spikeOut > 100 && spikeBack > 100 && endpointGap < 30 {
                last.isOutlier = true
            }
        }

        do {
            try context.save()
            pointBeforeLast = lastSavedPoint
            lastSavedPoint = point
            // Notify observers that new data is available
            locationPointsSavedCount += 1
            // Sync to watch widget (throttled by WidgetKit)
            syncDataToWatch()
        } catch {
            lastError = "Failed to save location point: \(error.localizedDescription)"
        }
    }

    // MARK: - Geocoding

    private func geocodeVisit(_ visit: Visit) async {
        guard !visit.geocodingCompleted else { return }
        guard allowNetworkGeocoding else { return }

        let location = CLLocation(latitude: visit.latitude, longitude: visit.longitude)

        do {
            let result = try await geocodingService.reverseGeocode(location: location)
            visit.locationName = result.name
            visit.address = result.address
            visit.geocodingCompleted = true

            try modelContext?.save()
        } catch {
            // Mark as completed even on error to avoid retrying too often
            visit.geocodingCompleted = true
            try? modelContext?.save()
        }
    }

    func retryGeocoding(for visit: Visit) async {
        visit.geocodingCompleted = false
        await geocodeVisit(visit)
    }

    // MARK: - Live Activity Geocoding

    private func geocodeForLiveActivity(location: CLLocation) async {
        guard allowNetworkGeocoding else { return }

        // Throttle geocoding - only geocode if we've moved more than 50 meters
        if let lastLocation = lastGeocodedLocation {
            let distance = location.distance(from: lastLocation)
            guard distance > 50 else { return }
        }

        lastGeocodedLocation = location

        do {
            let result = try await geocodingService.reverseGeocode(location: location)
            currentLocationName = result.name ?? result.address
            currentAddress = result.address
        } catch {
            // Keep the previous location name on error
        }
    }

    // MARK: - Watch Widget Data Sync

    /// Syncs current tracking state and today's stats to the shared App Group for the watch widget
    func syncDataToWatch() {
        guard let context = modelContext else { return }

        // Get today's date range
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        // Fetch today's visits
        let visitsPredicate = #Predicate<Visit> { visit in
            visit.arrivedAt >= startOfToday && visit.arrivedAt < endOfToday
        }
        let visitsDescriptor = FetchDescriptor<Visit>(predicate: visitsPredicate)
        let todayVisits = (try? context.fetch(visitsDescriptor)) ?? []

        // Fetch today's location points
        let pointsPredicate = #Predicate<LocationPoint> { point in
            point.timestamp >= startOfToday && point.timestamp < endOfToday
        }
        let pointsDescriptor = FetchDescriptor<LocationPoint>(
            predicate: pointsPredicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let todayPoints = (try? context.fetch(pointsDescriptor)) ?? []

        // Calculate total distance from today's points
        var totalDistance: Double = 0
        if todayPoints.count > 1 {
            for i in 1..<todayPoints.count {
                totalDistance += todayPoints[i].distance(to: todayPoints[i-1])
            }
        }

        let sharedData = SharedLocationData(
            isTrackingEnabled: isTrackingEnabled,
            currentLocationName: currentLocationName,
            currentAddress: currentAddress,
            lastLatitude: currentLocation?.coordinate.latitude,
            lastLongitude: currentLocation?.coordinate.longitude,
            lastUpdateTime: Date(),
            todayVisitsCount: todayVisits.count,
            todayDistanceMeters: totalDistance,
            todayPointsCount: todayPoints.count,
            trackingStartTime: trackingStartTime,
            stopAfterHours: stopAfterHours > 0 ? stopAfterHours : nil,
            usesMetricDistanceUnits: usesMetricDistanceUnits
        )

        sharedData.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func refreshDistanceUnitPreference() {
        syncDataToWatch()
        liveActivityManager.refreshDistanceUnitPreference()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if hasLocationPermission && isTrackingEnabled {
                // Reattach the CL APIs once permission lands
                startTracking()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            saveVisit(visit)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            currentLocation = location

            // Record location for daily distance history (stats only)
            dailyDistanceTracker.recordLocation(location)

            guard isTrackingEnabled else { return }

            saveLocationPoint(location)

            // Geocode location for Live Activity (throttled to avoid too many requests)
            await geocodeForLiveActivity(location: location)

            let remainingSeconds: Int? = remainingTime.map { Int($0) }
            liveActivityManager.updateActivity(
                location: location,
                locationName: currentLocationName,
                remainingSeconds: remainingSeconds
            )
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    lastError = "Location access denied"
                case .network:
                    lastError = "Network error"
                default:
                    lastError = error.localizedDescription
                }
            } else {
                lastError = error.localizedDescription
            }
        }
    }
}
