import Foundation
import CoreLocation
import UIKit

struct MileageVehicle: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var placedInService: Date
    var yearStartOdometer: [Int: Double] = [:]
    var yearEndOdometer: [Int: Double] = [:]

    static let defaultVehicle = MileageVehicle(name: "Default Vehicle", placedInService: Date())
}

struct MileageVehicleStore {
    private static let key = "mileageReportVehicles"

    static func load() -> [MileageVehicle] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let vehicles = try? JSONDecoder().decode([MileageVehicle].self, from: data),
              !vehicles.isEmpty else {
            return [.defaultVehicle]
        }
        return vehicles
    }

    static func save(_ vehicles: [MileageVehicle]) {
        guard let data = try? JSONEncoder().encode(vehicles.isEmpty ? [.defaultVehicle] : vehicles) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func vehicleName(for id: UUID?, in vehicles: [MileageVehicle]) -> String {
        guard let id, let vehicle = vehicles.first(where: { $0.id == id }) else {
            return vehicles.first?.name ?? MileageVehicle.defaultVehicle.name
        }
        return vehicle.name
    }
}

struct StandardMileageRate: Codable, Identifiable, Equatable {
    let id: String
    let year: Int
    let startsOn: Date
    let centsPerMile: Double

    var dollarsPerMile: Double { centsPerMile / 100 }

    static let bakedInRates: [StandardMileageRate] = {
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        }
        return [
            .init(id: "2026-01-01", year: 2026, startsOn: date(2026, 1, 1), centsPerMile: 72.5),
            .init(id: "2025-01-01", year: 2025, startsOn: date(2025, 1, 1), centsPerMile: 70.0),
            .init(id: "2024-01-01", year: 2024, startsOn: date(2024, 1, 1), centsPerMile: 67.0),
            .init(id: "2023-01-01", year: 2023, startsOn: date(2023, 1, 1), centsPerMile: 65.5),
            .init(id: "2022-07-01", year: 2022, startsOn: date(2022, 7, 1), centsPerMile: 62.5),
            .init(id: "2022-01-01", year: 2022, startsOn: date(2022, 1, 1), centsPerMile: 58.5),
            .init(id: "2021-01-01", year: 2021, startsOn: date(2021, 1, 1), centsPerMile: 56.0)
        ]
    }()
}

enum MileageReportPreset: String, CaseIterable, Identifiable {
    case taxYear
    case q1
    case q2
    case q3
    case q4

    var id: String { rawValue }

    var label: String {
        switch self {
        case .taxYear: return "Tax Year"
        case .q1: return "Q1"
        case .q2: return "Q2"
        case .q3: return "Q3"
        case .q4: return "Q4"
        }
    }

    func dateRange(year: Int, calendar: Calendar = .current) -> ClosedRange<Date> {
        let startMonth: Int
        let endMonth: Int
        switch self {
        case .taxYear:
            startMonth = 1
            endMonth = 12
        case .q1:
            startMonth = 1
            endMonth = 3
        case .q2:
            startMonth = 4
            endMonth = 6
        case .q3:
            startMonth = 7
            endMonth = 9
        case .q4:
            startMonth = 10
            endMonth = 12
        }

        let start = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? Date()
        let endStart = calendar.date(from: DateComponents(year: year, month: endMonth + 1, day: 1))
            ?? calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
            ?? Date()
        let end = calendar.date(byAdding: .second, value: -1, to: endStart) ?? endStart
        return start...end
    }
}

struct MileageReportOptions {
    var year: Int = Calendar.current.component(.year, from: Date()) - 1
    var preset: MileageReportPreset = .taxYear
    var includedVehicleIDs: Set<UUID> = []
    var includedClassifications: Set<TripClassification> = [.business]
    var overrideCentsPerMile: Double?

    var dateRange: ClosedRange<Date> { preset.dateRange(year: year) }
}

struct MileageTripRow: Identifiable {
    let id: UUID
    let date: Date
    let startAddress: String
    let endAddress: String
    let purpose: String
    let subPurpose: String
    let vehicleID: UUID
    let vehicleName: String
    let classification: TripClassification
    let miles: Double
    let standardMileageRateCents: Double
    let notes: String
    let startedAt: Date
    let endedAt: Date

    var deductionAmount: Double {
        classification == .business ? miles * standardMileageRateCents / 100 : 0
    }
}

struct MileageVehicleSummary: Identifiable {
    let id: UUID
    let vehicleName: String
    let placedInService: Date
    let totalMiles: Double
    let businessMiles: Double
    let personalMiles: Double
    let commutingMiles: Double
    let unclassifiedMiles: Double
    let yearStartOdometer: Double?
    let yearEndOdometer: Double?

    var businessUsePercentage: Double {
        guard totalMiles > 0 else { return 0 }
        return businessMiles / totalMiles * 100
    }
}

struct MileageReport {
    let generatedAt: Date
    let year: Int
    let dateRange: ClosedRange<Date>
    let trips: [MileageTripRow]
    let summaries: [MileageVehicleSummary]
    let unclassifiedTripCount: Int
    let excludedTripCount: Int
    let standardMileageRateCents: Double

    var totalBusinessMiles: Double { summaries.reduce(0) { $0 + $1.businessMiles } }
    var deductionAmount: Double { trips.reduce(0) { $0 + $1.deductionAmount } }
}

enum MileageReportBuilder {
    static func build(visits: [Visit], points: [LocationPoint], vehicles: [MileageVehicle], options: MileageReportOptions) -> MileageReport {
        let sortedVisits = visits.sorted { $0.arrivedAt < $1.arrivedAt }
        let vehicleIDs = options.includedVehicleIDs.isEmpty ? Set(vehicles.map(\.id)) : options.includedVehicleIDs
        var allRows: [MileageTripRow] = []
        var unclassifiedCount = 0

        for index in 1..<sortedVisits.count {
            let origin = sortedVisits[index - 1]
            let destination = sortedVisits[index]
            guard let startedAt = origin.departedAt else { continue }
            let endedAt = destination.arrivedAt
            guard options.dateRange.overlaps(startedAt...endedAt) else { continue }

            let vehicleID = destination.vehicleID ?? vehicles.first?.id ?? MileageVehicle.defaultVehicle.id
            guard vehicleIDs.contains(vehicleID) else { continue }

            let classification = destination.tripClassification
            if classification == .unclassified { unclassifiedCount += 1 }
            let rateCents = options.overrideCentsPerMile ?? standardRateCents(for: options.year, on: startedAt)

            let tripPoints = points
                .filter { $0.timestamp >= startedAt && $0.timestamp <= endedAt && !$0.isOutlier }
                .sorted { $0.timestamp < $1.timestamp }
            let miles = milesDriven(from: origin, to: destination, points: tripPoints)

            allRows.append(MileageTripRow(
                id: destination.id,
                date: startedAt,
                startAddress: origin.address ?? origin.locationName ?? origin.displayName,
                endAddress: destination.address ?? destination.locationName ?? destination.displayName,
                purpose: destination.businessPurpose ?? "",
                subPurpose: destination.businessSubPurpose ?? "",
                vehicleID: vehicleID,
                vehicleName: MileageVehicleStore.vehicleName(for: vehicleID, in: vehicles),
                classification: classification,
                miles: roundedMiles(miles),
                standardMileageRateCents: rateCents,
                notes: destination.notes ?? "",
                startedAt: startedAt,
                endedAt: endedAt
            ))
        }

        let includedRows = allRows.filter { options.includedClassifications.contains($0.classification) }
        let summaries = vehicles.filter { vehicleIDs.contains($0.id) }.map { vehicle in
            let rows = allRows.filter { $0.vehicleID == vehicle.id }
            let total = rows.reduce(0) { $0 + $1.miles }
            let business = rows.filter { $0.classification == .business }.reduce(0) { $0 + $1.miles }
            let personal = rows.filter { $0.classification == .personal }.reduce(0) { $0 + $1.miles }
            let commuting = rows.filter { $0.classification == .commuting }.reduce(0) { $0 + $1.miles }
            let unclassified = rows.filter { $0.classification == .unclassified }.reduce(0) { $0 + $1.miles }
            let odometerStart = vehicle.yearStartOdometer[options.year]
            let odometerEnd = vehicle.yearEndOdometer[options.year]
            return MileageVehicleSummary(
                id: vehicle.id,
                vehicleName: vehicle.name,
                placedInService: vehicle.placedInService,
                totalMiles: odometerStart.flatMap { start in odometerEnd.map { $0 - start } } ?? roundedMiles(total),
                businessMiles: roundedMiles(business),
                personalMiles: roundedMiles(personal),
                commutingMiles: roundedMiles(commuting),
                unclassifiedMiles: roundedMiles(unclassified),
                yearStartOdometer: odometerStart,
                yearEndOdometer: odometerEnd
            )
        }

        return MileageReport(
            generatedAt: Date(),
            year: options.year,
            dateRange: options.dateRange,
            trips: includedRows,
            summaries: summaries,
            unclassifiedTripCount: unclassifiedCount,
            excludedTripCount: max(0, allRows.count - includedRows.count),
            standardMileageRateCents: options.overrideCentsPerMile ?? standardRateCents(for: options.year)
        )
    }

    static func standardRateCents(for year: Int, on date: Date? = nil) -> Double {
        let rates = StandardMileageRate.bakedInRates.filter { $0.year == year }.sorted { $0.startsOn > $1.startsOn }
        guard let date else { return rates.first?.centsPerMile ?? 0 }
        return rates.first(where: { date >= $0.startsOn })?.centsPerMile ?? rates.last?.centsPerMile ?? 0
    }

    private static func milesDriven(from origin: Visit, to destination: Visit, points: [LocationPoint]) -> Double {
        let meters: Double
        if points.count > 1 {
            meters = zip(points, points.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
        } else {
            let start = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            let end = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
            meters = start.distance(from: end)
        }
        return meters / 1609.344
    }

    private static func roundedMiles(_ miles: Double) -> Double {
        (miles * 10).rounded() / 10
    }
}

extension ExportService {
    static func exportMileageReportToCSV(_ report: MileageReport) -> Data {
        var csv = "# iso.me Mileage Report\n"
        csv += "# Generated,\(iso8601Formatter.string(from: report.generatedAt))\n"
        csv += "# Date Range,\(iso8601Formatter.string(from: report.dateRange.lowerBound)),\(iso8601Formatter.string(from: report.dateRange.upperBound))\n"
        csv += "# Standard Mileage Rate,\(String(format: "%.1f", report.standardMileageRateCents)) cents/mile\n"
        csv += "# Deduction,\(String(format: "%.2f", report.deductionAmount))\n"
        csv += "# Warning,\(report.unclassifiedTripCount) unclassified trips not included\n\n"

        csv += "Vehicle Annual Summary\n"
        csv += "vehicle,placed_in_service,total_miles,business_miles,personal_miles,commuting_miles,unclassified_miles,business_use_percentage,year_start_odometer,year_end_odometer\n"
        for summary in report.summaries {
            csv += [
                escapeCSVField(summary.vehicleName),
                shortDate(summary.placedInService),
                oneDecimal(summary.totalMiles),
                oneDecimal(summary.businessMiles),
                oneDecimal(summary.personalMiles),
                oneDecimal(summary.commutingMiles),
                oneDecimal(summary.unclassifiedMiles),
                oneDecimal(summary.businessUsePercentage),
                summary.yearStartOdometer.map(oneDecimal) ?? "",
                summary.yearEndOdometer.map(oneDecimal) ?? ""
            ].joined(separator: ",") + "\n"
        }

        csv += "\nTrip Detail\n"
        csv += "date,start_address,end_address,business_destination,business_purpose,sub_purpose,vehicle,miles,standard_mileage_rate_cents,deduction_amount,notes,started_at,ended_at\n"
        for trip in report.trips {
            csv += [
                shortDate(trip.date),
                escapeCSVField(trip.startAddress),
                escapeCSVField(trip.endAddress),
                escapeCSVField(trip.endAddress),
                escapeCSVField(trip.purpose),
                escapeCSVField(trip.subPurpose),
                escapeCSVField(trip.vehicleName),
                oneDecimal(trip.miles),
                oneDecimal(trip.standardMileageRateCents),
                String(format: "%.2f", trip.deductionAmount),
                escapeCSVField(trip.notes),
                iso8601Formatter.string(from: trip.startedAt),
                iso8601Formatter.string(from: trip.endedAt)
            ].joined(separator: ",") + "\n"
        }

        csv += "\n# Report generated from contemporaneous GPS logs with timestamps. Review classifications, purpose, and odometer values before filing.\n"
        return csv.data(using: .utf8) ?? Data()
    }

    static func exportMileageReportToPDF(_ report: MileageReport) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 36
            draw("iso.me Mileage Report", at: &y, size: 20, weight: .bold)
            draw("Generated: \(readableDate(report.generatedAt))", at: &y)
            draw("Period: \(shortDate(report.dateRange.lowerBound)) to \(shortDate(report.dateRange.upperBound))", at: &y)
            draw("Standard mileage rate: \(oneDecimal(report.standardMileageRateCents)) cents/mile", at: &y)
            draw("Business miles: \(oneDecimal(report.totalBusinessMiles))    Deduction: \(currency(report.deductionAmount))", at: &y, weight: .semibold)
            if report.unclassifiedTripCount > 0 {
                draw("Warning: \(report.unclassifiedTripCount) unclassified trips not included.", at: &y, color: .systemOrange)
            }
            y += 12

            draw("Per-Vehicle Annual Summary", at: &y, size: 14, weight: .bold)
            for summary in report.summaries {
                draw("\(summary.vehicleName): total \(oneDecimal(summary.totalMiles)), business \(oneDecimal(summary.businessMiles)), personal \(oneDecimal(summary.personalMiles)), commuting \(oneDecimal(summary.commutingMiles)), business use \(oneDecimal(summary.businessUsePercentage))%", at: &y)
                draw("Placed in service: \(shortDate(summary.placedInService)); odometer: \(summary.yearStartOdometer.map(oneDecimal) ?? "n/a") to \(summary.yearEndOdometer.map(oneDecimal) ?? "n/a")", at: &y, size: 9, color: .darkGray)
            }
            y += 12

            draw("Trip Detail", at: &y, size: 14, weight: .bold)
            for trip in report.trips {
                if y > 720 {
                    drawFooter(page: page)
                    context.beginPage()
                    y = 36
                    draw("Trip Detail (continued)", at: &y, size: 14, weight: .bold)
                }
                draw("\(shortDate(trip.date))  \(oneDecimal(trip.miles)) mi  \(trip.vehicleName)  \(oneDecimal(trip.standardMileageRateCents)) cents/mi", at: &y, weight: .semibold)
                draw("\(trip.startAddress) -> \(trip.endAddress)", at: &y, size: 9)
                draw("Purpose: \(trip.purpose.isEmpty ? "Not provided" : trip.purpose)  \(trip.subPurpose)", at: &y, size: 9)
                if !trip.notes.isEmpty { draw("Notes: \(trip.notes)", at: &y, size: 9, color: .darkGray) }
                y += 6
            }
            drawFooter(page: page)
        }
    }

    @MainActor
    static func shareMileageReport(_ report: MileageReport, format: ExportFormat, from viewController: UIViewController? = nil) throws {
        let data = format == .csv ? exportMileageReportToCSV(report) : exportMileageReportToPDF(report)
        let fileExtension = format == .csv ? "csv" : "pdf"
        let fileName = "isome_mileage_report_\(report.year)_\(formattedDate()).\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let presenter = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else { return }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }

    @MainActor
    static func saveMileageReportToDefaultFolder(_ report: MileageReport, format: ExportFormat) throws -> URL {
        let data = format == .csv ? exportMileageReportToCSV(report) : exportMileageReportToPDF(report)
        let fileExtension = format == .csv ? "csv" : "pdf"
        let fileName = "isome_mileage_report_\(report.year)_\(formattedDate()).\(fileExtension)"
        guard let savedURL = try ExportFolderManager.shared.saveToDefaultFolder(data: data, fileName: fileName) else {
            throw ExportFolderError.noDefaultFolder
        }
        return savedURL
    }

    fileprivate static func oneDecimal(_ value: Double) -> String { String(format: "%.1f", value) }
    fileprivate static func currency(_ value: Double) -> String { String(format: "$%.2f", value) }
    fileprivate static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    fileprivate static func readableDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    fileprivate static func draw(_ text: String, at y: inout CGFloat, size: CGFloat = 10, weight: UIFont.Weight = .regular, color: UIColor = .black) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let rect = CGRect(x: 36, y: y, width: 540, height: 56)
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        let height = text.boundingRect(with: CGSize(width: 540, height: 120), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height
        y += ceil(height) + 5
    }
    fileprivate static func drawFooter(page: CGRect) {
        let footer = "Generated from contemporaneous GPS logs with timestamps. Signature: ____________________  Date: __________"
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray]
        footer.draw(in: CGRect(x: 36, y: page.height - 42, width: 540, height: 24), withAttributes: attributes)
    }
}
