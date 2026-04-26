import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import Combine
import ActivityKit
import WidgetKit
import UserNotifications

@MainActor
final class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?

    // Published state
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTrackingEnabled: Bool = false
    @Published var isContinuousTrackingEnabled: Bool = false
    @Published var continuousTrackingAutoOffHours: Double = 2.0
    @Published var distanceFilter: Double = 10.0
    @Published var currentLocation: CLLocation?
    @Published var lastError: String?

    // Continuous tracking timer
    private var continuousTrackingTimer: Timer?
    @Published var continuousTrackingStartTime: Date?

    // Geocoding service
    private let geocodingService = GeocodingService()
    
    // Publisher for data changes (fires when new location points are saved)
    @Published var locationPointsSavedCount: Int = 0
    
    // Live Activity manager
    private let liveActivityManager = LiveActivityManager.shared
    @Published var isLiveActivityEnabled: Bool = true
    
    // Activity detection
    private let activityDetectionManager = ActivityDetectionManager.shared
    @Published var autoStartOnActivity: Bool = false
    @Published var wasAutoStarted: Bool = false

    // HealthKit workout observer
    private let healthKitObserver = HealthKitWorkoutObserver.shared
    @Published var autoStartOnWorkout: Bool = false

    // Distance-based trigger
    private let dailyDistanceTracker = DailyDistanceTracker.shared
    @Published var autoStartOnDistance: Bool = false

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
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        // Restore saved state
        isTrackingEnabled = UserDefaults.standard.bool(forKey: "isTrackingEnabled")
        isContinuousTrackingEnabled = UserDefaults.standard.bool(forKey: "isContinuousTrackingEnabled")
        if UserDefaults.standard.object(forKey: "continuousTrackingAutoOffHours") != nil {
            continuousTrackingAutoOffHours = UserDefaults.standard.double(forKey: "continuousTrackingAutoOffHours")
        } else {
            continuousTrackingAutoOffHours = 2.0
        }
        if UserDefaults.standard.object(forKey: "distanceFilter") != nil {
            distanceFilter = UserDefaults.standard.double(forKey: "distanceFilter")
        } else {
            distanceFilter = 10.0
        }

        autoStartOnActivity = UserDefaults.standard.bool(forKey: "autoStartOnActivity")
        autoStartOnWorkout = UserDefaults.standard.bool(forKey: "autoStartOnWorkout")
        autoStartOnDistance = UserDefaults.standard.bool(forKey: "autoStartOnDistance")

        authorizationStatus = locationManager.authorizationStatus

        // Request notification permission for auto-start/stop alerts.
        // Skipped in screenshot-seeding mode so the system prompt doesn't cover the UI.
        #if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("--seed-screenshot-data") {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        #else
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        #endif

        // Set up activity detection for auto-start
        setupActivityDetection()

        // Set up HealthKit workout observer
        setupHealthKitObserver()

        // Listen for stop tracking notification from Live Activity
        NotificationCenter.default.addObserver(
            forName: .stopContinuousTracking,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.disableContinuousTracking()
            }
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
        UserDefaults.standard.set(isTrackingEnabled, forKey: "isTrackingEnabled")
        updateTrackingState()
        syncDataToWatch()
    }

    func stopTracking() {
        // Clean up continuous tracking state first
        if isContinuousTrackingEnabled {
            continuousTrackingTimer?.invalidate()
            continuousTrackingTimer = nil
            Task {
                await liveActivityManager.endActivity()
            }
        }
        continuousTrackingStartTime = nil

        isTrackingEnabled = false
        isContinuousTrackingEnabled = false
        UserDefaults.standard.set(isTrackingEnabled, forKey: "isTrackingEnabled")
        UserDefaults.standard.set(isContinuousTrackingEnabled, forKey: "isContinuousTrackingEnabled")

        updateTrackingState()
        syncDataToWatch()
    }

    private func updateTrackingState() {
        if isTrackingEnabled && hasLocationPermission {
            locationManager.startMonitoringVisits()
            locationManager.startMonitoringSignificantLocationChanges()
            if autoStartOnActivity {
                activityDetectionManager.startMonitoring()
            }
            if autoStartOnWorkout {
                healthKitObserver.startObserving()
            }
        } else {
            locationManager.stopMonitoringVisits()
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.stopUpdatingLocation()
            activityDetectionManager.stopMonitoring()
            healthKitObserver.stopObserving()
        }
    }

    // MARK: - Continuous Tracking

    func enableContinuousTracking() {
        guard hasLocationPermission else { return }

        isContinuousTrackingEnabled = true
        UserDefaults.standard.set(isContinuousTrackingEnabled, forKey: "isContinuousTrackingEnabled")
        continuousTrackingStartTime = Date()

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilter
        locationManager.startUpdatingLocation()

        // Start Live Activity
        if isLiveActivityEnabled {
            let autoOffSeconds = continuousTrackingAutoOffHours > 0
                ? Int(continuousTrackingAutoOffHours * 3600)
                : nil
            liveActivityManager.startActivity(mode: .continuous, autoOffSeconds: autoOffSeconds)
        }

        // Set auto-off timer (skip if set to "Never" which is 0)
        continuousTrackingTimer?.invalidate()
        continuousTrackingTimer = nil

        if continuousTrackingAutoOffHours > 0 {
            let autoOffInterval = continuousTrackingAutoOffHours * 3600
            continuousTrackingTimer = Timer.scheduledTimer(withTimeInterval: autoOffInterval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.disableContinuousTracking()
                }
            }
        }
    }

    func disableContinuousTracking() {
        wasAutoStarted = false
        isContinuousTrackingEnabled = false
        UserDefaults.standard.set(isContinuousTrackingEnabled, forKey: "isContinuousTrackingEnabled")
        continuousTrackingTimer?.invalidate()
        continuousTrackingTimer = nil
        continuousTrackingStartTime = nil

        locationManager.stopUpdatingLocation()
        
        // End Live Activity
        Task {
            await liveActivityManager.endActivity()
        }

        // Resume normal tracking if still enabled
        if isTrackingEnabled {
            updateTrackingState()
        }
        syncDataToWatch()
    }

    private func updateContinuousTracking() {
        if isContinuousTrackingEnabled {
            enableContinuousTracking()
        } else {
            disableContinuousTracking()
        }
    }

    var continuousTrackingRemainingTime: TimeInterval? {
        // Return nil if auto-off is set to "Never" (0)
        guard continuousTrackingAutoOffHours > 0 else { return nil }
        guard let startTime = continuousTrackingStartTime else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        let total = continuousTrackingAutoOffHours * 3600
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
    
    // MARK: - Activity Detection (Auto-Start)

    private func setupActivityDetection() {
        activityDetectionManager.onActivityStarted = { [weak self] activity in
            Task { @MainActor in
                self?.handleActivityDetected(activity)
            }
        }
        activityDetectionManager.onActivityStopped = { [weak self] in
            Task { @MainActor in
                self?.handleActivityStopped()
            }
        }

        // Start monitoring if auto-start is enabled and tracking is on
        if autoStartOnActivity && isTrackingEnabled {
            activityDetectionManager.startMonitoring()
        }
    }

    func setAutoStartOnActivity(_ enabled: Bool) {
        autoStartOnActivity = enabled
        UserDefaults.standard.set(enabled, forKey: "autoStartOnActivity")

        if enabled && isTrackingEnabled {
            activityDetectionManager.startMonitoring()
        } else if !enabled {
            activityDetectionManager.stopMonitoring()
        }
    }

    private func handleActivityDetected(_ activity: CMMotionActivity) {
        guard autoStartOnActivity,
              isTrackingEnabled,
              !isContinuousTrackingEnabled else { return }

        wasAutoStarted = true
        enableContinuousTracking()

        let reason: String
        if activity.automotive { reason = "driving detected" }
        else if activity.cycling { reason = "cycling detected" }
        else if activity.running { reason = "running detected" }
        else { reason = "walking detected" }
        sendAutoStartNotification(reason: reason)
    }

    private func handleActivityStopped() {
        guard wasAutoStarted, isContinuousTrackingEnabled else { return }

        sendAutoStopNotification()
        disableContinuousTracking()
    }

    // MARK: - HealthKit Workout Observer (Auto-Start)

    private func setupHealthKitObserver() {
        healthKitObserver.onWorkoutDetected = { [weak self] in
            Task { @MainActor in
                self?.handleWorkoutDetected()
            }
        }

        if autoStartOnWorkout && isTrackingEnabled {
            healthKitObserver.startObserving()
        }
    }

    func setAutoStartOnWorkout(_ enabled: Bool) {
        if enabled {
            Task {
                let authorized = await healthKitObserver.requestAuthorization()
                autoStartOnWorkout = authorized
                UserDefaults.standard.set(authorized, forKey: "autoStartOnWorkout")
                if authorized && isTrackingEnabled {
                    healthKitObserver.startObserving()
                }
            }
        } else {
            autoStartOnWorkout = false
            UserDefaults.standard.set(false, forKey: "autoStartOnWorkout")
            healthKitObserver.stopObserving()
        }
    }

    private func handleWorkoutDetected() {
        guard autoStartOnWorkout,
              isTrackingEnabled,
              !isContinuousTrackingEnabled else { return }

        wasAutoStarted = true
        enableContinuousTracking()
        sendAutoStartNotification(reason: "workout detected")
    }

    // MARK: - Distance-Based Trigger (Auto-Start)

    func setAutoStartOnDistance(_ enabled: Bool) {
        autoStartOnDistance = enabled
        UserDefaults.standard.set(enabled, forKey: "autoStartOnDistance")
    }

    private func handleDistanceThresholdExceeded() {
        guard autoStartOnDistance,
              isTrackingEnabled,
              !isContinuousTrackingEnabled else { return }

        wasAutoStarted = true
        enableContinuousTracking()
        sendAutoStartNotification(reason: "above-average travel detected")
    }

    // MARK: - Auto-Start Notifications

    private func sendAutoStartNotification(reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "Recording Started"
        content.body = "\(reason.prefix(1).uppercased() + reason.dropFirst()) — continuous tracking enabled"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "autoStart-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func sendAutoStopNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Recording Stopped"
        content.body = "Activity ended — continuous tracking disabled"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "autoStop-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Check activity on background wake (called from significant location change)
    private func checkActivityOnWake() {
        guard autoStartOnActivity,
              isTrackingEnabled,
              !isContinuousTrackingEnabled else { return }

        Task {
            guard let activity = await activityDetectionManager.queryCurrentActivity() else { return }
            if ActivityDetectionManager.isActiveActivity(activity) {
                handleActivityDetected(activity)
            }
        }
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

        // Create shared data
        let sharedData = SharedLocationData(
            isTrackingEnabled: isTrackingEnabled,
            isContinuousTrackingEnabled: isContinuousTrackingEnabled,
            currentLocationName: currentLocationName,
            currentAddress: currentAddress,
            lastLatitude: currentLocation?.coordinate.latitude,
            lastLongitude: currentLocation?.coordinate.longitude,
            lastUpdateTime: Date(),
            todayVisitsCount: todayVisits.count,
            todayDistanceMeters: totalDistance,
            todayPointsCount: todayPoints.count,
            continuousTrackingStartTime: continuousTrackingStartTime,
            continuousTrackingAutoOffHours: continuousTrackingAutoOffHours > 0 ? continuousTrackingAutoOffHours : nil,
            usesMetricDistanceUnits: usesMetricDistanceUnits
        )

        // Save to App Group and reload widget timelines
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
                updateTrackingState()
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

            // Record location for daily distance history
            dailyDistanceTracker.recordLocation(location)

            // On significant location change (not continuous), check if we should auto-start
            if !isContinuousTrackingEnabled {
                checkActivityOnWake()

                // Check distance-based trigger
                if autoStartOnDistance, dailyDistanceTracker.isAboveAverage() {
                    handleDistanceThresholdExceeded()
                }
            }

            if isContinuousTrackingEnabled {
                saveLocationPoint(location)
                
                // Geocode location for Live Activity (throttled to avoid too many requests)
                await geocodeForLiveActivity(location: location)
                
                // Update Live Activity
                let remainingSeconds: Int?
                if let remaining = continuousTrackingRemainingTime {
                    remainingSeconds = Int(remaining)
                } else {
                    remainingSeconds = nil
                }
                liveActivityManager.updateActivity(
                    location: location,
                    locationName: currentLocationName,
                    remainingSeconds: remainingSeconds,
                    mode: .continuous
                )
            }
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
