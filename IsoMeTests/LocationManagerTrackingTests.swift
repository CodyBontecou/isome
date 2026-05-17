import XCTest
import CoreLocation
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
        UserDefaults.standard.removeObject(forKey: "trackingMode")
        UserDefaults.standard.removeObject(forKey: "customVisitDetectionEnabled")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
        manager = LocationManager()
    }

    override func tearDown() {
        manager = nil
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "trackingMode")
        UserDefaults.standard.removeObject(forKey: "customVisitDetectionEnabled")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
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

    func testTrackingModeDefaultsToFullHistory() {
        XCTAssertEqual(manager.trackingMode, .fullHistory)
        XCTAssertTrue(manager.isVisitDetectionEnabled)
        XCTAssertFalse(manager.isDrivesOnlyMode)
    }

    func testDrivesOnlyDisablesVisitDetectionAndPersists() {
        manager.setTrackingMode(.drivesOnly)

        XCTAssertEqual(manager.trackingMode, .drivesOnly)
        XCTAssertTrue(manager.isDrivesOnlyMode)
        XCTAssertFalse(manager.isVisitDetectionEnabled)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "trackingMode"), TrackingMode.drivesOnly.rawValue)
    }

    func testFullHistoryRestoresVisitDetection() {
        manager.setTrackingMode(.drivesOnly)
        manager.setTrackingMode(.fullHistory)

        XCTAssertEqual(manager.trackingMode, .fullHistory)
        XCTAssertTrue(manager.isVisitDetectionEnabled)
    }

    func testCustomVisitDetectionPersists() {
        manager.setTrackingMode(.custom)
        manager.setCustomVisitDetectionEnabled(false)

        let fresh = LocationManager()
        XCTAssertEqual(fresh.trackingMode, .custom)
        XCTAssertFalse(fresh.isVisitDetectionEnabled)
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
}
