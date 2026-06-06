import XCTest
@testable import IsoMe

final class SharedLocationDataTests: XCTestCase {

    // MARK: - Backward-compatible decoding

    /// Data encoded BEFORE the usesMetricDistanceUnits field was added must
    /// still decode successfully.  A failure here means existing users will
    /// crash on launch because SharedLocationData.load() feeds a JSONDecoder.
    func testDecodesLegacyPayloadWithoutMetricField() throws {
        // Simulate the JSON that was persisted before the new field existed.
        let legacyJSON = """
        {
            "isTrackingEnabled": true,
            "todayVisitsCount": 3,
            "todayDistanceMeters": 1200.0,
            "todayPointsCount": 10
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: legacyJSON)

        XCTAssertTrue(decoded.isTrackingEnabled)
        XCTAssertNil(decoded.usesMetricDistanceUnits,
                     "Missing key should decode as nil, not crash")
        XCTAssertNil(decoded.currentVisitSourceRaw)
        XCTAssertFalse(decoded.isManualCheckInOpen)
    }

    /// Data encoded with the OLD continuous-tracking fields must still decode.
    /// Extra unknown keys should be silently ignored.
    func testDecodesPayloadWithRemovedContinuousFields() throws {
        let legacyJSON = """
        {
            "isTrackingEnabled": true,
            "isContinuousTrackingEnabled": true,
            "todayVisitsCount": 3,
            "todayDistanceMeters": 1200.0,
            "todayPointsCount": 10,
            "continuousTrackingStartTime": -1000,
            "continuousTrackingAutoOffHours": 2.0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: legacyJSON)
        XCTAssertTrue(decoded.isTrackingEnabled)
        XCTAssertEqual(decoded.todayVisitsCount, 3)
    }

    /// Round-trip: encode and decode the new struct.
    func testRoundTrip() throws {
        let original = SharedLocationData(
            isTrackingEnabled: true,
            currentLocationName: "Coffee Shop",
            currentAddress: "123 Main St",
            lastLatitude: 37.7749,
            lastLongitude: -122.4194,
            lastUpdateTime: Date(),
            todayVisitsCount: 5,
            todayDistanceMeters: 3200,
            todayPointsCount: 42,
            trackingStartTime: Date(),
            stopAfterHours: 2.0,
            usesMetricDistanceUnits: false,
            currentVisitID: UUID(uuidString: "6B6AD473-7F13-4A6F-BA74-E81821BE7296"),
            currentVisitName: "Coffee Shop",
            currentVisitSourceRaw: "manual",
            currentVisitConfirmationStatusRaw: "confirmed",
            currentVisitArrivedAt: Date(),
            hasOpenManualVisit: true,
            openManualVisitID: UUID(uuidString: "6B6AD473-7F13-4A6F-BA74-E81821BE7296"),
            openManualVisitName: "Coffee Shop",
            openManualVisitArrivedAt: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: data)

        XCTAssertEqual(decoded.usesMetricDistanceUnits, false)
        XCTAssertEqual(decoded.todayVisitsCount, 5)
        XCTAssertEqual(decoded.stopAfterHours, 2.0)
        XCTAssertEqual(decoded.currentVisitSourceRaw, "manual")
        XCTAssertEqual(decoded.currentVisitConfirmationStatusRaw, "confirmed")
        XCTAssertTrue(decoded.isManualCheckInOpen)
        XCTAssertEqual(decoded.openManualVisitDisplayName, "Coffee Shop")
    }

    func testSharedLocationDataPropertyListPayloadRoundTrips() throws {
        let original = SharedLocationData(
            isTrackingEnabled: false,
            currentLocationName: "Park",
            currentAddress: nil,
            lastLatitude: 37.0,
            lastLongitude: -122.0,
            lastUpdateTime: Date(),
            todayVisitsCount: 2,
            todayDistanceMeters: 100,
            todayPointsCount: 4,
            trackingStartTime: nil,
            stopAfterHours: nil,
            usesMetricDistanceUnits: true,
            hasOpenManualVisit: true,
            openManualVisitName: "Park"
        )

        let decoded = try XCTUnwrap(SharedLocationData.decode(from: original.propertyListPayload))

        XCTAssertEqual(decoded.todayVisitsCount, 2)
        XCTAssertTrue(decoded.isManualCheckInOpen)
        XCTAssertEqual(decoded.openManualVisitDisplayName, "Park")
    }

    func testWatchManualVisitCommandPayloadRoundTrips() throws {
        let command = WatchManualVisitCommand(
            id: UUID(uuidString: "C237DD67-E4E7-4625-B7A8-41D67C510B1B")!,
            action: .checkIn,
            createdAt: Date(),
            placeName: "Cafe"
        )

        let decoded = try XCTUnwrap(WatchManualVisitCommand.decode(from: command.propertyListPayload))

        XCTAssertEqual(decoded.id, command.id)
        XCTAssertEqual(decoded.action, .checkIn)
        XCTAssertEqual(decoded.placeName, "Cafe")
    }

    func testWatchManualVisitCommandResponsePayloadRoundTrips() throws {
        let response = WatchManualVisitCommandResponse(
            commandID: UUID(uuidString: "A8CB1B35-46AF-474D-B5D7-2155C94E9B2B")!,
            success: true,
            message: "Checked in."
        )

        let decoded = try XCTUnwrap(WatchManualVisitCommandResponse.decode(from: response.propertyListPayload))

        XCTAssertEqual(decoded, response)
    }

    // MARK: - Tracking status (2-state)

    func testTrackingStatusOn() {
        var d = SharedLocationData.empty
        d.isTrackingEnabled = true
        XCTAssertEqual(d.trackingStatus, "Tracking")
    }

    func testTrackingStatusOff() {
        let d = SharedLocationData.empty
        XCTAssertEqual(d.trackingStatus, "Off")
    }

    // MARK: - Formatted distance (metric vs US standard)

    func testFormattedDistanceMetricShortDistance() {
        var d = SharedLocationData.empty
        d.usesMetricDistanceUnits = true
        d.todayDistanceMeters = 500
        XCTAssertEqual(d.formattedDistance, "500 m")
    }

    func testFormattedDistanceMetricLongDistance() {
        var d = SharedLocationData.empty
        d.usesMetricDistanceUnits = true
        d.todayDistanceMeters = 2500
        XCTAssertEqual(d.formattedDistance, "2.5 km")
    }

    func testFormattedDistanceImperialShortDistance() {
        var d = SharedLocationData.empty
        d.usesMetricDistanceUnits = false
        d.todayDistanceMeters = 30 // ~98 ft
        // 30 * 3.28084 ≈ 98 ft, miles = 30/1609.344 ≈ 0.019 < 0.1
        XCTAssertEqual(d.formattedDistance, "98 ft")
    }

    func testFormattedDistanceImperialLongDistance() {
        var d = SharedLocationData.empty
        d.usesMetricDistanceUnits = false
        d.todayDistanceMeters = 5000 // ~3.1 mi
        XCTAssertEqual(d.formattedDistance, "3.1 mi")
    }

    func testFormattedDistanceDefaultsToMetricWhenNil() {
        var d = SharedLocationData.empty
        d.usesMetricDistanceUnits = nil
        d.todayDistanceMeters = 500
        XCTAssertEqual(d.formattedDistance, "500 m",
                       "nil should fall back to metric")
    }
}
