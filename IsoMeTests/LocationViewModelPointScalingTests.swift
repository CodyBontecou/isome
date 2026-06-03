import XCTest
import SwiftData
import CoreLocation
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
        UserDefaults.standard.removeObject(forKey: "processedWatchManualVisitCommandIDs")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
        UserDefaults.standard.removeObject(forKey: "processedWatchManualVisitCommandIDs")
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

@MainActor
final class ManualVisitCorrectionTests: XCTestCase {
    private var fixedNow: Date {
        date(year: 2026, month: 2, day: 3, hour: 12, minute: 0)
    }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(false, forKey: "allowNetworkGeocoding")
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "allowNetworkGeocoding")
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "stopAfterHours")
        UserDefaults.standard.removeObject(forKey: "distanceFilter")
        UserDefaults.standard.removeObject(forKey: "isLiveActivityEnabled")
        super.tearDown()
    }

    func testLegacyVisitDefaultsToAutomaticUnconfirmed() {
        let visit = Visit(
            latitude: 37.0,
            longitude: -122.0,
            arrivedAt: fixedNow
        )
        visit.sourceRaw = nil
        visit.confirmationStatusRaw = nil

        XCTAssertEqual(visit.source, .automatic)
        XCTAssertEqual(visit.confirmationStatus, .unconfirmed)
    }

    func testPersistedVisitWithoutMetadataReloadsWithDefaults() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IsoMeVisitMetadataSmoke-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("default.store")
        do {
            let container = try makeFileBackedContainer(url: storeURL)
            let visit = Visit(
                latitude: 37.0,
                longitude: -122.0,
                arrivedAt: fixedNow
            )
            visit.sourceRaw = nil
            visit.confirmationStatusRaw = nil
            container.mainContext.insert(visit)
            try container.mainContext.save()
        }

        do {
            let container = try makeFileBackedContainer(url: storeURL)
            let visits = try container.mainContext.fetch(FetchDescriptor<Visit>())
            let reloaded = try XCTUnwrap(visits.first)

            XCTAssertEqual(reloaded.source, .automatic)
            XCTAssertEqual(reloaded.confirmationStatus, .unconfirmed)
        }
    }

    func testConfirmCorrectAndUndoPreserveOriginalPlaceMetadata() throws {
        let container = try makeInMemoryContainer()
        let viewModel = makeViewModel(container: container)
        let visit = Visit(
            latitude: 37.7765,
            longitude: -122.4241,
            arrivedAt: fixedNow.addingTimeInterval(-3600),
            locationName: "Bookstore",
            address: "10 Market St",
            detectedLatitude: 37.7765,
            detectedLongitude: -122.4241,
            detectedLocationName: "Bookstore",
            detectedAddress: "10 Market St"
        )
        container.mainContext.insert(visit)
        try container.mainContext.save()

        viewModel.confirmVisit(visit)
        XCTAssertEqual(visit.confirmationStatus, .confirmed)
        XCTAssertEqual(visit.confirmedAt, fixedNow)

        try viewModel.correctVisit(visit, with: VisitPlaceUpdate(
            latitude: 37.7768,
            longitude: -122.4244,
            locationName: "Civic Cafe",
            address: "12 Market St",
            placeSource: .appleMaps,
            placeCategoryRaw: "restaurant",
            placeDistanceMeters: 42,
            placeConfidence: 0.92
        ))

        XCTAssertEqual(visit.confirmationStatus, .corrected)
        XCTAssertEqual(try XCTUnwrap(visit.originalLatitude), 37.7765, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(visit.originalLongitude), -122.4241, accuracy: 0.000001)
        XCTAssertEqual(visit.originalLocationName, "Bookstore")
        XCTAssertEqual(visit.locationName, "Civic Cafe")
        XCTAssertEqual(visit.placeSource, .appleMaps)
        XCTAssertTrue(visit.geocodingCompleted)

        try viewModel.undoVisitCorrection(visit)
        XCTAssertEqual(visit.confirmationStatus, .unconfirmed)
        XCTAssertEqual(visit.latitude, 37.7765, accuracy: 0.000001)
        XCTAssertEqual(visit.longitude, -122.4241, accuracy: 0.000001)
        XCTAssertEqual(visit.locationName, "Bookstore")
        XCTAssertNil(visit.originalLatitude)
        XCTAssertNil(visit.placeDistanceMeters)
    }

    func testManualVisitValidationDuplicateDetectionAndCheckout() throws {
        let container = try makeInMemoryContainer()
        let viewModel = makeViewModel(container: container)

        let first = try viewModel.createManualVisit(from: ManualVisitDraft(
            latitude: 37.0,
            longitude: -122.0,
            arrivedAt: fixedNow,
            departedAt: fixedNow.addingTimeInterval(3600),
            locationName: "Lunch"
        ))

        XCTAssertEqual(first.source, .manual)
        XCTAssertEqual(first.confirmationStatus, .confirmed)

        XCTAssertThrowsError(try viewModel.createManualVisit(from: ManualVisitDraft(
            latitude: 37.1,
            longitude: -122.1,
            arrivedAt: fixedNow.addingTimeInterval(1800),
            departedAt: fixedNow.addingTimeInterval(7200),
            locationName: "Overlap"
        ))) { error in
            XCTAssertEqual(error as? VisitMutationError, .overlappingManualVisit)
        }

        XCTAssertThrowsError(try viewModel.updateVisitTimes(
            first,
            arrivedAt: fixedNow,
            departedAt: fixedNow.addingTimeInterval(-60)
        )) { error in
            XCTAssertEqual(error as? VisitMutationError, .invalidTimeRange)
        }

        let open = try viewModel.createManualVisit(from: ManualVisitDraft(
            latitude: 38.0,
            longitude: -123.0,
            arrivedAt: fixedNow.addingTimeInterval(7200),
            departedAt: nil,
            locationName: "Open Visit"
        ))
        try viewModel.checkoutVisit(open, at: fixedNow.addingTimeInterval(9000))
        XCTAssertEqual(open.departedAt, fixedNow.addingTimeInterval(9000))
    }

    func testCorrectedOpenVisitStillReceivesAutomaticDepartureUpdate() throws {
        let container = try makeInMemoryContainer()
        let manager = LocationManager()
        manager.setModelContext(container.mainContext)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7765, longitude: -122.4241)

        manager.recordAutomaticVisit(
            arrivalDate: fixedNow,
            departureDate: Date.distantFuture,
            coordinate: coordinate
        )

        let visits = try container.mainContext.fetch(FetchDescriptor<Visit>())
        let visit = try XCTUnwrap(visits.first)
        visit.latitude = 37.7800
        visit.longitude = -122.4300
        visit.confirmationStatus = .corrected
        try container.mainContext.save()

        let departedAt = fixedNow.addingTimeInterval(3600)
        manager.recordAutomaticVisit(
            arrivalDate: Date.distantPast,
            departureDate: departedAt,
            coordinate: coordinate
        )

        XCTAssertEqual(visit.departedAt, departedAt)
    }

    func testPlaceCandidateRankingPrefersQueryAndDistance() {
        let origin = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let candidates = [
            PlaceCandidate(
                name: "Generic Shop",
                latitude: 37.0001,
                longitude: -122.0001,
                categoryRaw: "retail"
            ),
            PlaceCandidate(
                name: "Civic Cafe",
                latitude: 37.0020,
                longitude: -122.0020,
                categoryRaw: "restaurant"
            )
        ]

        let ranked = PlaceCandidate.ranked(candidates, around: origin, query: "cafe")
        XCTAssertEqual(ranked.first?.name, "Civic Cafe")
        XCTAssertGreaterThan(ranked.first?.confidence ?? 0, ranked.last?.confidence ?? 0)
    }

    func testPlaceSearchReceivesNetworkPrivacyGate() async throws {
        let container = try makeInMemoryContainer()
        let fakeSearch = FakePlaceSearchService()
        let viewModel = makeViewModel(container: container, placeSearchService: fakeSearch)
        UserDefaults.standard.set(false, forKey: "allowNetworkGeocoding")

        let results = await viewModel.searchPlaceCandidates(
            near: CLLocationCoordinate2D(latitude: 37, longitude: -122),
            query: "cafe"
        )

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(fakeSearch.receivedAllowNetworkGeocoding, false)
    }

    func testWatchCheckOutCommandClosesOpenManualVisitAndDedupes() async throws {
        let container = try makeInMemoryContainer()
        let viewModel = makeViewModel(container: container)
        let open = try viewModel.createManualVisit(from: ManualVisitDraft(
            latitude: 37.0,
            longitude: -122.0,
            arrivedAt: fixedNow,
            departedAt: nil,
            locationName: "Watch Cafe"
        ))
        let appDelegate = AppDelegate()
        let command = WatchManualVisitCommand(
            id: UUID(uuidString: "2A0F3F0A-BC1B-4E1F-9AAE-5D67C5115C3C")!,
            action: .checkOut,
            createdAt: fixedNow
        )

        let response = await appDelegate.processWatchManualVisitCommandForTesting(
            command,
            modelContainer: container
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.commandID, command.id)
        let firstDeparture = try XCTUnwrap(open.departedAt)

        let duplicateResponse = await appDelegate.processWatchManualVisitCommandForTesting(
            command,
            modelContainer: container
        )

        XCTAssertTrue(duplicateResponse.success)
        XCTAssertEqual(open.departedAt, firstDeparture)
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

    private func makeFileBackedContainer(url: URL) throws -> ModelContainer {
        let schema = Schema([Visit.self, LocationPoint.self])
        let configuration = ModelConfiguration(
            schema: schema,
            url: url,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeViewModel(
        container: ModelContainer,
        placeSearchService: any PlaceSearching = FakePlaceSearchService()
    ) -> LocationViewModel {
        let manager = LocationManager()
        manager.isTrackingEnabled = false
        manager.trackingStartTime = nil
        return LocationViewModel(
            modelContext: container.mainContext,
            locationManager: manager,
            placeSearchService: placeSearchService,
            now: { self.fixedNow }
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}

private final class FakePlaceSearchService: PlaceSearching {
    var receivedAllowNetworkGeocoding: Bool?

    func search(
        near coordinate: CLLocationCoordinate2D,
        query: String?,
        allowNetworkGeocoding: Bool
    ) async throws -> [PlaceCandidate] {
        receivedAllowNetworkGeocoding = allowNetworkGeocoding
        guard allowNetworkGeocoding else { return [] }
        return [
            PlaceCandidate(
                name: query ?? "Candidate",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                source: .appleMaps
            )
        ]
    }
}
