
// Documentation evidence only; appended to the isolated release-source test copy.
extension SavedPlaceManagementTests {
    func testDocumentationBackupFilesPersistOnDiskAfterReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("isome-backup-evidence-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let visitsURL = directory.appendingPathComponent("synthetic-visits.json")
        let pointsURL = directory.appendingPathComponent("synthetic-points.json")
        try Data(Self.backupVisitJSON.utf8).write(to: visitsURL)
        try Data(Self.backupPointJSON.utf8).write(to: pointsURL)
        let storeURL = directory.appendingPathComponent("journal.store")
        let oldGeocoding = UserDefaults.standard.object(forKey: "allowNetworkGeocoding")
        UserDefaults.standard.set(false, forKey: "allowNetworkGeocoding")
        defer {
            if let oldGeocoding { UserDefaults.standard.set(oldGeocoding, forKey: "allowNetworkGeocoding") }
            else { UserDefaults.standard.removeObject(forKey: "allowNetworkGeocoding") }
        }
        try autoreleasepool {
            let container = try Self.backupContainer(at: storeURL)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Visit>()), 0)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<LocationPoint>()), 0)
            let manager = LocationManager()
            manager.isTrackingEnabled = false
            manager.trackingStartTime = nil
            let model = LocationViewModel(modelContext: container.mainContext, locationManager: manager)
            let visits = try model.importData(from: visitsURL)
            XCTAssertEqual(visits.visitCount, 2)
            XCTAssertEqual(visits.pointCount, 0)
            let points = try model.importData(from: pointsURL)
            XCTAssertEqual(points.pointCount, 3)
            XCTAssertEqual(points.visitCount, 0)
            try container.mainContext.save()
        }
        try autoreleasepool {
            let reopened = try Self.backupContainer(at: storeURL)
            let visits = try reopened.mainContext.fetch(FetchDescriptor<Visit>(sortBy: [SortDescriptor(\.arrivedAt)]))
            let points = try reopened.mainContext.fetch(FetchDescriptor<LocationPoint>(sortBy: [SortDescriptor(\.timestamp)]))
            XCTAssertEqual(visits.count, 1)
            XCTAssertEqual(points.count, 3)
            let firstVisit = try XCTUnwrap(visits.first)
            let lastVisit = try XCTUnwrap(visits.last)
            XCTAssertEqual(firstVisit.locationName, "Synthetic stop A")
            XCTAssertEqual(lastVisit.locationName, "Synthetic stop A")
            XCTAssertEqual(firstVisit.arrivedAt.timeIntervalSince1970, 946727100)
            XCTAssertEqual(firstVisit.departedAt?.timeIntervalSince1970, 946729020)
            XCTAssertEqual(firstVisit.notes, "Invented documentation example; not a real visit.")
            XCTAssertEqual(lastVisit.latitude, 0)
            XCTAssertEqual(lastVisit.longitude, 0)
            let lastPoint = try XCTUnwrap(points.last)
            XCTAssertEqual(lastPoint.timestamp.timeIntervalSince1970, 946728120)
            XCTAssertEqual(lastPoint.latitude, 0.0002)
            XCTAssertEqual(lastPoint.horizontalAccuracy, 5)
            XCTAssertFalse(lastPoint.isOutlier)
            var options = ExportOptions()
            options.dataKind = .visits
            options.format = .json
            let exportedVisits = try ExportService.render(visits: visits, points: points, options: options)
            let parsedVisits = try ImportService.importFile(data: exportedVisits.data, format: .json)
            XCTAssertEqual(parsedVisits.visits.count, 1)
            XCTAssertEqual(parsedVisits.visits.first?.locationName, "Synthetic stop A")
            options.dataKind = .points
            let exportedPoints = try ExportService.render(visits: visits, points: points, options: options)
            let parsedPoints = try ImportService.importFile(data: exportedPoints.data, format: .json)
            XCTAssertEqual(parsedPoints.points.count, 3)
            let manager = LocationManager()
            manager.isTrackingEnabled = false
            manager.trackingStartTime = nil
            let model = LocationViewModel(modelContext: reopened.mainContext, locationManager: manager)
            let repeatedVisits = try model.importData(from: visitsURL)
            let repeatedPoints = try model.importData(from: pointsURL)
            XCTAssertEqual(repeatedVisits.visitCount, 2)
            XCTAssertEqual(repeatedPoints.pointCount, 3)
            try reopened.mainContext.save()
        }
        try autoreleasepool {
            let repeated = try Self.backupContainer(at: storeURL)
            XCTAssertEqual(try repeated.mainContext.fetchCount(FetchDescriptor<Visit>()), 1)
            XCTAssertEqual(try repeated.mainContext.fetchCount(FetchDescriptor<LocationPoint>()), 6)
        }
    }

    private static func backupContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema([Visit.self, LocationPoint.self, RecordingSession.self, PhotoMoment.self, SavedPlace.self, CountryStay.self])
        let configuration = ModelConfiguration(schema: schema, url: url, allowsSave: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    private static let backupVisitJSON = #"""
{
  "exportDate": "2000-01-02T00:00:00Z",
  "visits": [
    {
      "latitude": 0.0,
      "longitude": 0.0,
      "arrivedAt": "2000-01-01T11:45:00Z",
      "departedAt": "2000-01-01T12:00:00Z",
      "durationMinutes": 15.0,
      "locationName": "Synthetic stop A",
      "notes": "Invented documentation example; not a real visit."
    },
    {
      "latitude": 0.0002,
      "longitude": 0.0001,
      "arrivedAt": "2000-01-01T12:02:00Z",
      "departedAt": "2000-01-01T12:17:00Z",
      "durationMinutes": 15.0,
      "locationName": "Synthetic stop B",
      "notes": "Invented documentation example; not a real visit."
    }
  ]
}
"""#
    private static let backupPointJSON = #"""
{
  "exportDate": "2000-01-02T00:00:00Z",
  "totalPoints": 3,
  "dateRange": {
    "earliest": "2000-01-01T12:00:00Z",
    "latest": "2000-01-01T12:02:00Z",
    "durationSeconds": 120.0
  },
  "points": [
    {
      "latitude": 0.0,
      "longitude": 0.0,
      "timestamp": "2000-01-01T12:00:00Z",
      "timestampUnix": 946728000.0,
      "horizontalAccuracy": 5.0,
      "isOutlier": false
    },
    {
      "latitude": 0.0001,
      "longitude": 0.0001,
      "timestamp": "2000-01-01T12:01:00Z",
      "timestampUnix": 946728060.0,
      "horizontalAccuracy": 5.0,
      "isOutlier": false
    },
    {
      "latitude": 0.0002,
      "longitude": 0.0001,
      "timestamp": "2000-01-01T12:02:00Z",
      "timestampUnix": 946728120.0,
      "horizontalAccuracy": 5.0,
      "isOutlier": false
    }
  ]
}
"""#
}
