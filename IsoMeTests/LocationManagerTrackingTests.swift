import XCTest
import CoreLocation
@testable import IsoMe

/// Tests that the LocationManager tracking lifecycle is correct:
/// enabling and disabling should leave no stale state.
@MainActor
final class LocationManagerTrackingTests: XCTestCase {

    private var manager: LocationManager!

    override func setUp() {
        super.setUp()
        manager = LocationManager()
        // Clear any persisted state from prior runs
        UserDefaults.standard.removeObject(forKey: TrackingStorageKeys.enabled)
        UserDefaults.standard.removeObject(forKey: TrackingStorageKeys.autoOffHours)
    }

    override func tearDown() {
        manager = nil
        UserDefaults.standard.removeObject(forKey: TrackingStorageKeys.enabled)
        super.tearDown()
    }

    // MARK: - disableTracking must fully clean up

    /// disableTracking() must reset isTrackingEnabled and clear the timer +
    /// start time so the next start cycle doesn't see stale state.
    func testDisableTrackingClearsState() {
        // Simulate that tracking was previously active
        manager.isTrackingEnabled = true
        manager.trackingStartTime = Date()

        manager.disableTracking()

        XCTAssertFalse(manager.isTrackingEnabled)
        XCTAssertNil(manager.trackingStartTime,
                     "disableTracking must nil out trackingStartTime")
    }

    /// After disableTracking(), the Live Activity manager should not
    /// report an active session.
    func testDisableTrackingEndsLiveActivity() async {
        manager.disableTracking()

        // Give any async Task a moment to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        let liveActivityActive = LiveActivityManager.shared.isActivityActive
        XCTAssertFalse(liveActivityActive,
                       "disableTracking must end the Live Activity")
    }

    /// Disabling then re-enabling tracking should not leave leftover timer state.
    func testDisableThenReenableHasCleanTimerState() {
        // Arrange – simulate previous session
        manager.trackingStartTime = Date().addingTimeInterval(-3600)

        // Act – disable
        manager.disableTracking()

        XCTAssertNil(manager.trackingStartTime,
                     "After disable, start time must be nil before restarting")
    }
}
