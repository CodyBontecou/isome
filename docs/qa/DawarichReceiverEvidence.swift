
extension ExportRoundTripTests {
    @MainActor
    func testSEODawarichReceiver() async throws {
        let suite = "SEO.Dawarich." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let manager = WebhookManager(defaults: defaults, urlSession: URLSession(configuration: .ephemeral))
        let oldKey = manager.authKey
        let oldValue = manager.authValue
        defer {
            manager.authKey = oldKey
            manager.authValue = oldValue
            defaults.removePersistentDomain(forName: suite)
        }
        manager.urlString = "http://127.0.0.1:38147/api/v1/overland/batches"
        manager.authType = .apiKeyQuery
        manager.authKey = "api_key"
        manager.authValue = "__LOCAL_API_KEY__"
        manager.format = .overland
        let connected = try await manager.testConnection()
        XCTAssertTrue(connected.contains("201"))
        print("SEO_DAWARICH_TEST_CONNECTION_HTTP_201")
        manager.authValue = "invalid-synthetic-test-key"
        do {
            _ = try await manager.testConnection()
            XCTFail("Expected unauthorized")
        } catch WebhookError.unauthorized {
            print("SEO_DAWARICH_INVALID_KEY_HTTP_401")
        }
        manager.authValue = "__LOCAL_API_KEY__"
        let base = Date(timeIntervalSince1970: 946728000)
        let points = (0..<3).map { index in
            LocationPoint(latitude: 1 + Double(index) * 0.0001,
                          longitude: 2 + Double(index) * 0.0001,
                          timestamp: base.addingTimeInterval(Double(index) * 60),
                          altitude: Double(index), speed: 1, horizontalAccuracy: 5)
        }
        let data = try ExportService.exportLocationPointsToOverland(points: points)
        print("SEO_OVERLAND_EXPORT_BEGIN" + data.base64EncodedString() + "SEO_OVERLAND_EXPORT_END")
        for point in points { manager.enqueuePendingPoint(point) }
        await manager.flushBatch()
        XCTAssertEqual(manager.queuedPointCount, 0)
        XCTAssertNotNil(manager.lastSentAt)
        XCTAssertNil(manager.lastError)
        print("SEO_DAWARICH_NATIVE_BATCH_ACCEPTED")
    }
}
