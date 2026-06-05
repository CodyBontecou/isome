import XCTest
import CoreLocation
import SwiftData
@testable import IsoMe

/// Tests that the LocationManager tracking lifecycle is correct:
/// starting, stopping, and restarting should leave no stale state.
@MainActor
final class LocationManagerTrackingTests: XCTestCase {

    private var manager: LocationManager!

    override func setUp() {
        super.setUp()
        // Clear any persisted state from prior runs before instantiating
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
        UserDefaults.standard.removeObject(forKey: "allowNetworkGeocoding")
        manager = LocationManager()
    }

    override func tearDown() {
        manager = nil
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
        UserDefaults.standard.removeObject(forKey: "allowNetworkGeocoding")
        super.tearDown()
    }

    // MARK: - stopTracking must fully clean up

    /// stopTracking() must reset isTrackingEnabled and clear the start time
    /// so the next start cycle doesn't see stale state.
    func testStopTrackingClearsState() {
        // Simulate that tracking was previously active
        manager.isTrackingEnabled = true
        manager.trackingStartTime = Date()

        manager.stopTracking()

        XCTAssertFalse(manager.isTrackingEnabled)
        XCTAssertNil(manager.trackingStartTime,
                     "stopTracking must nil out trackingStartTime")
    }

    /// After stopTracking(), the Live Activity manager should not
    /// report an active session.
    func testStopTrackingEndsLiveActivity() async {
        manager.stopTracking()

        // Give any async Task a moment to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        let liveActivityActive = LiveActivityManager.shared.isActivityActive
        XCTAssertFalse(liveActivityActive,
                       "stopTracking must end the Live Activity")
    }

    // MARK: - Persisted defaults

    /// stopAfterHours defaults to 0 (Never) so a fresh user won't see
    /// surprise auto-stops.
    func testStopAfterHoursDefaultsToNever() {
        XCTAssertEqual(manager.stopAfterHours, 0.0)
    }

    /// Distance filter defaults to 5m (the most aggressive available)
    /// to maximize captured points by default.
    func testDistanceFilterDefaultsToFiveMeters() {
        XCTAssertEqual(manager.distanceFilter, 5.0)
    }

    /// setStopAfterHours persists across reinstantiation.
    func testStopAfterHoursIsPersisted() {
        manager.setStopAfterHours(2.0)
        let fresh = LocationManager()
        XCTAssertEqual(fresh.stopAfterHours, 2.0)
    }

    /// Live Activity monitor defaults to on for existing behavior.
    func testLiveActivityEnabledDefaultsToOn() {
        XCTAssertTrue(manager.isLiveActivityEnabled)
    }

    /// Live Activity monitor preference persists across reinstantiation.
    func testLiveActivityEnabledIsPersisted() {
        manager.setLiveActivityEnabled(false)
        let fresh = LocationManager()
        XCTAssertFalse(fresh.isLiveActivityEnabled)
    }

    /// Core Location may deliver multiple chronological points in one delegate callback.
    /// Tracking must persist every valid point, not just `locations.last`, otherwise
    /// background batches render as long straight-line jumps on the map.
    func testDidUpdateLocationsPersistsEveryValidLocationInBatch() async throws {
        UserDefaults.standard.set(false, forKey: "allowNetworkGeocoding")
        let container = try makeInMemoryContainer()
        manager.setModelContext(container.mainContext)
        manager.isTrackingEnabled = true
        manager.isLiveActivityEnabled = false

        let start = Date()
        let locations = [
            makeLocation(latitude: 18.3270, longitude: -67.2200, timestamp: start),
            makeLocation(latitude: 18.3271, longitude: -67.2201, timestamp: start.addingTimeInterval(1)),
            makeLocation(latitude: 18.3272, longitude: -67.2202, timestamp: start.addingTimeInterval(2))
        ]

        manager.locationManager(CLLocationManager(), didUpdateLocations: locations)
        try await waitForSavedPointCount(3)

        var descriptor = FetchDescriptor<LocationPoint>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
        let savedPoints = try container.mainContext.fetch(descriptor)

        XCTAssertEqual(savedPoints.count, 3)
        XCTAssertEqual(savedPoints.map(\.timestamp), locations.map(\.timestamp))
        XCTAssertEqual(manager.locationPointsSavedCount, 3)
        XCTAssertEqual(manager.lastSavedLocationPoints.count, 3)
        XCTAssertEqual(manager.lastSavedLocationPoint?.timestamp, locations.last?.timestamp)
        XCTAssertEqual(manager.currentLocation?.timestamp, locations.last?.timestamp)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Visit.self, LocationPoint.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeLocation(latitude: Double, longitude: Double, timestamp: Date) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: -1,
            speed: 10,
            timestamp: timestamp
        )
    }

    private func waitForSavedPointCount(_ count: Int, timeout: TimeInterval = 1) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.locationPointsSavedCount < count {
            if Date() >= deadline {
                XCTFail("Timed out waiting for saved location points")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
