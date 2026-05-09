import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
@Observable
final class LocationViewModel {
    var locationManager: LocationManager
    private var modelContext: ModelContext

    // Cached data
    var todayVisits: [Visit] = []
    var allVisits: [Visit] = []
    var locationPoints: [LocationPoint] = []
    var todayLocationPoints: [LocationPoint] = []
    var vehicles: [Vehicle] = []
    var vehiclePairingMessage: String?

    // UI State
    var mapDateRange: ClosedRange<Date> = Calendar.current.startOfDay(for: Date())...Date()
    var showingExportSheet = false
    var showingClearConfirmation = false
    var exportError: String?

    private var cancellables = Set<AnyCancellable>()
    private let frequentSubPurposesKey = "frequentBusinessSubPurposes"

    init(modelContext: ModelContext, locationManager: LocationManager) {
        self.modelContext = modelContext
        self.locationManager = locationManager
        locationManager.setModelContext(modelContext)

        loadData()
        
        // Observe location manager for new data points and reload when they're saved
        locationManager.$locationPointsSavedCount
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadTodayLocationPoints()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() {
        loadTodayVisits()
        loadAllVisits()
        loadLocationPoints()
        loadTodayLocationPoints()
        loadVehicles()
    }

    func loadTodayVisits() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<Visit> { visit in
            visit.arrivedAt >= startOfDay && visit.arrivedAt < endOfDay
        }

        var descriptor = FetchDescriptor<Visit>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .forward)]

        do {
            todayVisits = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch today's visits: \(error)")
            todayVisits = []
        }
    }

    func loadAllVisits() {
        var descriptor = FetchDescriptor<Visit>()
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .reverse)]

        do {
            allVisits = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch all visits: \(error)")
            allVisits = []
        }
    }

    func loadLocationPoints() {
        var descriptor = FetchDescriptor<LocationPoint>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        do {
            locationPoints = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch location points: \(error)")
            locationPoints = []
        }
    }

    func loadTodayLocationPoints() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<LocationPoint> { point in
            point.timestamp >= startOfDay && point.timestamp < endOfDay
        }

        var descriptor = FetchDescriptor<LocationPoint>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        do {
            todayLocationPoints = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch today's location points: \(error)")
            todayLocationPoints = []
        }
    }

    func loadVehicles() {
        var descriptor = FetchDescriptor<Vehicle>()
        descriptor.sortBy = [
            SortDescriptor(\.name, order: .forward)
        ]

        do {
            vehicles = try modelContext.fetch(descriptor)
                .sorted { lhs, rhs in
                    if lhs.isDefault != rhs.isDefault { return lhs.isDefault && !rhs.isDefault }
                    if lhs.isArchived != rhs.isArchived { return !lhs.isArchived && rhs.isArchived }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
        } catch {
            print("Failed to fetch vehicles: \(error)")
            vehicles = []
        }
    }

    // MARK: - Computed Properties

    var currentVisit: Visit? {
        todayVisits.first { $0.isCurrentVisit }
    }

    var activeVehicles: [Vehicle] {
        vehicles.filter { !$0.isArchived }
    }

    var defaultVehicle: Vehicle? {
        activeVehicles.first { $0.isDefault }
    }

    var recentVehicles: [Vehicle] {
        let ids = (allVisits.map(\.vehicleID) + locationPoints.map(\.vehicleID)).compactMap { $0 }
        var seen = Set<UUID>()
        let orderedIDs = ids.filter { seen.insert($0).inserted }
        let byID = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0) })
        let recent = orderedIDs.compactMap { byID[$0] }.filter { !$0.isArchived }
        return Array((recent + activeVehicles).reduce(into: [Vehicle]()) { result, vehicle in
            if !result.contains(where: { $0.id == vehicle.id }) {
                result.append(vehicle)
            }
        }.prefix(4))
    }

    // Session-specific location points (only points from current tracking session)
    var sessionLocationPoints: [LocationPoint] {
        guard let sessionStart = locationManager.trackingStartTime else {
            return []
        }
        return todayLocationPoints.filter { $0.timestamp >= sessionStart }
    }

    // Session tracking stats
    var sessionTrackingDuration: TimeInterval {
        guard let sessionStart = locationManager.trackingStartTime else { return 0 }
        return Date().timeIntervalSince(sessionStart)
    }

    var sessionDistanceTraveled: Double {
        let points = sessionLocationPoints
        guard points.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<points.count {
            let prev = points[i-1]
            let curr = points[i]
            total += prev.distance(to: curr)
        }
        return total
    }

    var formattedSessionTrackingDuration: String {
        let totalSeconds = Int(sessionTrackingDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes < 60 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, seconds)
        }
    }

    var formattedSessionDistance: String {
        formatDistance(sessionDistanceTraveled)
    }

    // Today's tracking stats (kept for other views)
    var todayTrackingDuration: TimeInterval {
        guard let first = todayLocationPoints.first,
              let last = todayLocationPoints.last else { return 0 }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }

    var todayDistanceTraveled: Double {
        guard todayLocationPoints.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<todayLocationPoints.count {
            let prev = todayLocationPoints[i-1]
            let curr = todayLocationPoints[i]
            total += prev.distance(to: curr)
        }
        return total
    }

    var formattedTodayTrackingDuration: String {
        let minutes = Int(todayTrackingDuration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }

    var formattedTodayDistance: String {
        formatDistance(todayDistanceTraveled)
    }

    private var usesMetricDistanceUnits: Bool {
        let key = "usesMetricDistanceUnits"
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func formatDistance(_ meters: Double) -> String {
        DistanceFormatter.format(meters: meters, usesMetric: usesMetricDistanceUnits)
    }

    func visitsInDateRange(_ range: ClosedRange<Date>) -> [Visit] {
        allVisits.filter { range.contains($0.arrivedAt) }
    }

    func locationPointsInDateRange(_ range: ClosedRange<Date>) -> [LocationPoint] {
        locationPoints.filter { range.contains($0.timestamp) }
    }

    // MARK: - Visit Management

    func deleteVisit(_ visit: Visit) {
        modelContext.delete(visit)
        try? modelContext.save()
        loadData()
    }

    func updateVisitNotes(_ visit: Visit, notes: String) {
        visit.notes = notes.isEmpty ? nil : notes
        try? modelContext.save()
    }

    func updateVisitClassification(_ visit: Visit, purpose: TripPurpose, subPurpose: String? = nil) {
        visit.purpose = purpose
        let cleanedSubPurpose = subPurpose?.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.subPurpose = purpose == .business && !(cleanedSubPurpose?.isEmpty ?? true) ? cleanedSubPurpose : nil
        rememberSubPurpose(visit.subPurpose)
        try? modelContext.save()
        loadData()
    }

    func updateVisitVehicle(_ visit: Visit, vehicle: Vehicle?) {
        visit.vehicleID = vehicle?.id
        visit.vehicleName = vehicle?.name
        visit.vehicleDetectionSource = vehicle == nil ? nil : "manual"
        visit.vehicleBluetoothPortName = nil
        try? modelContext.save()
        loadData()
    }

    func assignVehicle(_ vehicleID: UUID?, to visit: Visit) {
        updateVisitVehicle(visit, vehicle: vehicle(for: vehicleID))
    }

    func bulkUpdateClassification(_ visits: [Visit], purpose: TripPurpose, subPurpose: String? = nil) {
        let cleanedSubPurpose = subPurpose?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedSubPurpose = purpose == .business && !(cleanedSubPurpose?.isEmpty ?? true) ? cleanedSubPurpose : nil

        for visit in visits {
            visit.purpose = purpose
            visit.subPurpose = storedSubPurpose
        }

        rememberSubPurpose(storedSubPurpose)
        try? modelContext.save()
        loadData()
    }

    var frequentBusinessSubPurposes: [String] {
        UserDefaults.standard.stringArray(forKey: frequentSubPurposesKey) ?? []
    }

    private func rememberSubPurpose(_ subPurpose: String?) {
        guard let subPurpose, !subPurpose.isEmpty else { return }
        var values = frequentBusinessSubPurposes.filter { $0.caseInsensitiveCompare(subPurpose) != .orderedSame }
        values.insert(subPurpose, at: 0)
        UserDefaults.standard.set(Array(values.prefix(12)), forKey: frequentSubPurposesKey)
    }

    func vehicle(for id: UUID?) -> Vehicle? {
        guard let id else { return nil }
        return vehicles.first { $0.id == id }
    }

    func vehicleName(for id: UUID?) -> String {
        vehicle(for: id)?.name ?? "No Vehicle"
    }

    func addVehicle(
        name: String,
        make: String?,
        model: String?,
        year: Int?,
        licensePlate: String?,
        odometerStart: Int?,
        odometerCurrent: Int?,
        isDefault: Bool
    ) {
        let shouldDefault = isDefault || activeVehicles.isEmpty
        if shouldDefault {
            clearDefaultVehicle()
        }

        let vehicle = Vehicle(
            name: name,
            make: make,
            model: model,
            year: year,
            licensePlate: licensePlate,
            odometerStart: odometerStart,
            odometerCurrent: odometerCurrent,
            isDefault: shouldDefault
        )
        modelContext.insert(vehicle)
        try? modelContext.save()
        loadVehicles()
    }

    func addVehicle(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addVehicle(
            name: trimmed,
            make: nil,
            model: nil,
            year: nil,
            licensePlate: nil,
            odometerStart: nil,
            odometerCurrent: nil,
            isDefault: activeVehicles.isEmpty
        )
    }

    func updateVehicle(
        _ vehicle: Vehicle,
        name: String,
        make: String?,
        model: String?,
        year: Int?,
        licensePlate: String?,
        odometerStart: Int?,
        odometerCurrent: Int?,
        isDefault: Bool
    ) {
        if isDefault {
            clearDefaultVehicle(except: vehicle.id)
        }
        vehicle.name = name
        vehicle.make = make
        vehicle.model = model
        vehicle.year = year
        vehicle.licensePlate = licensePlate
        vehicle.odometerStart = odometerStart
        vehicle.odometerCurrent = odometerCurrent
        vehicle.isDefault = isDefault
        try? modelContext.save()
        loadVehicles()
    }

    func setDefaultVehicle(_ vehicle: Vehicle) {
        clearDefaultVehicle(except: vehicle.id)
        vehicle.isDefault = true
        try? modelContext.save()
        loadVehicles()
    }

    func pairVehicleWithBluetooth(_ vehicle: Vehicle) {
        let detector = locationManager.bluetoothVehicleDetector
        vehiclePairingMessage = "Waiting for a car audio or Bluetooth route..."

        detector.beginPairing(vehicleID: vehicle.id) { [weak self] route in
            guard let self else { return }
            vehicle.bluetoothPortName = route.portName
            vehicle.bluetoothPortType = route.portType
            try? self.modelContext.save()
            self.vehiclePairingMessage = "Paired \(vehicle.name) with \(route.portName)."
            self.loadVehicles()
        }
    }

    func clearBluetoothPairing(for vehicle: Vehicle) {
        vehicle.bluetoothPortName = nil
        vehicle.bluetoothPortType = nil
        try? modelContext.save()
        loadVehicles()
    }

    func deleteVehicle(_ vehicle: Vehicle) {
        archiveVehicle(vehicle)
    }

    func archiveVehicle(_ vehicle: Vehicle) {
        vehicle.archivedAt = Date()
        vehicle.isDefault = false
        if defaultVehicle == nil, let replacement = activeVehicles.first(where: { $0.id != vehicle.id }) {
            replacement.isDefault = true
        }
        try? modelContext.save()
        loadVehicles()
    }

    private func clearDefaultVehicle(except id: UUID? = nil) {
        for vehicle in vehicles where vehicle.id != id {
            vehicle.isDefault = false
        }
    }

    // MARK: - Export

    func exportVisits(format: ExportFormat, dateRange: ClosedRange<Date>? = nil) {
        let visitsToExport: [Visit]
        if let range = dateRange {
            visitsToExport = visitsInDateRange(range)
        } else {
            visitsToExport = allVisits
        }

        do {
            try ExportService.share(visits: visitsToExport, vehicles: vehicles, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }
    
    func exportLocationPoints(format: ExportFormat, dateRange: ClosedRange<Date>? = nil) {
        let pointsToExport: [LocationPoint]
        if let range = dateRange {
            pointsToExport = locationPointsInDateRange(range)
        } else {
            pointsToExport = locationPoints
        }

        do {
            try ExportService.shareLocationPoints(points: pointsToExport, vehicles: vehicles, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }

    func exportAllData(format: ExportFormat) {
        do {
            try ExportService.shareCombined(visits: allVisits, points: locationPoints, vehicles: vehicles, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }

    @MainActor
    func exportWithOptions(_ options: ExportOptions) {
        do {
            try ExportService.share(visits: allVisits, points: locationPoints, vehicles: vehicles, options: options)
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Import

    func importData(from url: URL) throws -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.invalidData("Cannot access file")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let format = ImportService.detectFormat(url: url) else {
            throw ImportError.unsupportedFormat
        }

        let data = try Data(contentsOf: url)
        let result = try ImportService.importFile(data: data, format: format)

        for imported in result.visits {
            let visit = Visit(
                latitude: imported.latitude,
                longitude: imported.longitude,
                arrivedAt: imported.arrivedAt,
                departedAt: imported.departedAt,
                locationName: imported.locationName,
                address: imported.address,
                notes: imported.notes,
                purpose: imported.purpose,
                subPurpose: imported.subPurpose,
                geocodingCompleted: imported.locationName != nil || imported.address != nil
            )
            modelContext.insert(visit)
        }

        for imported in result.points {
            let point = LocationPoint(
                latitude: imported.latitude,
                longitude: imported.longitude,
                timestamp: imported.timestamp,
                altitude: imported.altitude,
                speed: imported.speed,
                horizontalAccuracy: imported.horizontalAccuracy,
                isOutlier: imported.isOutlier
            )
            modelContext.insert(point)
        }

        try modelContext.save()
        loadData()

        return ImportResult(visitCount: result.visits.count, pointCount: result.points.count)
    }

    // MARK: - Clear Data

    func clearAllData() {
        do {
            try modelContext.delete(model: Visit.self)
            try modelContext.delete(model: LocationPoint.self)
            try modelContext.delete(model: Vehicle.self)
            try modelContext.save()
            loadData()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }

    // MARK: - Tracking Control

    func startTracking() {
        locationManager.startTracking()
    }

    func stopTracking() {
        locationManager.stopTracking()
    }
}
