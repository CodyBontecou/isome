import CoreLocation
import Foundation
import WidgetKit

/// A small, watch-native location tracker so the watch app can run without the
/// iPhone companion app being installed or launched.
final class WatchLocationTracker: NSObject, ObservableObject {
    @Published private(set) var locationData: SharedLocationData
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published var lastErrorMessage: String?

    private let locationManager = CLLocationManager()
    private let defaults: UserDefaults
    private var persistedState: PersistedWatchTrackingState

    private let minimumMovementDistance: CLLocationDistance = 10
    private let visitDistanceThreshold: CLLocationDistance = 100
    private let acceptableHorizontalAccuracy: CLLocationAccuracy = 100

    override init() {
        let defaults = UserDefaults(suiteName: SharedLocationData.appGroupIdentifier) ?? .standard
        self.defaults = defaults
        self.locationData = SharedLocationData.load() ?? .empty
        self.persistedState = Self.loadPersistedState(from: defaults)
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        configureLocationManager()
        rollOverIfNeeded()

        if locationData.isTrackingEnabled, canUseLocation {
            startLocationUpdates()
        }
    }

    var canUseLocation: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var needsLocationPermission: Bool {
        authorizationStatus == .notDetermined
    }

    var authorizationMessage: String? {
        switch authorizationStatus {
        case .notDetermined:
            return String(localized: "Enable location to track directly on Apple Watch.")
        case .restricted:
            return String(localized: "Location is restricted on this Apple Watch.")
        case .denied:
            return String(localized: "Location is denied. Enable it in Settings to track from Apple Watch.")
        case .authorizedAlways, .authorizedWhenInUse:
            return nil
        @unknown default:
            return String(localized: "Location permission is unavailable.")
        }
    }

    func refresh() {
        authorizationStatus = locationManager.authorizationStatus
        rollOverIfNeeded()
    }

    func requestLocationPermission() {
        lastErrorMessage = nil
        locationManager.requestWhenInUseAuthorization()
    }

    func toggleTracking() {
        locationData.isTrackingEnabled ? stopTracking() : startTracking()
    }

    func startTracking() {
        lastErrorMessage = nil
        rollOverIfNeeded()

        guard canUseLocation else {
            requestLocationPermission()
            return
        }

        if locationData.trackingStartTime == nil {
            locationData.trackingStartTime = Date()
        }
        locationData.isTrackingEnabled = true
        saveLocationData()
        startLocationUpdates()
    }

    func stopTracking() {
        locationData.isTrackingEnabled = false
        locationData.trackingStartTime = nil
        locationData.stopAfterHours = nil
        saveLocationData()
        locationManager.stopUpdatingLocation()
    }

    func resetToday() {
        persistedState = PersistedWatchTrackingState(dayStart: Calendar.current.startOfDay(for: Date()))
        locationData.todayVisitsCount = 0
        locationData.todayDistanceMeters = 0
        locationData.todayPointsCount = 0
        locationData.currentLocationName = nil
        locationData.currentAddress = nil
        locationData.lastLatitude = nil
        locationData.lastLongitude = nil
        locationData.lastUpdateTime = nil
        savePersistedState()
        saveLocationData()
    }

    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = minimumMovementDistance
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
    }

    private func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status

        if canUseLocation, locationData.isTrackingEnabled {
            startLocationUpdates()
        } else if status == .denied || status == .restricted {
            locationManager.stopUpdatingLocation()
        }
    }

    private func handleLocation(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= acceptableHorizontalAccuracy else {
            return
        }

        rollOverIfNeeded(for: location.timestamp)

        locationData.lastLatitude = location.coordinate.latitude
        locationData.lastLongitude = location.coordinate.longitude
        locationData.lastUpdateTime = location.timestamp
        locationData.currentLocationName = formattedCoordinate(for: location)
        locationData.currentAddress = nil
        locationData.usesMetricDistanceUnits = usesMetricDistanceUnits

        if locationData.isTrackingEnabled {
            locationData.todayPointsCount += 1
            accumulateDistance(using: location)
            updateVisitCount(using: location)
        }

        persistedState.lastLatitude = location.coordinate.latitude
        persistedState.lastLongitude = location.coordinate.longitude
        persistedState.lastTimestamp = location.timestamp

        savePersistedState()
        saveLocationData()
    }

    private func accumulateDistance(using location: CLLocation) {
        guard let previous = persistedState.lastLocation else {
            return
        }

        let distance = location.distance(from: previous)
        guard distance >= minimumMovementDistance else {
            return
        }

        locationData.todayDistanceMeters += distance
    }

    private func updateVisitCount(using location: CLLocation) {
        guard let countedVisitLocation = persistedState.lastCountedVisitLocation else {
            locationData.todayVisitsCount = max(locationData.todayVisitsCount, 1)
            persistedState.lastCountedVisitLatitude = location.coordinate.latitude
            persistedState.lastCountedVisitLongitude = location.coordinate.longitude
            return
        }

        guard location.distance(from: countedVisitLocation) >= visitDistanceThreshold else {
            return
        }

        locationData.todayVisitsCount += 1
        persistedState.lastCountedVisitLatitude = location.coordinate.latitude
        persistedState.lastCountedVisitLongitude = location.coordinate.longitude
    }

    private func rollOverIfNeeded(for date: Date = Date()) {
        let calendar = Calendar.current
        guard !calendar.isDate(persistedState.dayStart, inSameDayAs: date) else {
            return
        }

        let wasTracking = locationData.isTrackingEnabled
        let trackingStartTime = locationData.trackingStartTime
        let stopAfterHours = locationData.stopAfterHours

        persistedState = PersistedWatchTrackingState(dayStart: calendar.startOfDay(for: date))
        locationData = .empty
        locationData.isTrackingEnabled = wasTracking
        locationData.trackingStartTime = trackingStartTime
        locationData.stopAfterHours = stopAfterHours
        locationData.usesMetricDistanceUnits = usesMetricDistanceUnits
        savePersistedState()
        saveLocationData()
    }

    private func saveLocationData() {
        locationData.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func savePersistedState() {
        guard let encoded = try? JSONEncoder().encode(persistedState) else { return }
        defaults.set(encoded, forKey: Self.persistedStateKey)
    }

    private var usesMetricDistanceUnits: Bool {
        Locale.current.measurementSystem != .us
    }

    private func formattedCoordinate(for location: CLLocation) -> String {
        String(
            format: "%.4f, %.4f",
            locale: Locale(identifier: "en_US_POSIX"),
            location.coordinate.latitude,
            location.coordinate.longitude
        )
    }

    private static let persistedStateKey = "watchLocationTrackingState"

    private static func loadPersistedState(from defaults: UserDefaults) -> PersistedWatchTrackingState {
        guard let data = defaults.data(forKey: persistedStateKey),
              let decoded = try? JSONDecoder().decode(PersistedWatchTrackingState.self, from: data) else {
            return PersistedWatchTrackingState(dayStart: Calendar.current.startOfDay(for: Date()))
        }
        return decoded
    }
}

extension WatchLocationTracker: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.handleAuthorizationChange(manager.authorizationStatus)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            locations.forEach { self?.handleLocation($0) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            if let clError = error as? CLError, clError.code == .locationUnknown {
                return
            }
            self?.lastErrorMessage = error.localizedDescription
        }
    }
}

private struct PersistedWatchTrackingState: Codable {
    var dayStart: Date
    var lastLatitude: Double?
    var lastLongitude: Double?
    var lastTimestamp: Date?
    var lastCountedVisitLatitude: Double?
    var lastCountedVisitLongitude: Double?

    var lastLocation: CLLocation? {
        guard let lastLatitude, let lastLongitude else { return nil }
        return CLLocation(latitude: lastLatitude, longitude: lastLongitude)
    }

    var lastCountedVisitLocation: CLLocation? {
        guard let lastCountedVisitLatitude, let lastCountedVisitLongitude else { return nil }
        return CLLocation(latitude: lastCountedVisitLatitude, longitude: lastCountedVisitLongitude)
    }
}
