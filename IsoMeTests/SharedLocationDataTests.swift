import XCTest
@testable import IsoMe

final class SharedLocationDataTests: XCTestCase {

    // MARK: - Backward-compatible decoding

    /// Data encoded before the rename to tracking terminology must still decode.
    func testDecodesLegacyPayloadWithoutMetricField() throws {
        let legacyJSON = """
        {
            "isContinuousTrackingEnabled": false,
            "todayVisitsCount": 3,
            "todayDistanceMeters": 1200.0,
            "todayPointsCount": 10,
            "continuousTrackingStartTime": null,
            "continuousTrackingAutoOffHours": 2.0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: legacyJSON)

        XCTAssertFalse(decoded.isTrackingEnabled)
        XCTAssertNil(decoded.usesMetricDistanceUnits,
                     "Missing key should decode as nil, not crash")
        XCTAssertEqual(decoded.todayVisitsCount, 3)
    }

    func testTrackingKeyTakesPrecedenceOverLegacyKey() throws {
        let mixedJSON = """
        {
            "isTrackingEnabled": true,
            "isContinuousTrackingEnabled": false,
            "todayVisitsCount": 1,
            "todayDistanceMeters": 10.0,
            "todayPointsCount": 1
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: mixedJSON)
        XCTAssertTrue(decoded.isTrackingEnabled)
    }

    /// Round-trip: encode with the current fields, then decode.
    func testRoundTripWithMetricField() throws {
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
            trackingAutoOffHours: 2.0,
            usesMetricDistanceUnits: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: data)

        XCTAssertEqual(decoded.usesMetricDistanceUnits, false)
        XCTAssertEqual(decoded.todayVisitsCount, 5)

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["isTrackingEnabled"] as? Bool, true)
        XCTAssertEqual(json["isContinuousTrackingEnabled"] as? Bool, true,
                       "Encoder should continue emitting legacy key for compatibility")
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
