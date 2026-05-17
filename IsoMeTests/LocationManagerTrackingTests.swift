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

    func testVehicleSelectionStoresAssignedVehicleID() throws {
        let context = try makeVehicleContext()
        let vehicle = Vehicle(name: "Work Truck", isDefault: true)
        let visit = Visit(latitude: 37.0, longitude: -122.0, arrivedAt: Date())
        context.insert(vehicle)
        context.insert(visit)
        try context.save()

        let viewModel = LocationViewModel(modelContext: context, locationManager: manager)
        viewModel.assignVehicle(vehicle.id, to: visit)

        XCTAssertEqual(visit.vehicleID, vehicle.id)
    }

    func testVisitExportIncludesResolvedVehicleName() throws {
        let vehicleID = UUID()
        let vehicle = Vehicle(id: vehicleID, name: "Renamed Truck")
        let visit = Visit(
            latitude: 37.0,
            longitude: -122.0,
            arrivedAt: Date(timeIntervalSince1970: 100),
            vehicleID: vehicleID
        )

        let data = try ExportService.exportToJSON(visits: [visit], vehicles: [vehicle])
        let exportedVisit = try firstDictionary(in: data, rootKey: "visits")

        XCTAssertEqual(exportedVisit["vehicleID"] as? String, vehicleID.uuidString)
        XCTAssertEqual(exportedVisit["vehicleName"] as? String, "Renamed Truck")
    }

    func testLocationPointExportIncludesResolvedVehicleName() throws {
        let vehicleID = UUID()
        let vehicle = Vehicle(id: vehicleID, name: "Family Car")
        let point = LocationPoint(
            latitude: 37.0,
            longitude: -122.0,
            timestamp: Date(timeIntervalSince1970: 100),
            horizontalAccuracy: 5,
            vehicleID: vehicleID
        )

        let data = try ExportService.exportLocationPointsToJSON(points: [point], vehicles: [vehicle])
        let exportedPoint = try firstDictionary(in: data, rootKey: "points")

        XCTAssertEqual(exportedPoint["vehicleID"] as? String, vehicleID.uuidString)
        XCTAssertEqual(exportedPoint["vehicleName"] as? String, "Family Car")
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

    private func makeVehicleContext() throws -> ModelContext {
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

@MainActor
final class LocationViewModelLoadTests: XCTestCase {
    private let stressPointCount = 33_000
    private let millionPointStressTestCount = 1_000_000
    private let millionPointStressTestEnvKey = "ISOME_RUN_MILLION_POINT_STRESS_TEST"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
        super.tearDown()
    }

    func testStartupWithThirtyThreeThousandHistoricalPointsDoesNotEagerlyLoadFullPointCache() throws {
        let container = try makeContainer()
        let tripRange = try seedLocationPoints(
            count: stressPointCount,
            into: container.mainContext,
            start: Date().addingTimeInterval(-7 * 86_400)
        )

        let viewModel = LocationViewModel(
            modelContext: container.mainContext,
            locationManager: LocationManager()
        )

        XCTAssertEqual(viewModel.locationPointCount, stressPointCount)
        XCTAssertTrue(viewModel.locationPoints.isEmpty, "Startup should not load every historical point into the export cache.")
        XCTAssertTrue(viewModel.mapLocationPoints.isEmpty, "Default Today map range should not load old road-trip points.")
        XCTAssertTrue(viewModel.todayLocationPoints.isEmpty, "Historical points should not inflate today's live stats.")

        viewModel.setCustomMapDateRange(tripRange)

        XCTAssertEqual(viewModel.mapLocationPoints.count, stressPointCount)
        XCTAssertTrue(viewModel.locationPoints.isEmpty, "Loading a large selected map range should not populate the full export cache.")
    }

    func testOnDemandExportLoadStillFetchesThirtyThreeThousandPoints() throws {
        let container = try makeContainer()
        try seedLocationPoints(
            count: stressPointCount,
            into: container.mainContext,
            start: Date().addingTimeInterval(-7 * 86_400)
        )

        let viewModel = LocationViewModel(
            modelContext: container.mainContext,
            locationManager: LocationManager()
        )

        XCTAssertTrue(viewModel.locationPoints.isEmpty)

        viewModel.loadLocationPoints()

        XCTAssertEqual(viewModel.locationPoints.count, stressPointCount)
        XCTAssertEqual(viewModel.locationPointCount, stressPointCount)
    }

    func testMapViewDownsamplesThirtyThreeThousandSelectedPointsForRendering() throws {
        let container = try makeContainer()
        let viewModel = LocationViewModel(
            modelContext: container.mainContext,
            locationManager: LocationManager()
        )
        viewModel.mapLocationPoints = makeDetachedPoints(count: stressPointCount)

        let mapView = LocationMapView(viewModel: viewModel)

        XCTAssertEqual(mapView.filteredPoints.count, stressPointCount)
        XCTAssertEqual(mapView.displayPathPoints.count, 2_500)
        XCTAssertLessThanOrEqual(mapView.spacedPoints.count, 500)
        XCTAssertEqual(mapView.displayPathPoints.first?.id, viewModel.mapLocationPoints.first?.id)
        XCTAssertEqual(mapView.displayPathPoints.last?.id, viewModel.mapLocationPoints.last?.id)
    }

    func testAppendingPointAcrossMidnightReloadsTodayCache() throws {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterdayReference = calendar.date(byAdding: .day, value: -1, to: todayStart)!.addingTimeInterval(60)
        let todayReference = todayStart.addingTimeInterval(60)

        let container = try makeContainer()
        let context = container.mainContext
        let yesterdayPoint = LocationPoint(
            latitude: 37.0,
            longitude: -122.0,
            timestamp: yesterdayReference,
            horizontalAccuracy: 5
        )
        context.insert(yesterdayPoint)
        try context.save()

        let manager = LocationManager()
        let viewModel = LocationViewModel(
            modelContext: context,
            locationManager: manager
        )
        viewModel.loadTodayLocationPoints(referenceDate: yesterdayReference)
        viewModel.selectMapPreset(.today, referenceDate: yesterdayReference)
        XCTAssertEqual(viewModel.todayLocationPoints.map(\.id), [yesterdayPoint.id])
        XCTAssertEqual(viewModel.mapLocationPoints.map(\.id), [yesterdayPoint.id])

        let todayPoint = LocationPoint(
            latitude: 37.1,
            longitude: -122.1,
            timestamp: todayReference,
            horizontalAccuracy: 5
        )
        context.insert(todayPoint)
        try context.save()
        let pointCountBeforeAppend = viewModel.locationPointCount

        manager.latestSavedLocationPoint = todayPoint
        viewModel.appendLatestSavedLocationPoint(referenceDate: todayReference)

        XCTAssertEqual(viewModel.todayLocationPoints.map(\.id), [todayPoint.id])
        XCTAssertFalse(viewModel.todayLocationPoints.contains { $0.id == yesterdayPoint.id })
        XCTAssertEqual(viewModel.mapLocationPoints.map(\.id), [todayPoint.id])
        XCTAssertFalse(viewModel.mapLocationPoints.contains { $0.id == yesterdayPoint.id })
        XCTAssertEqual(viewModel.locationPointCount, pointCountBeforeAppend + 1)
    }

    func testAppendingPointRefreshesActiveMapPresetRangeBeforeUpdatingMapCache() throws {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let initialReference = todayStart.addingTimeInterval(60)
        let laterReference = todayStart.addingTimeInterval(600)

        let container = try makeContainer()
        let context = container.mainContext
        let manager = LocationManager()
        let viewModel = LocationViewModel(
            modelContext: context,
            locationManager: manager
        )
        viewModel.selectMapPreset(.today, referenceDate: initialReference)
        XCTAssertFalse(viewModel.mapDateRange.contains(laterReference))

        let laterPoint = LocationPoint(
            latitude: 37.2,
            longitude: -122.2,
            timestamp: laterReference,
            horizontalAccuracy: 5
        )
        context.insert(laterPoint)
        try context.save()

        manager.latestSavedLocationPoint = laterPoint
        viewModel.appendLatestSavedLocationPoint(referenceDate: laterReference)

        XCTAssertTrue(viewModel.mapDateRange.contains(laterPoint.timestamp))
        XCTAssertEqual(viewModel.mapLocationPoints.map(\.id), [laterPoint.id])
    }

    func testAppendingPointDoesNotExpandCustomMapDateRange() throws {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let rangeEnd = todayStart.addingTimeInterval(60)
        let laterReference = todayStart.addingTimeInterval(600)

        let container = try makeContainer()
        let context = container.mainContext
        let manager = LocationManager()
        let viewModel = LocationViewModel(
            modelContext: context,
            locationManager: manager
        )
        viewModel.setCustomMapDateRange(todayStart...rangeEnd)

        let laterPoint = LocationPoint(
            latitude: 37.3,
            longitude: -122.3,
            timestamp: laterReference,
            horizontalAccuracy: 5
        )
        context.insert(laterPoint)
        try context.save()

        manager.latestSavedLocationPoint = laterPoint
        viewModel.appendLatestSavedLocationPoint(referenceDate: laterReference)

        XCTAssertNil(viewModel.activeMapPreset)
        XCTAssertFalse(viewModel.mapDateRange.contains(laterPoint.timestamp))
        XCTAssertTrue(viewModel.mapLocationPoints.isEmpty)
    }

    func testManualMillionPointStartupDoesNotEagerlyLoadFullPointCache() throws {
        guard ProcessInfo.processInfo.environment[millionPointStressTestEnvKey] == "1" else {
            throw XCTSkip("Set \(millionPointStressTestEnvKey)=1 to run the 1,000,000-point startup stress test.")
        }

        let container = try makeContainer()
        try seedLocationPoints(
            count: millionPointStressTestCount,
            into: container,
            start: Date().addingTimeInterval(-30 * 86_400),
            batchSize: 10_000
        )

        let viewModel = LocationViewModel(
            modelContext: container.mainContext,
            locationManager: LocationManager()
        )

        XCTAssertEqual(viewModel.locationPointCount, millionPointStressTestCount)
        XCTAssertTrue(viewModel.locationPoints.isEmpty, "Startup should not load one million historical points into the export cache.")
        XCTAssertTrue(viewModel.mapLocationPoints.isEmpty, "Default Today map range should not load old stress-test points.")
        XCTAssertTrue(viewModel.todayLocationPoints.isEmpty, "Historical stress-test points should not inflate today's live stats.")
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Visit.self, LocationPoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @discardableResult
    private func seedLocationPoints(
        count: Int,
        into context: ModelContext,
        start: Date
    ) throws -> ClosedRange<Date> {
        let interval: TimeInterval = 5
        for index in 0..<count {
            context.insert(makePoint(index: index, start: start, interval: interval))
        }
        try context.save()

        let end = start.addingTimeInterval(Double(max(0, count - 1)) * interval)
        return start...end
    }

    @discardableResult
    private func seedLocationPoints(
        count: Int,
        into container: ModelContainer,
        start: Date,
        batchSize: Int
    ) throws -> ClosedRange<Date> {
        let interval: TimeInterval = 5

        for batchStart in stride(from: 0, to: count, by: batchSize) {
            let context = ModelContext(container)
            let batchEnd = min(batchStart + batchSize, count)
            for index in batchStart..<batchEnd {
                context.insert(makePoint(index: index, start: start, interval: interval))
            }
            try context.save()
        }

        let end = start.addingTimeInterval(Double(max(0, count - 1)) * interval)
        return start...end
    }

    private func makeDetachedPoints(count: Int) -> [LocationPoint] {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        return (0..<count).map { makePoint(index: $0, start: start, interval: 5) }
    }

    private func makePoint(index: Int, start: Date, interval: TimeInterval) -> LocationPoint {
        LocationPoint(
            latitude: 37.0 + Double(index % 1_000) * 0.0001,
            longitude: -122.0 + Double(index / 1_000) * 0.0001,
            timestamp: start.addingTimeInterval(Double(index) * interval),
            horizontalAccuracy: 5
        )
    }
}

final class LocationPointSamplerTests: XCTestCase {
    func testDownsampleCapsPointCountAndPreservesEndpoints() {
        let points = makePoints(count: 33_000)

        let sampled = LocationPointSampler.downsample(points, maximumCount: 2_500)

        XCTAssertLessThanOrEqual(sampled.count, 2_500)
        XCTAssertEqual(sampled.first?.id, points.first?.id)
        XCTAssertEqual(sampled.last?.id, points.last?.id)
    }

    func testSpacedCapsMarkerCountAndPreservesStart() {
        let points = makePoints(count: 10_000, latitudeStep: 0.001)

        let sampled = LocationPointSampler.spaced(
            points,
            minimumDistance: 50,
            maximumCount: 500
        )

        XCTAssertLessThanOrEqual(sampled.count, 500)
        XCTAssertEqual(sampled.first?.id, points.first?.id)
    }

    func testDownsampleWithZeroMaximumReturnsNoPoints() {
        XCTAssertTrue(LocationPointSampler.downsample(makePoints(count: 10), maximumCount: 0).isEmpty)
    }

    private func makePoints(count: Int, latitudeStep: Double = 0.0001) -> [LocationPoint] {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        return (0..<count).map { index in
            LocationPoint(
                latitude: 37.0 + Double(index) * latitudeStep,
                longitude: -122.0,
                timestamp: startDate.addingTimeInterval(Double(index)),
                horizontalAccuracy: 5
            )
        }
    }
}
