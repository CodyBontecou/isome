import XCTest
@testable import Spotted

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
            "isContinuousTrackingEnabled": false,
            "todayVisitsCount": 3,
            "todayDistanceMeters": 1200.0,
            "todayPointsCount": 10
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: legacyJSON)

        XCTAssertTrue(decoded.isTrackingEnabled)
        XCTAssertFalse(decoded.isContinuousTrackingEnabled)
        XCTAssertNil(decoded.usesMetricDistanceUnits,
                     "Missing key should decode as nil, not crash")
    }

    /// Round-trip: encode with the new field, then decode.
    func testRoundTripWithMetricField() throws {
        let original = SharedLocationData(
            isTrackingEnabled: true,
            isContinuousTrackingEnabled: true,
            currentLocationName: "Coffee Shop",
            currentAddress: "123 Main St",
            lastLatitude: 37.7749,
            lastLongitude: -122.4194,
            lastUpdateTime: Date(),
            todayVisitsCount: 5,
            todayDistanceMeters: 3200,
            todayPointsCount: 42,
            continuousTrackingStartTime: Date(),
            continuousTrackingAutoOffHours: 2.0,
            usesMetricDistanceUnits: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedLocationData.self, from: data)

        XCTAssertEqual(decoded.usesMetricDistanceUnits, false)
        XCTAssertEqual(decoded.todayVisitsCount, 5)
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
