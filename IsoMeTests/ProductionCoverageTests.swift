import XCTest
import Foundation
import CoreLocation
import MapKit
import UniformTypeIdentifiers
@testable import IsoMe

final class ProductionCoverageTests: XCTestCase {

    private let baseDate = Date(timeIntervalSince1970: 1_778_411_400)

    func testAllExportFormatsRenderReadableRoundTrips() throws {
        let visits = [makeVisit()]
        let points = [makePoint(offset: 120), makePoint(offset: 60)]

        for format in allFormats {
            var options = ExportOptions()
            options.dataKind = .all
            options.format = format

            let rendered = try ExportService.render(
                visits: visits,
                points: points,
                options: options,
                filenamePattern: "audit_{type}_{format}"
            )

            XCTAssertEqual(rendered.fileName, "audit_\(format.isPointsOnly ? "points" : "all")_\(format.token).\(format.fileExtension)")
            try assertExport(rendered.data, format: format)
        }
    }

    func testRenderPerDayKeepsFormatSpecificFilenamesUnique() throws {
        var options = ExportOptions()
        options.dataKind = .all
        options.format = .gpx
        options.splitByDay = true

        let dayOne = makePoint(offset: 0)
        let dayTwo = makePoint(offset: 86_400)

        let rendered = try ExportService.renderPerDay(
            visits: [],
            points: [dayTwo, dayOne],
            options: options,
            filenamePattern: "daily_{format}"
        )

        XCTAssertEqual(rendered.count, 2)
        XCTAssertEqual(Set(rendered.map(\.fileName)).count, 2)
        XCTAssertTrue(rendered.allSatisfy { $0.fileName.hasSuffix(".gpx") })
    }

    func testShortcutsFormatsMapToExpectedExportPathsAndContentTypes() {
        let cases: [(IsoMeExportFormat, ExportFormat, String, UTType)] = [
            (.json, .json, "json", .json),
            (.csv, .csv, "csv", .commaSeparatedText),
            (.markdown, .markdown, "md", UTType(filenameExtension: "md") ?? .plainText),
            (.geojson, .geojson, "geojson", UTType(filenameExtension: "geojson") ?? .json),
            (.gpx, .gpx, "gpx", UTType(filenameExtension: "gpx") ?? .xml),
            (.owntracks, .owntracks, "json", .json),
            (.overland, .overland, "json", .json),
        ]

        for (intentFormat, exportFormat, fileExtension, contentType) in cases {
            XCTAssertEqual(intentFormat.format.token, exportFormat.token)
            XCTAssertEqual(intentFormat.format.fileExtension, fileExtension)
            XCTAssertEqual(intentFormat.contentType, contentType)
        }
    }

    @MainActor
    func testDailyExportScheduleMathPreventsDuplicateSameDayRuns() {
        let scheduler = DailyExportScheduler.shared
        scheduler.hour = 9
        scheduler.minute = 30

        let scheduled = fixedDate(year: 2026, month: 5, day: 10, hour: 9, minute: 30)
        let before = fixedDate(year: 2026, month: 5, day: 10, hour: 9, minute: 29)
        let after = fixedDate(year: 2026, month: 5, day: 10, hour: 9, minute: 31)
        let yesterday = fixedDate(year: 2026, month: 5, day: 9, hour: 21, minute: 0)

        XCTAssertEqual(scheduler.nextScheduledTime(after: before), scheduled)
        XCTAssertEqual(scheduler.nextScheduledTime(after: after), fixedDate(year: 2026, month: 5, day: 11, hour: 9, minute: 30))
        XCTAssertFalse(scheduler.isDueForTesting(at: before, lastRun: nil))
        XCTAssertTrue(scheduler.isDueForTesting(at: after, lastRun: yesterday))
        XCTAssertFalse(scheduler.isDueForTesting(at: after, lastRun: scheduled))
    }

    @MainActor
    func testDriveModeDoesNotAutoStartFromDistanceHistory() {
        UserDefaults.standard.removeObject(forKey: "isTrackingEnabled")
        let manager = LocationManager()

        XCTAssertFalse(manager.isTrackingEnabled)
        XCTAssertNil(manager.trackingStartTime)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "isTrackingEnabled"), false)
    }

    func testMapRegionAndAccessibilityContracts() {
        let region = MKCoordinateRegion(coordinates: [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712),
        ])

        XCTAssertEqual(region.center.latitude, 37.78965, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, -122.3453, accuracy: 0.0001)
        XCTAssertGreaterThan(region.span.latitudeDelta, 0)
        XCTAssertGreaterThan(region.span.longitudeDelta, 0)
        XCTAssertEqual(LocationMapView.mapAccessibilityLabel, "Location history map")
    }

    private var allFormats: [ExportFormat] {
        [.json, .csv, .markdown, .geojson, .gpx, .owntracks, .overland]
    }

    private func assertExport(_ data: Data, format: ExportFormat, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertFalse(data.isEmpty, file: file, line: line)
        let string = String(data: data, encoding: .utf8) ?? ""

        switch format {
        case .json:
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], file: file, line: line)
            XCTAssertEqual(object["totalVisits"] as? Int, 1, file: file, line: line)
            XCTAssertEqual(object["totalPoints"] as? Int, 2, file: file, line: line)
        case .csv:
            XCTAssertTrue(string.contains("# VISITS (1)"), file: file, line: line)
            XCTAssertTrue(string.contains("# LOCATION POINTS (2)"), file: file, line: line)
            XCTAssertTrue(string.contains("Test Cafe"), file: file, line: line)
        case .markdown:
            XCTAssertTrue(string.contains("# iso.me Complete Export"), file: file, line: line)
            XCTAssertTrue(string.contains("Test Cafe"), file: file, line: line)
        case .geojson:
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], file: file, line: line)
            XCTAssertEqual(object["type"] as? String, "FeatureCollection", file: file, line: line)
            let features = try XCTUnwrap(object["features"] as? [[String: Any]], file: file, line: line)
            XCTAssertEqual(features.count, 3, file: file, line: line)
        case .gpx:
            XCTAssertTrue(string.contains("<gpx version=\"1.1\""), file: file, line: line)
            XCTAssertTrue(string.contains("<wpt lat=\"37.7749000\" lon=\"-122.4194000\">"), file: file, line: line)
            XCTAssertTrue(string.contains("<trkpt"), file: file, line: line)
        case .owntracks:
            let messages = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]], file: file, line: line)
            XCTAssertEqual(messages.count, 2, file: file, line: line)
            XCTAssertEqual(messages.first?["_type"] as? String, "location", file: file, line: line)
            XCTAssertEqual(messages.first?["tid"] as? String, "IM", file: file, line: line)
        case .overland:
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], file: file, line: line)
            let locations = try XCTUnwrap(object["locations"] as? [[String: Any]], file: file, line: line)
            XCTAssertEqual(locations.count, 2, file: file, line: line)
            XCTAssertNotNil(object["current"], file: file, line: line)
        }
    }

    private func makeVisit() -> Visit {
        Visit(
            latitude: 37.7749,
            longitude: -122.4194,
            arrivedAt: baseDate,
            departedAt: baseDate.addingTimeInterval(3_600),
            locationName: "Test Cafe",
            address: "1 Market St",
            notes: "audit note",
            geocodingCompleted: true
        )
    }

    private func makePoint(offset: TimeInterval) -> LocationPoint {
        LocationPoint(
            latitude: 37.7749 + offset / 1_000_000,
            longitude: -122.4194 - offset / 1_000_000,
            timestamp: baseDate.addingTimeInterval(offset),
            altitude: 12.5,
            speed: 2.4,
            horizontalAccuracy: 4.2,
            isOutlier: false
        )
    }

    private func fixedDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
