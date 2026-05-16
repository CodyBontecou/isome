import XCTest
import CoreLocation
import SwiftData
@testable import IsoMe

/// Tests that the LocationManager tracking lifecycle is correct:
/// starting, stopping, and restarting should leave no stale state.
@MainActor
final class LocationManagerTrackingTests: XCTestCase {

    private var manager: LocationManager!
    private var retainedContainers: [ModelContainer] = []

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
        retainedContainers = []
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

    func testVehicleSelectionStoresManualAttribution() throws {
        let context = try makeInMemoryContext()
        let vehicle = Vehicle(name: "Work Truck", isDefault: true)
        let visit = Visit(latitude: 37.0, longitude: -122.0, arrivedAt: Date())
        context.insert(vehicle)
        context.insert(visit)
        try context.save()

        let viewModel = LocationViewModel(modelContext: context, locationManager: manager)
        viewModel.assignVehicle(vehicle.id, to: visit)

        XCTAssertEqual(visit.vehicleID, vehicle.id)
        XCTAssertEqual(visit.vehicleName, "Work Truck")
        XCTAssertEqual(visit.vehicleDetectionSource, "manual")
        XCTAssertNil(visit.vehicleBluetoothPortName)
    }

    func testBluetoothAttributionSnapshotSurvivesMissingVehicleLookup() throws {
        let vehicleID = UUID()
        let point = LocationPoint(
            latitude: 37.0,
            longitude: -122.0,
            timestamp: Date(timeIntervalSince1970: 100),
            horizontalAccuracy: 5,
            vehicleID: vehicleID,
            vehicleName: "Family Car",
            vehicleDetectionSource: "bluetooth",
            vehicleBluetoothPortName: "Car Audio"
        )

        let data = try ExportService.exportLocationPointsToJSON(points: [point], vehicles: [])
        let exportedPoint = try firstDictionary(in: data, rootKey: "points")

        XCTAssertEqual(exportedPoint["vehicleID"] as? String, vehicleID.uuidString)
        XCTAssertEqual(exportedPoint["vehicleName"] as? String, "Family Car")
        XCTAssertEqual(point.vehicleDetectionSource, "bluetooth")
        XCTAssertEqual(point.vehicleBluetoothPortName, "Car Audio")
    }

    func testResolvedVehicleNameOverridesFallbackSnapshot() throws {
        let vehicleID = UUID()
        let vehicle = Vehicle(id: vehicleID, name: "Renamed Truck")
        let visit = Visit(
            latitude: 37.0,
            longitude: -122.0,
            arrivedAt: Date(timeIntervalSince1970: 100),
            vehicleID: vehicleID,
            vehicleName: "Old Truck"
        )

        let data = try ExportService.exportToJSON(visits: [visit], vehicles: [vehicle])
        let exportedVisit = try firstDictionary(in: data, rootKey: "visits")

        XCTAssertEqual(exportedVisit["vehicleID"] as? String, vehicleID.uuidString)
        XCTAssertEqual(exportedVisit["vehicleName"] as? String, "Renamed Truck")
    }

    func testMissingVehicleUsesAttributionFallbackSnapshot() throws {
        let vehicleID = UUID()
        let visit = Visit(
            latitude: 37.0,
            longitude: -122.0,
            arrivedAt: Date(timeIntervalSince1970: 100),
            vehicleID: vehicleID,
            vehicleName: "Archived Truck"
        )

        let data = try ExportService.exportToJSON(visits: [visit], vehicles: [])
        let exportedVisit = try firstDictionary(in: data, rootKey: "visits")

        XCTAssertEqual(exportedVisit["vehicleID"] as? String, vehicleID.uuidString)
        XCTAssertEqual(exportedVisit["vehicleName"] as? String, "Archived Truck")
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

    private func makeInMemoryContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Visit.self,
            LocationPoint.self,
            Vehicle.self,
            configurations: configuration
        )
        retainedContainers.append(container)
        return container.mainContext
    }

    private func firstDictionary(in data: Data, rootKey: String) throws -> [String: Any] {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let values = try XCTUnwrap(root[rootKey] as? [[String: Any]])
        return try XCTUnwrap(values.first)
    }
}
