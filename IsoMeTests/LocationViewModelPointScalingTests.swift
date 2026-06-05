import XCTest
import CoreLocation
import SwiftData
@testable import IsoMe

@MainActor
final class LocationViewModelPointScalingTests: XCTestCase {
    private let mapPointDisplayCap = 2_500

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
        UserDefaults.standard.removeObject(forKey: "allowNetworkGeocoding")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
        UserDefaults.standard.removeObject(forKey: "allowNetworkGeocoding")
        super.tearDown()
    }

    func testMapRangeDownsamplesLargePointHistoryAndLeavesExportCacheLazy() throws {
        let container = try makeInMemoryContainer()
        let start = fixtureDate(dayOffset: 0)
        let pointCount = 12_500
        let lastTimestamp = try insertPointHistory(
            count: pointCount,
            startingAt: start,
            interval: 1,
            into: container.mainContext
        )

        let viewModel = makeViewModel(container: container)
        let range = start...lastTimestamp
        viewModel.mapDateRange = range
        viewModel.loadMapLocationPoints(in: range)

        XCTAssertEqual(viewModel.totalLocationPointCount, pointCount)
        XCTAssertEqual(viewModel.mapLocationPointCount, pointCount)
        XCTAssertLessThanOrEqual(viewModel.mapLocationPoints.count, mapPointDisplayCap)
        XCTAssertGreaterThan(viewModel.mapLocationPoints.count, 0)
        XCTAssertEqual(
            viewModel.locationPoints.count,
            0,
            "Opening the map must not hydrate the full point history; export loads it on demand."
        )

        assertSortedByTimestamp(viewModel.mapLocationPoints)
        XCTAssertEqual(
            try XCTUnwrap(viewModel.mapLocationPoints.first?.timestamp.timeIntervalSince1970),
            start.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertEqual(
            try XCTUnwrap(viewModel.mapLocationPoints.last?.timestamp.timeIntervalSince1970),
            lastTimestamp.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testEnsureAllLocationPointsLoadedPreservesFullResolutionForExport() throws {
        let container = try makeInMemoryContainer()
        let start = fixtureDate(dayOffset: 1)
        let pointCount = 750
        let lastTimestamp = try insertPointHistory(
            count: pointCount,
            startingAt: start,
            interval: 5,
            into: container.mainContext
        )

        let viewModel = makeViewModel(container: container)
        XCTAssertEqual(viewModel.locationPoints.count, 0, "Full-resolution points should start lazy.")

        viewModel.ensureAllLocationPointsLoaded()

        XCTAssertEqual(viewModel.locationPoints.count, pointCount)
        XCTAssertEqual(viewModel.totalLocationPointCount, pointCount)
        assertSortedByTimestamp(viewModel.locationPoints)
        XCTAssertEqual(
            try XCTUnwrap(viewModel.locationPoints.first?.timestamp.timeIntervalSince1970),
            start.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertEqual(
            try XCTUnwrap(viewModel.locationPoints.last?.timestamp.timeIntervalSince1970),
            lastTimestamp.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testMapReloadCountsOnlySelectedDateRange() throws {
        let container = try makeInMemoryContainer()
        let firstDay = fixtureDate(dayOffset: 2)
        let secondDay = fixtureDate(dayOffset: 3)

        _ = try insertPointHistory(count: 5, startingAt: firstDay, interval: 60, into: container.mainContext)
        let secondDayLast = try insertPointHistory(count: 7, startingAt: secondDay, interval: 60, into: container.mainContext)

        let viewModel = makeViewModel(container: container)
        let range = secondDay...secondDayLast
        viewModel.mapDateRange = range
        viewModel.loadMapLocationPoints(in: range)

        XCTAssertEqual(viewModel.totalLocationPointCount, 12)
        XCTAssertEqual(viewModel.mapLocationPointCount, 7)
        XCTAssertEqual(viewModel.mapLocationPoints.count, 7)
        XCTAssertTrue(viewModel.mapLocationPoints.allSatisfy { range.contains($0.timestamp) })
        assertSortedByTimestamp(viewModel.mapLocationPoints)
    }

    func testLiveBatchAppendAddsEveryPointToMapAndSessionCaches() async throws {
        UserDefaults.standard.set(false, forKey: "allowNetworkGeocoding")
        let container = try makeInMemoryContainer()
        let manager = LocationManager()
        let start = Date()
        manager.isTrackingEnabled = true
        manager.isLiveActivityEnabled = false
        manager.trackingStartTime = start.addingTimeInterval(-1)

        let viewModel = LocationViewModel(modelContext: container.mainContext, locationManager: manager)
        let range = start.addingTimeInterval(-1)...start.addingTimeInterval(10)
        viewModel.mapDateRange = range
        viewModel.loadMapLocationPoints(in: range)

        let locations = [
            makeLocation(latitude: 18.3270, longitude: -67.2200, timestamp: start),
            makeLocation(latitude: 18.3271, longitude: -67.2201, timestamp: start.addingTimeInterval(1)),
            makeLocation(latitude: 18.3272, longitude: -67.2202, timestamp: start.addingTimeInterval(2))
        ]

        manager.locationManager(CLLocationManager(), didUpdateLocations: locations)
        try await waitUntil { viewModel.mapLocationPoints.count == 3 }

        XCTAssertEqual(viewModel.totalLocationPointCount, 3)
        XCTAssertEqual(viewModel.mapLocationPointCount, 3)
        XCTAssertEqual(viewModel.mapLocationPoints.count, 3)
        XCTAssertEqual(viewModel.todayLocationPoints.count, 3)
        XCTAssertEqual(viewModel.sessionLocationPoints.count, 3)
        XCTAssertEqual(viewModel.mapLocationPoints.map(\.timestamp), locations.map(\.timestamp))
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

    private func makeViewModel(container: ModelContainer) -> LocationViewModel {
        let manager = LocationManager()
        manager.isTrackingEnabled = false
        manager.trackingStartTime = nil
        return LocationViewModel(
            modelContext: container.mainContext,
            locationManager: manager
        )
    }

    @discardableResult
    private func insertPointHistory(
        count: Int,
        startingAt start: Date,
        interval: TimeInterval,
        into context: ModelContext
    ) throws -> Date {
        precondition(count > 0)

        var timestamp = start
        for index in 0..<count {
            timestamp = start.addingTimeInterval(Double(index) * interval)
            context.insert(LocationPoint(
                latitude: 37.0 + Double(index) * 0.00001,
                longitude: -122.0 - Double(index) * 0.00001,
                timestamp: timestamp,
                altitude: nil,
                speed: nil,
                horizontalAccuracy: 5,
                isOutlier: false
            ))
        }

        try context.save()
        return timestamp
    }

    private func fixtureDate(dayOffset: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 1
        components.day = 1 + dayOffset
        components.hour = 12
        components.minute = 0
        components.second = 0
        return components.date!
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

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool,
        timeout: TimeInterval = 1
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func assertSortedByTimestamp(
        _ points: [LocationPoint],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for pair in zip(points, points.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.timestamp, pair.1.timestamp, file: file, line: line)
        }
    }
}
