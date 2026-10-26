// Documentation evidence only; append to the isolated release-source
// WatchLocationSyncTests.swift. Real WatchConnectivity transport is disabled.
#if canImport(IsoMe)
extension WatchLocationSyncImportTests {
    func testDocumentationQueueAndPhoneDiskStoresSurviveLostAck() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queueURL = directory.appendingPathComponent("state.json")
        let storeURL = directory.appendingPathComponent("phone.store")
        let wireURL = directory.appendingPathComponent("first-payload.json")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var queue = try decoder.decode(WatchLocationSyncState.self, from: snapshotData())
        let expectedIDs = Set(queue.points.map(\.id))
        let expectedTimes = queue.points.map(\.timestamp).sorted()
        XCTAssertEqual(queue.points.count, 503)
        let first = try XCTUnwrap(queue.makePayload())
        XCTAssertEqual(first.points.count, 500)
        queue.registerTransfer(first)
        try encoder.encode(queue).write(to: queueURL, options: .atomic)
        try encoder.encode(first).write(to: wireURL, options: .atomic)
        try autoreleasepool {
            let container = try Self.documentationDiskContainer(at: storeURL)
            let receiver = WatchLocationSyncReceiver()
            receiver.configure(modelContainer: container, activatesConnectivity: false)
            let ack = try XCTUnwrap(receiver.importPayloadData(Data(contentsOf: wireURL)))
            XCTAssertTrue(ack.succeeded)
            XCTAssertEqual(ack.importedPointCount, 500)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<LocationPoint>()), 500)
            // Deliberately do not deliver the acknowledgement to the queue.
        }
        queue = try decoder.decode(WatchLocationSyncState.self, from: Data(contentsOf: queueURL))
        XCTAssertEqual(queue.points.count, 503)
        try autoreleasepool {
            let container = try Self.documentationDiskContainer(at: storeURL)
            let receiver = WatchLocationSyncReceiver()
            receiver.configure(modelContainer: container, activatesConnectivity: false)
            let retry = try XCTUnwrap(receiver.importPayloadData(Data(contentsOf: wireURL)))
            XCTAssertTrue(retry.succeeded)
            XCTAssertEqual(retry.importedPointCount, 0)
            XCTAssertEqual(retry.importedVisitCount, 0)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<LocationPoint>()), 500)
            let transfer = try XCTUnwrap(queue.pendingTransfers.first { $0.sequence == retry.sequence })
            queue.acknowledge(transfer)
            XCTAssertEqual(queue.points.count, 3)
            XCTAssertEqual(queue.sessions.count, 1)
            XCTAssertTrue(queue.needsFollowup(after: transfer))
            try encoder.encode(queue).write(to: queueURL, options: .atomic)
            queue = try decoder.decode(WatchLocationSyncState.self, from: Data(contentsOf: queueURL))
            let last = try XCTUnwrap(queue.makePayload())
            XCTAssertEqual(last.points.count, 3)
            queue.registerTransfer(last)
            let finalAck = try XCTUnwrap(receiver.importPayloadData(encoder.encode(last)))
            XCTAssertTrue(finalAck.succeeded)
            XCTAssertEqual(finalAck.importedPointCount, 3)
            queue.acknowledge(try XCTUnwrap(queue.pendingTransfers.first { $0.sequence == finalAck.sequence }))
            try encoder.encode(queue).write(to: queueURL, options: .atomic)
        }
        queue = try decoder.decode(WatchLocationSyncState.self, from: Data(contentsOf: queueURL))
        XCTAssertTrue(queue.points.isEmpty)
        XCTAssertTrue(queue.visits.isEmpty)
        XCTAssertTrue(queue.sessions.isEmpty)
        XCTAssertNil(queue.makePayload())
        try autoreleasepool {
            let container = try Self.documentationDiskContainer(at: storeURL)
            let points = try container.mainContext.fetch(FetchDescriptor<LocationPoint>(sortBy: [SortDescriptor(\.timestamp)]))
            XCTAssertEqual(points.count, 503)
            XCTAssertEqual(Set(points.map(\.id)), expectedIDs)
            XCTAssertEqual(points.map(\.timestamp), expectedTimes)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Visit>()), 2)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<RecordingSession>()), 1)
            let receiver = WatchLocationSyncReceiver()
            receiver.configure(modelContainer: container, activatesConnectivity: false)
            let delayed = try XCTUnwrap(receiver.importPayloadData(Data(contentsOf: wireURL)))
            XCTAssertTrue(delayed.succeeded)
            XCTAssertEqual(delayed.importedPointCount, 0)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<LocationPoint>()), 503)
        }
    }

    private static func documentationDiskContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema([Visit.self, LocationPoint.self, RecordingSession.self, PhotoMoment.self, SavedPlace.self, CountryStay.self])
        let configuration = ModelConfiguration(schema: schema, url: url, allowsSave: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
#endif
