// Documentation evidence only; append to the isolated release-source
// CountryDayTests.swift. No production code changes or geocoding calls.
extension CountryDayTests {
    func testDocumentationCountryDayCSVExample() throws {
        func syntheticPoint(_ code: String?, _ time: String, zone: String?, outlier: Bool = false) -> LocationPoint {
            let point = LocationPoint(latitude: 0, longitude: 0, timestamp: instant(time), horizontalAccuracy: 5, isOutlier: outlier)
            point.countryCode = code
            point.countryTimeZoneIdentifier = zone
            return point
        }
        let points = [
            syntheticPoint("PT", "2026-10-01T08:00:00Z", zone: "Europe/Lisbon"),
            syntheticPoint("PT", "2026-10-01T08:05:00Z", zone: "Europe/Lisbon"),
            syntheticPoint("ES", "2026-10-01T18:00:00Z", zone: "Europe/Madrid"),
            syntheticPoint("FR", "2026-10-02T22:30:00Z", zone: "Europe/Paris"),
            syntheticPoint("FR", "2026-10-04T12:00:00Z", zone: "Europe/Paris", outlier: true),
            syntheticPoint(nil, "2026-10-05T12:00:00Z", zone: nil)
        ]
        let summaries = CountryDayCalculator.summaries(visits: [], points: points,
            stays: [CountryStay(countryCode: "PT", firstDay: "2026-10-01", lastDay: "2026-10-02")], now: now)
        XCTAssertEqual(summaries.count, 3)
        XCTAssertEqual(summaries.flatMap(\.days).count, 4)
        XCTAssertEqual(Set(summaries.flatMap(\.days).map(\.day)), ["2026-10-01", "2026-10-02", "2026-10-03"])
        let portugal = try XCTUnwrap(summaries.first { $0.countryCode == "PT" })
        XCTAssertEqual(portugal.days.count, 2)
        XCTAssertEqual(portugal.days.first { $0.day == "2026-10-01" }, CountryPresence(countryCode: "PT", day: "2026-10-01", recorded: true, manual: true))
        let expected = "country_code,local_date,source\r\nES,2026-10-01,recorded\r\nFR,2026-10-03,recorded\r\nPT,2026-10-01,recorded+manual\r\nPT,2026-10-02,manual\r\n"
        let csv = CountryDayCalculator.csv(summaries)
        XCTAssertEqual(csv, expected)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(csv.utf8).write(to: url)
        XCTAssertEqual(try Data(contentsOf: url), Data(expected.utf8))
        print("COUNTRY_DAYS_SAMPLE_BASE64=" + Data(csv.utf8).base64EncodedString())
    }
}
