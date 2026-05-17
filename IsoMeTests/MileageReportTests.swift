import XCTest
@testable import IsoMe

final class MileageReportTests: XCTestCase {
    func testBuilderPartitionsTripsAndCalculatesDeduction() {
        let calendar = Calendar(identifier: .gregorian)
        let vehicleID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let vehicle = MileageVehicle(
            id: vehicleID,
            name: "Work Van",
            placedInService: calendar.date(from: DateComponents(year: 2024, month: 6, day: 1))!,
            yearStartOdometer: [2025: 10_000],
            yearEndOdometer: [2025: 12_000]
        )

        let origin = Visit(
            latitude: 37.7749,
            longitude: -122.4194,
            arrivedAt: calendar.date(from: DateComponents(year: 2025, month: 1, day: 3, hour: 8))!,
            departedAt: calendar.date(from: DateComponents(year: 2025, month: 1, day: 3, hour: 9))!,
            address: "Start Office"
        )
        let businessDestination = Visit(
            latitude: 37.8044,
            longitude: -122.2712,
            arrivedAt: calendar.date(from: DateComponents(year: 2025, month: 1, day: 3, hour: 10))!,
            departedAt: calendar.date(from: DateComponents(year: 2025, month: 1, day: 3, hour: 11))!,
            address: "Client Site",
            purpose: .business,
            subPurpose: "Client meeting",
            vehicleID: vehicle.id
        )
        let personalDestination = Visit(
            latitude: 37.8715,
            longitude: -122.2730,
            arrivedAt: calendar.date(from: DateComponents(year: 2025, month: 1, day: 3, hour: 12))!,
            address: "Personal Stop",
            purpose: .personal,
            vehicleID: vehicle.id
        )

        let points = [
            LocationPoint(latitude: 37.7749, longitude: -122.4194, timestamp: origin.departedAt!, horizontalAccuracy: 5),
            LocationPoint(latitude: 37.8044, longitude: -122.2712, timestamp: businessDestination.arrivedAt, horizontalAccuracy: 5),
            LocationPoint(latitude: 37.8715, longitude: -122.2730, timestamp: personalDestination.arrivedAt, horizontalAccuracy: 5)
        ]

        var options = MileageReportOptions(year: 2025)
        options.includedVehicleIDs = [vehicle.id]
        options.includedClassifications = [.business]

        let report = MileageReportBuilder.build(
            visits: [personalDestination, origin, businessDestination],
            points: points,
            vehicles: [vehicle],
            options: options
        )

        XCTAssertEqual(report.trips.count, 1)
        XCTAssertEqual(report.trips.first?.purpose, "Client meeting")
        XCTAssertEqual(report.summaries.first?.businessMiles, report.totalBusinessMiles)
        XCTAssertGreaterThan(report.summaries.first?.personalMiles ?? 0, 0)
        XCTAssertEqual(report.summaries.first?.totalMiles, 2_000)
        XCTAssertEqual(report.standardMileageRateCents, 70.0)
        XCTAssertEqual(report.deductionAmount, report.totalBusinessMiles * 0.70, accuracy: 0.001)
    }

    func testBuilderHandlesEmptyAndSingleVisitReports() {
        let calendar = Calendar(identifier: .gregorian)
        let vehicle = MileageVehicle(name: "Work Van", placedInService: Date())
        var options = MileageReportOptions(year: 2025)
        options.includedVehicleIDs = [vehicle.id]

        let emptyReport = MileageReportBuilder.build(
            visits: [],
            points: [],
            vehicles: [vehicle],
            options: options
        )
        XCTAssertTrue(emptyReport.trips.isEmpty)
        XCTAssertEqual(emptyReport.totalBusinessMiles, 0)
        XCTAssertEqual(emptyReport.summaries.first?.totalMiles, 0)

        let onlyVisit = Visit(
            latitude: 37.7749,
            longitude: -122.4194,
            arrivedAt: calendar.date(from: DateComponents(year: 2025, month: 1, day: 3, hour: 8))!,
            address: "Start Office",
            purpose: .business,
            subPurpose: "Client meeting",
            vehicleID: vehicle.id
        )
        let singleVisitReport = MileageReportBuilder.build(
            visits: [onlyVisit],
            points: [],
            vehicles: [vehicle],
            options: options
        )
        XCTAssertTrue(singleVisitReport.trips.isEmpty)
        XCTAssertEqual(singleVisitReport.totalBusinessMiles, 0)
        XCTAssertEqual(singleVisitReport.unclassifiedTripCount, 0)
    }

    func testBakedInRatesIncludeMidYear2022AndCurrent2026() {
        let calendar = Calendar(identifier: .gregorian)
        let june = calendar.date(from: DateComponents(year: 2022, month: 6, day: 30))!
        let july = calendar.date(from: DateComponents(year: 2022, month: 7, day: 1))!

        XCTAssertEqual(MileageReportBuilder.standardRateCents(for: 2022, on: june), 58.5)
        XCTAssertEqual(MileageReportBuilder.standardRateCents(for: 2022, on: july), 62.5)
        XCTAssertEqual(MileageReportBuilder.standardRateCents(for: 2026), 72.5)
    }
}
