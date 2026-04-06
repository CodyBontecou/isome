import Foundation
import CoreLocation
import SwiftData
import Combine
import ActivityKit
import WidgetKit

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
    
    // Current location name for Live Activity
    private var currentLocationName: String?
    private var currentAddress: String?
    private var lastGeocodedLocation: CLLocation?

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

        authorizationStatus = locationManager.authorizationStatus
        
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
        isTrackingEnabled = false
        isContinuousTrackingEnabled = false
        UserDefaults.standard.set(isTrackingEnabled, forKey: "isTrackingEnabled")
        UserDefaults.standard.set(isContinuousTrackingEnabled, forKey: "isContinuousTrackingEnabled")
        syncDataToWatch()
    }

    private func updateTrackingState() {
        if isTrackingEnabled && hasLocationPermission {
            locationManager.startMonitoringVisits()
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            locationManager.stopMonitoringVisits()
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.stopUpdatingLocation()
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
        context.insert(point)

        do {
            try context.save()
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
        for i in 1..<todayPoints.count {
            totalDistance += todayPoints[i].distance(to: todayPoints[i-1])
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
            continuousTrackingAutoOffHours: continuousTrackingAutoOffHours > 0 ? continuousTrackingAutoOffHours : nil
        )
        
        // Save to App Group and reload widget timelines
        sharedData.save()
        WidgetCenter.shared.reloadAllTimelines()
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
