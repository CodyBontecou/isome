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
            usesMetricDistanceUnits: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: data)

        XCTAssertEqual(decoded.usesMetricDistanceUnits, false)
        XCTAssertEqual(decoded.todayVisitsCount, 5)
        XCTAssertEqual(decoded.stopAfterHours, 2.0)
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
