import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import Combine
import ActivityKit
import WidgetKit
import UserNotifications

enum TrackingStorageKeys {
    // Intentionally preserve legacy raw keys for backward-compatible UserDefaults storage.
    static let enabled = "isContinuousTrackingEnabled"
    static let autoOffHours = "continuousTrackingAutoOffHours"
}

@MainActor
final class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?

    // Published state
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTrackingEnabled: Bool = false
    @Published var trackingAutoOffHours: Double = 2.0
    @Published var distanceFilter: Double = 10.0
    @Published var currentLocation: CLLocation?
    @Published var lastError: String?

    // Tracking timer
    private var trackingTimer: Timer?
    @Published var trackingStartTime: Date?

    // Geocoding service
    private let geocodingService = GeocodingService()
    
    // Publisher for data changes (fires when new location points are saved)
    @Published var locationPointsSavedCount: Int = 0
    
    // Live Activity manager
    private let liveActivityManager = LiveActivityManager.shared
    @Published var isLiveActivityEnabled: Bool = true
    
    // Activity detection prompt
    private let activityDetectionManager = ActivityDetectionManager.shared
    @Published var autoStartOnActivity: Bool = false
    @Published var wasAutoStarted: Bool = false
    private let lastActivityPromptSentAtKey = "lastActivityPromptSentAt"

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

    private var activityPromptCooldownMinutes: Double {
        let key = "activityPromptCooldownMinutes"
        if UserDefaults.standard.object(forKey: key) == nil {
            return 30
        }
        return max(1, UserDefaults.standard.double(forKey: key))
    }

    private var activityPromptCooldownInterval: TimeInterval {
        activityPromptCooldownMinutes * 60
    }

    private var lastActivityPromptSentAt: Date? {
        guard UserDefaults.standard.object(forKey: lastActivityPromptSentAtKey) != nil else { return nil }
        let interval = UserDefaults.standard.double(forKey: lastActivityPromptSentAtKey)
        return Date(timeIntervalSince1970: interval)
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        // Restore saved state (legacy keys intentionally retained for compatibility).
        isTrackingEnabled = UserDefaults.standard.bool(forKey: TrackingStorageKeys.enabled)
        if UserDefaults.standard.object(forKey: TrackingStorageKeys.autoOffHours) != nil {
            trackingAutoOffHours = UserDefaults.standard.double(forKey: TrackingStorageKeys.autoOffHours)
        } else {
            trackingAutoOffHours = 2.0
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

        // Request notification permission for movement prompts and status alerts.
        // Skipped in screenshot-seeding/onboarding-preview modes so the system prompt doesn't cover the UI.
        #if DEBUG
        let suppressNotificationPrompt = ProcessInfo.processInfo.arguments.contains("--seed-screenshot-data")
            || ProcessInfo.processInfo.arguments.contains("--show-onboarding")
        if !suppressNotificationPrompt {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        #else
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        #endif

        // Set up activity detection for auto-start
        setupActivityDetection()

        // Set up HealthKit workout observer
        setupHealthKitObserver()

        // Listen for stop tracking notifications from Live Activity / deep links.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopTrackingNotification(_:)),
            name: .stopTracking,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopTrackingNotification(_:)),
            name: .stopContinuousTracking,
            object: nil
        )

        restoreTrackingStateAfterLaunch()
    }

    @objc private func handleStopTrackingNotification(_ notification: Notification) {
        Task { @MainActor in
            self.disableTracking()
        }
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private func restoreTrackingStateAfterLaunch() {
        if !hasLocationPermission {
            if isTrackingEnabled {
                LogManager.shared.warning("[Movement] Cleared persisted tracking state because location permission is unavailable.")
            }
            isTrackingEnabled = false
            UserDefaults.standard.set(false, forKey: TrackingStorageKeys.enabled)
            updateTrackingState()
            return
        }

        updateTrackingState()

        if isTrackingEnabled {
            LogManager.shared.info("[Movement] Restoring active tracking session after launch.")
            enableTracking()
        }
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

    private func updateTrackingState() {
        guard hasLocationPermission else {
            locationManager.stopUpdatingLocation()
            activityDetectionManager.stopMonitoring()
            healthKitObserver.stopObserving()
            return
        }

        // Activity detection for movement-prompt auto-start (when tracking is off)
        if autoStartOnActivity && !isTrackingEnabled {
            activityDetectionManager.startMonitoring()
        } else {
            activityDetectionManager.stopMonitoring()
        }

        // HealthKit workout observer for auto-start
        if autoStartOnWorkout && !isTrackingEnabled {
            healthKitObserver.startObserving()
        } else {
            healthKitObserver.stopObserving()
        }
    }

    // MARK: - Tracking

    func enableTracking() {
        guard hasLocationPermission else { return }

        isTrackingEnabled = true
        UserDefaults.standard.set(isTrackingEnabled, forKey: TrackingStorageKeys.enabled)
        trackingStartTime = Date()

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilter
        locationManager.startUpdatingLocation()

        // While tracking is active, movement prompts are redundant.
        activityDetectionManager.stopMonitoring()
        LogManager.shared.info("[Tracking] Tracking enabled (distance filter: \(Int(distanceFilter))m).")

        // Start Live Activity
        if isLiveActivityEnabled {
            let autoOffSeconds = trackingAutoOffHours > 0
                ? Int(trackingAutoOffHours * 3600)
                : nil
            liveActivityManager.startActivity(autoOffSeconds: autoOffSeconds)
        }

        // Set auto-off timer (skip if set to "Never" which is 0)
        trackingTimer?.invalidate()
        trackingTimer = nil

        if trackingAutoOffHours > 0 {
            let autoOffInterval = trackingAutoOffHours * 3600
            trackingTimer = Timer.scheduledTimer(withTimeInterval: autoOffInterval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.disableTracking()
                }
            }
        }

    }

    func disableTracking() {
        wasAutoStarted = false
        isTrackingEnabled = false
        UserDefaults.standard.set(isTrackingEnabled, forKey: TrackingStorageKeys.enabled)
        trackingTimer?.invalidate()
        trackingTimer = nil
        trackingStartTime = nil

        locationManager.stopUpdatingLocation()
        LogManager.shared.info("[Tracking] Tracking disabled.")

        // End Live Activity
        Task {
            await liveActivityManager.endActivity()
        }

        updateTrackingState()
        syncDataToWatch()
    }

    var trackingRemainingTime: TimeInterval? {
        // Return nil if auto-off is set to "Never" (0)
        guard trackingAutoOffHours > 0 else { return nil }
        guard let startTime = trackingStartTime else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        let total = trackingAutoOffHours * 3600
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
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 100 else {
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
    
    // MARK: - Activity Detection Prompt

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

        // Start monitoring if movement prompts are enabled and tracking is off.
        if autoStartOnActivity && !isTrackingEnabled {
            activityDetectionManager.startMonitoring()
        }
    }

    func setAutoStartOnActivity(_ enabled: Bool) {
        autoStartOnActivity = enabled
        UserDefaults.standard.set(enabled, forKey: "autoStartOnActivity")

        updateTrackingState()

        if enabled {
            LogManager.shared.info("[Movement] Activity prompt enabled for times when tracking is off.")
        } else {
            LogManager.shared.info("[Movement] Activity prompt disabled.")
        }
    }

    private func handleActivityDetected(_ activity: CMMotionActivity) {
        guard autoStartOnActivity else {
            LogManager.shared.info("[Movement] Detection ignored because Prompt on Movement is disabled.")
            return
        }

        guard !isTrackingEnabled else {
            LogManager.shared.info("[Movement] Detection ignored because tracking is already active.")
            return
        }

        if shouldThrottleActivityPrompt() {
            LogManager.shared.info("[Movement] Detection ignored due to prompt cooldown. Cooldown: \(Int(activityPromptCooldownMinutes)) min.")
            return
        }

        markActivityPromptSent()
        scheduleActivityStartPromptNotification(for: activity)
    }

    private func handleActivityStopped() {
        guard wasAutoStarted, isTrackingEnabled else { return }

        LogManager.shared.info("[Movement] Auto-stopping tracking after stationary event.")
        sendAutoStopNotification()
        disableTracking()
    }

    func confirmActivityStartPrompt(_ prompt: ActivityStartPromptContext) {
        guard !isTrackingEnabled else {
            LogManager.shared.info("[Movement] Prompt accepted, but tracking is already active.")
            return
        }

        guard hasLocationPermission else {
            LogManager.shared.warning("[Movement] Prompt accepted without location permission. Requesting authorization.")
            requestAlwaysAuthorization()
            return
        }

        wasAutoStarted = true
        enableTracking()
        LogManager.shared.info("[Movement] User started tracking from movement prompt: \(prompt.reason).")
    }

    func declineActivityStartPrompt(_ prompt: ActivityStartPromptContext) {
        LogManager.shared.info("[Movement] User declined movement prompt: \(prompt.reason).")
    }

    private func shouldThrottleActivityPrompt(at now: Date = Date()) -> Bool {
        guard let lastPrompt = lastActivityPromptSentAt else { return false }
        return now.timeIntervalSince(lastPrompt) < activityPromptCooldownInterval
    }

    private func markActivityPromptSent(at date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastActivityPromptSentAtKey)
    }

    private func scheduleActivityStartPromptNotification(for activity: CMMotionActivity) {
        let reason = ActivityDetectionManager.triggerReason(for: activity)
        let activityType = ActivityDetectionManager.primaryActivityType(for: activity)?.rawValue ?? "movement"
        let prompt = ActivityStartPromptContext(reason: reason, activityType: activityType)

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let canNotify = settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional ||
                settings.authorizationStatus == .ephemeral

            if canNotify {
                let content = UNMutableNotificationContent()
                content.title = "Movement Detected"
                content.body = "\(reason.prefix(1).uppercased() + reason.dropFirst()). Tap to review and start recording."
                content.sound = .default
                content.userInfo = prompt.userInfo

                let request = UNNotificationRequest(
                    identifier: "\(ActivityStartPromptContext.notificationIdentifierPrefix)\(prompt.id)",
                    content: content,
                    trigger: nil
                )

                UNUserNotificationCenter.current().add(request) { error in
                    Task { @MainActor in
                        if let error {
                            LogManager.shared.error("[Movement] Failed to schedule movement prompt notification: \(error.localizedDescription)")
                        } else {
                            LogManager.shared.info("[Movement] Movement prompt notification sent: \(reason).")
                        }
                    }
                }
            } else {
                await MainActor.run {
                    // Fall back to in-app prompt when notifications are not authorized.
                    AppDelegate.pendingActivityPromptUserInfo = prompt.userInfo
                    NotificationCenter.default.post(name: .activityStartPromptRequested, object: nil, userInfo: prompt.userInfo)
                    LogManager.shared.warning("[Movement] Notifications not authorized; showing movement prompt in-app.")
                }
            }
        }
    }

    // MARK: - HealthKit Workout Observer (Auto-Start)

    private func setupHealthKitObserver() {
        healthKitObserver.onWorkoutDetected = { [weak self] in
            Task { @MainActor in
                self?.handleWorkoutDetected()
            }
        }

        if autoStartOnWorkout && !isTrackingEnabled {
            healthKitObserver.startObserving()
        }
    }

    func setAutoStartOnWorkout(_ enabled: Bool) {
        if enabled {
            Task {
                let authorized = await healthKitObserver.requestAuthorization()
                autoStartOnWorkout = authorized
                UserDefaults.standard.set(authorized, forKey: "autoStartOnWorkout")
                if authorized && !isTrackingEnabled {
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
              !isTrackingEnabled else { return }

        wasAutoStarted = true
        enableTracking()
        sendAutoStartNotification(reason: "workout detected")
    }

    // MARK: - Distance-Based Trigger (Auto-Start)

    func setAutoStartOnDistance(_ enabled: Bool) {
        autoStartOnDistance = enabled
        UserDefaults.standard.set(enabled, forKey: "autoStartOnDistance")
    }

    private func handleDistanceThresholdExceeded() {
        guard autoStartOnDistance,
              !isTrackingEnabled else { return }

        wasAutoStarted = true
        enableTracking()
        sendAutoStartNotification(reason: "above-average travel detected")
    }

    // MARK: - Auto-Start Notifications

    private func sendAutoStartNotification(reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "Recording Started"
        content.body = "\(reason.prefix(1).uppercased() + reason.dropFirst()) — tracking enabled"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "autoStart-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func sendAutoStopNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Recording Stopped"
        content.body = "Activity ended — tracking disabled"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "autoStop-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Check activity on background wake
    private func checkActivityOnWake() {
        guard autoStartOnActivity,
              !isTrackingEnabled else { return }

        Task {
            guard let activity = await activityDetectionManager.queryCurrentActivity() else { return }
            if activityDetectionManager.shouldTriggerPrompt(for: activity) {
                LogManager.shared.info("[Movement] Background wake matched movement trigger; preparing prompt.")
                handleActivityDetected(activity)
            } else {
                LogManager.shared.info("[Movement] Background wake activity did not match configured movement triggers.")
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
            currentLocationName: currentLocationName,
            currentAddress: currentAddress,
            lastLatitude: currentLocation?.coordinate.latitude,
            lastLongitude: currentLocation?.coordinate.longitude,
            lastUpdateTime: Date(),
            todayVisitsCount: todayVisits.count,
            todayDistanceMeters: totalDistance,
            todayPointsCount: todayPoints.count,
            trackingStartTime: trackingStartTime,
            trackingAutoOffHours: trackingAutoOffHours > 0 ? trackingAutoOffHours : nil,
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
            updateTrackingState()
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

            // While not recording, check if movement should trigger a start prompt.
            if !isTrackingEnabled {
                checkActivityOnWake()

                // Check distance-based trigger
                if autoStartOnDistance, dailyDistanceTracker.isAboveAverage() {
                    handleDistanceThresholdExceeded()
                }
            }

            if isTrackingEnabled {
                saveLocationPoint(location)

                // Geocode location for Live Activity (throttled to avoid too many requests)
                await geocodeForLiveActivity(location: location)

                // Update Live Activity
                let remainingSeconds: Int?
                if let remaining = trackingRemainingTime {
                    remainingSeconds = Int(remaining)
                } else {
                    remainingSeconds = nil
                }
                liveActivityManager.updateActivity(
                    location: location,
                    locationName: currentLocationName,
                    remainingSeconds: remainingSeconds
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
