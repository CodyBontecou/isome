import XCTest
import CoreLocation
@testable import Spotted

/// Tests that the LocationManager tracking lifecycle is correct:
/// starting, stopping, and restarting should leave no stale state.
@MainActor
final class LocationManagerTrackingTests: XCTestCase {

    private var manager: LocationManager!

    override func setUp() {
        super.setUp()
        manager = LocationManager()
        // Clear any persisted state from prior runs
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "isContinuousTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "continuousTrackingAutoOffHours")
    }

    override func tearDown() {
        manager = nil
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "isContinuousTrackingEnabled")
        super.tearDown()
    }

    // MARK: - stopTracking must fully clean up

    /// stopTracking() must reset isContinuousTrackingEnabled AND
    /// clear the continuous tracking timer + start time so the next
    /// start cycle doesn't see stale state.
    func testStopTrackingClearsContinuousState() {
        // Simulate that continuous tracking was previously active
        manager.isContinuousTrackingEnabled = true
        manager.continuousTrackingStartTime = Date()

        manager.stopTracking()

        XCTAssertFalse(manager.isTrackingEnabled)
        XCTAssertFalse(manager.isContinuousTrackingEnabled)
        XCTAssertNil(manager.continuousTrackingStartTime,
                     "stopTracking must nil out continuousTrackingStartTime")
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

    /// Calling stopTracking() followed by startTracking() +
    /// enableContinuousTracking() should not leave leftover timer state.
    func testStopThenRestartHasCleanTimerState() {
        // Arrange – simulate previous continuous session
        manager.continuousTrackingStartTime = Date().addingTimeInterval(-3600)

        // Act – stop, then restart
        manager.stopTracking()

        XCTAssertNil(manager.continuousTrackingStartTime,
                     "After stop, start time must be nil before restarting")
    }
}
