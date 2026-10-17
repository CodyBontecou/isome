import XCTest
import SwiftData
@testable import IsoMe

final class ExportDataIntentTests: XCTestCase {
    // MARK: - Parameter resolution

    private static let base = Date(timeIntervalSince1970: 1_778_414_400) // 2026-05-10T12:00:00Z

    func testDefaultDateParametersResolveToStartOfTodayThroughNow() throws {
        let now = Self.base
        let range = try ExportDataParameterResolution.dateRange(start: nil, end: nil, now: now)

        XCTAssertEqual(range.lowerBound, Calendar.current.startOfDay(for: now))
        XCTAssertEqual(range.upperBound, now)
    }

    func testExplicitDateParametersPassThroughUnchanged() throws {
        let start = Self.base.addingTimeInterval(-3_600)
        let end = Self.base.addingTimeInterval(3_600)

        let range = try ExportDataParameterResolution.dateRange(start: start, end: end, now: Self.base)

        XCTAssertEqual(range.lowerBound, start)
        XCTAssertEqual(range.upperBound, end)
    }

    func testSingleMissingParameterPairsWithItsDefault() throws {
        let now = Self.base

        // Start provided, end defaulted to now.
        let startOnly = try ExportDataParameterResolution.dateRange(
            start: now.addingTimeInterval(-3_600), end: nil, now: now
        )
        XCTAssertEqual(startOnly.lowerBound, now.addingTimeInterval(-3_600))
        XCTAssertEqual(startOnly.upperBound, now)

        // End provided, start defaulted to start of today.
        let endOnly = try ExportDataParameterResolution.dateRange(
            start: nil, end: now, now: now
        )
        XCTAssertEqual(endOnly.lowerBound, Calendar.current.startOfDay(for: now))
        XCTAssertEqual(endOnly.upperBound, now)
    }

    func testInvertedExplicitDatesThrowInvalidDateRange() {
        let later = Self.base
        let earlier = Self.base.addingTimeInterval(-86_400)

        XCTAssertThrowsError(
            try ExportDataParameterResolution.dateRange(start: later, end: earlier, now: Self.base)
        ) { error in
            guard case IsoMeIntentError.invalidDateRange = error else {
                return XCTFail("Expected invalidDateRange, got \(error)")
            }
        }
    }

    func testFutureStartDateWithoutEndDateThrowsInsteadOfFormingInvalidRange() {
        XCTAssertThrowsError(
            try ExportDataParameterResolution.dateRange(
                start: Self.base.addingTimeInterval(86_400), end: nil, now: Self.base
            )
        ) { error in
            guard case IsoMeIntentError.invalidDateRange = error else {
                return XCTFail("Expected invalidDateRange, got \(error)")
            }
        }
    }

    func testEqualStartAndEndDateFormsValidSingleInstantRange() throws {
        let instant = Self.base
        let range = try ExportDataParameterResolution.dateRange(start: instant, end: instant, now: Self.base)
        XCTAssertEqual(range.lowerBound, instant)
        XCTAssertEqual(range.upperBound, instant)
    }

    // MARK: - Data kind mapping

    func testExportDataKindMappingCoversEveryExportOptionsDataKind() {
        XCTAssertEqual(
            Set(IsoMeExportDataKind.allCases.map(\.dataKind)),
            Set(ExportOptions.DataKind.allCases)
        )
        for appKind in IsoMeExportDataKind.allCases {
            XCTAssertEqual(appKind.dataKind.rawValue, appKind.rawValue)
        }
    }

    // MARK: - Differential rendering through the context-injectable seam

    /// Fixtures straddle the export range on every axis:
    /// - a visit in-range and one far out of range,
    /// - a standalone point in-range and one far out of range,
    /// - a stored session that starts in-range but ends past the range's upper
    ///   bound, owning one in-range point and one out-of-range point.
    private static let range: ClosedRange<Date> =
        ExportDataIntentTests.base.addingTimeInterval(-3_600)...ExportDataIntentTests.base.addingTimeInterval(3_600)

    @MainActor
    private func makeSeededContext() throws -> ModelContext {
        let schema = Schema([Visit.self, LocationPoint.self, RecordingSession.self, PhotoMoment.self, SavedPlace.self, CountryStay.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let base = Self.base

        context.insert(Visit(
            latitude: 37.776502,
            longitude: -122.424098,
            arrivedAt: base,
            departedAt: base.addingTimeInterval(1_800),
            locationName: "Range Cafe",
            address: "1 Market St, San Francisco, CA"
        ))
        context.insert(Visit(
            latitude: 37.700000,
            longitude: -122.500000,
            arrivedAt: base.addingTimeInterval(-48 * 3_600),
            departedAt: base.addingTimeInterval(-47 * 3_600),
            locationName: "Old Diner",
            address: "2 Mission St, San Francisco, CA"
        ))

        context.insert(LocationPoint(
            latitude: 37.776600,
            longitude: -122.424000,
            timestamp: base.addingTimeInterval(300),
            horizontalAccuracy: 4.5
        ))
        context.insert(LocationPoint(
            latitude: 37.700000,
            longitude: -122.500000,
            timestamp: base.addingTimeInterval(-48 * 3_600),
            horizontalAccuracy: 8.0
        ))

        let session = RecordingSession(
            startedAt: base.addingTimeInterval(-300),
            endedAt: base.addingTimeInterval(7_200),
            customName: "Range Outing"
        )
        context.insert(session)
        context.insert(LocationPoint(
            latitude: 37.777000,
            longitude: -122.424100,
            timestamp: base.addingTimeInterval(-300),
            horizontalAccuracy: 5.0
        ))
        // Session point beyond the range's upper bound: fetchPoints deliberately
        // ignores the range for the outings kind so the session's track renders
        // complete — this point must appear in the outings payload.
        context.insert(LocationPoint(
            latitude: 37.778000,
            longitude: -122.424200,
            timestamp: base.addingTimeInterval(5_400),
            horizontalAccuracy: 6.0
        ))

        try context.save()
        return context
    }

    @MainActor
    private func renderFixture(
        dataKind: ExportOptions.DataKind,
        context: ModelContext
    ) throws -> (data: Data, fileName: String) {
        let file = try ExportRunner.run(range: Self.range, dataKind: dataKind, format: .json, context: context)
        return (file.data, file.filename)
    }

    @MainActor
    func testVisitsKindExportsOnlyInRangeVisits() throws {
        let context = try makeSeededContext()
        let rendered = try renderFixture(dataKind: .visits, context: context)

        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: rendered.data) as? [String: Any])
        let visits = try XCTUnwrap(object["visits"] as? [[String: Any]])
        XCTAssertEqual(visits.count, 1)
        XCTAssertEqual(try XCTUnwrap(visits.first?["locationName"] as? String), "Range Cafe")
        XCTAssertNil(object["points"], "visits-kind export must not emit a points array")
    }

    @MainActor
    func testPointsKindExportsOnlyInRangePoints() throws {
        let context = try makeSeededContext()
        let rendered = try renderFixture(dataKind: .points, context: context)

        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: rendered.data) as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(object["totalPoints"] as? Int), 2)
        let points = try XCTUnwrap(object["points"] as? [[String: Any]])
        XCTAssertEqual(points.count, 2)
        XCTAssertNil(object["visits"], "points-kind export must not emit a visits array")

        // Both rendered timestamps must fall inside the range even though the
        // fixture holds two additional points outside it.
        let timestamps = Set(points.compactMap { $0["timestampUnix"] as? Double })
        XCTAssertTrue(timestamps.contains(Self.base.addingTimeInterval(-300).timeIntervalSince1970))
        XCTAssertTrue(timestamps.contains(Self.base.addingTimeInterval(300).timeIntervalSince1970))
    }

    @MainActor
    func testOutingsKindIncludesSessionPointsOutsideTheExportRange() throws {
        let context = try makeSeededContext()
        let rendered = try renderFixture(dataKind: .outings, context: context)

        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: rendered.data) as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(object["totalOutings"] as? Int), 1)
        let outings = try XCTUnwrap(object["outings"] as? [[String: Any]])
        XCTAssertEqual(outings.count, 1)

        let outing = try XCTUnwrap(outings.first)
        XCTAssertEqual(try XCTUnwrap(outing["title"] as? String), "Range Outing")
        // The session window owns three points: two in-range plus one past the
        // range's upper bound. The out-of-range point must still be counted so
        // the rendered track is complete — this locks the range-skip semantics
        // ExportRunner relies on for session rendering.
        XCTAssertEqual(try XCTUnwrap(outing["pointCount"] as? Int), 3)
    }

    @MainActor
    func testAllKindExportsRangeFilteredVisitsAndPointsTogether() throws {
        let context = try makeSeededContext()
        let rendered = try renderFixture(dataKind: .all, context: context)

        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: rendered.data) as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(object["totalVisits"] as? Int), 1)
        XCTAssertEqual(try XCTUnwrap(object["totalPoints"] as? Int), 2)
        XCTAssertNotNil(object["visits"])
        XCTAssertNotNil(object["points"])
    }

    @MainActor
    func testRenderedPayloadsDifferAcrossDataKinds() throws {
        let context = try makeSeededContext()
        var payloads: [Data] = []
        for kind in ExportOptions.DataKind.allCases {
            payloads.append(try renderFixture(dataKind: kind, context: context).data)
        }
        for (index, payload) in payloads.enumerated() {
            for other in payloads[(index + 1)...] {
                XCTAssertNotEqual(
                    payload,
                    other,
                    "Every data kind must render a distinct payload for the same fixtures and range"
                )
            }
        }
    }
}
