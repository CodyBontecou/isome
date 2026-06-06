import Foundation
import SwiftData
import CoreLocation

enum VisitSource: String, Codable, CaseIterable, Identifiable {
    case automatic
    case manual
    case imported

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .manual: return "Manual"
        case .imported: return "Imported"
        }
    }
}

enum VisitConfirmationStatus: String, Codable, CaseIterable, Identifiable {
    case unconfirmed
    case confirmed
    case corrected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unconfirmed: return "Unconfirmed"
        case .confirmed: return "Confirmed"
        case .corrected: return "Corrected"
        }
    }
}

enum VisitPlaceSource: String, Codable, CaseIterable, Identifiable {
    case coreLocationGeocode
    case appleMaps
    case userEntered
    case `import`

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coreLocationGeocode: return "Core Location"
        case .appleMaps: return "Apple Maps"
        case .userEntered: return "User Entered"
        case .import: return "Import"
        }
    }
}

struct VisitPlaceUpdate: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var locationName: String?
    var address: String?
    var placeSource: VisitPlaceSource
    var placeCategoryRaw: String?
    var placeDistanceMeters: Double?
    var placeConfidence: Double?

    init(
        latitude: Double,
        longitude: Double,
        locationName: String? = nil,
        address: String? = nil,
        placeSource: VisitPlaceSource = .userEntered,
        placeCategoryRaw: String? = nil,
        placeDistanceMeters: Double? = nil,
        placeConfidence: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.address = address
        self.placeSource = placeSource
        self.placeCategoryRaw = placeCategoryRaw
        self.placeDistanceMeters = placeDistanceMeters
        self.placeConfidence = placeConfidence
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ManualVisitDraft: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var arrivedAt: Date
    var departedAt: Date?
    var locationName: String?
    var address: String?
    var notes: String?
    var placeSource: VisitPlaceSource
    var placeCategoryRaw: String?
    var placeDistanceMeters: Double?
    var placeConfidence: Double?

    init(
        latitude: Double,
        longitude: Double,
        arrivedAt: Date,
        departedAt: Date? = nil,
        locationName: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        placeSource: VisitPlaceSource = .userEntered,
        placeCategoryRaw: String? = nil,
        placeDistanceMeters: Double? = nil,
        placeConfidence: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.arrivedAt = arrivedAt
        self.departedAt = departedAt
        self.locationName = locationName
        self.address = address
        self.notes = notes
        self.placeSource = placeSource
        self.placeCategoryRaw = placeCategoryRaw
        self.placeDistanceMeters = placeDistanceMeters
        self.placeConfidence = placeConfidence
    }
}

enum VisitMutationError: LocalizedError, Equatable {
    case invalidTimeRange
    case overlappingManualVisit
    case noCorrectionToUndo
    case checkoutRequiresManualVisit
    case visitAlreadyCheckedOut
    case noCurrentLocation

    var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "Departure time must be after arrival time."
        case .overlappingManualVisit:
            return "A manual visit already overlaps this time range."
        case .noCorrectionToUndo:
            return "This visit does not have a correction to undo."
        case .checkoutRequiresManualVisit:
            return "Only manual check-ins can be checked out manually."
        case .visitAlreadyCheckedOut:
            return "This visit is already checked out."
        case .noCurrentLocation:
            return "Current location is unavailable."
        }
    }
}

@Model
final class Visit {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var arrivedAt: Date
    var departedAt: Date?
    var locationName: String?
    var address: String?
    var notes: String?

    // Tracking if geocoding has been attempted
    var geocodingCompleted: Bool

    // Manual confirmation/correction metadata. Optional storage keeps existing
    // SwiftData rows lightweight-migratable; computed properties below provide
    // the automatic/unconfirmed defaults for legacy visits.
    var sourceRaw: String?
    var confirmationStatusRaw: String?
    var confirmedAt: Date?
    var updatedAt: Date?

    var originalLatitude: Double?
    var originalLongitude: Double?
    var originalLocationName: String?
    var originalAddress: String?

    var detectedLatitude: Double?
    var detectedLongitude: Double?
    var detectedLocationName: String?
    var detectedAddress: String?

    var placeSourceRaw: String?
    var placeCategoryRaw: String?
    var placeDistanceMeters: Double?
    var placeConfidence: Double?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        arrivedAt: Date,
        departedAt: Date? = nil,
        locationName: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        geocodingCompleted: Bool = false,
        source: VisitSource = .automatic,
        confirmationStatus: VisitConfirmationStatus = .unconfirmed,
        confirmedAt: Date? = nil,
        updatedAt: Date? = nil,
        originalLatitude: Double? = nil,
        originalLongitude: Double? = nil,
        originalLocationName: String? = nil,
        originalAddress: String? = nil,
        detectedLatitude: Double? = nil,
        detectedLongitude: Double? = nil,
        detectedLocationName: String? = nil,
        detectedAddress: String? = nil,
        placeSource: VisitPlaceSource? = nil,
        placeCategoryRaw: String? = nil,
        placeDistanceMeters: Double? = nil,
        placeConfidence: Double? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.arrivedAt = arrivedAt
        self.departedAt = departedAt
        self.locationName = locationName
        self.address = address
        self.notes = notes
        self.geocodingCompleted = geocodingCompleted
        self.sourceRaw = source.rawValue
        self.confirmationStatusRaw = confirmationStatus.rawValue
        self.confirmedAt = confirmedAt
        self.updatedAt = updatedAt
        self.originalLatitude = originalLatitude
        self.originalLongitude = originalLongitude
        self.originalLocationName = originalLocationName
        self.originalAddress = originalAddress
        self.detectedLatitude = detectedLatitude
        self.detectedLongitude = detectedLongitude
        self.detectedLocationName = detectedLocationName
        self.detectedAddress = detectedAddress
        self.placeSourceRaw = placeSource?.rawValue
        self.placeCategoryRaw = placeCategoryRaw
        self.placeDistanceMeters = placeDistanceMeters
        self.placeConfidence = placeConfidence
    }

    var source: VisitSource {
        get { VisitSource(rawValue: sourceRaw ?? "") ?? .automatic }
        set { sourceRaw = newValue.rawValue }
    }

    var confirmationStatus: VisitConfirmationStatus {
        get { VisitConfirmationStatus(rawValue: confirmationStatusRaw ?? "") ?? .unconfirmed }
        set { confirmationStatusRaw = newValue.rawValue }
    }

    var placeSource: VisitPlaceSource? {
        get {
            guard let placeSourceRaw else { return nil }
            return VisitPlaceSource(rawValue: placeSourceRaw)
        }
        set { placeSourceRaw = newValue?.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var detectedCoordinate: CLLocationCoordinate2D? {
        guard let detectedLatitude, let detectedLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: detectedLatitude, longitude: detectedLongitude)
    }

    var originalCoordinate: CLLocationCoordinate2D? {
        guard let originalLatitude, let originalLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: originalLatitude, longitude: originalLongitude)
    }

    var canBeAutomaticallyGeocoded: Bool {
        source == .automatic && confirmationStatus == .unconfirmed
    }

    var canUndoCorrection: Bool {
        confirmationStatus == .corrected && originalLatitude != nil && originalLongitude != nil
    }

    var durationMinutes: Double? {
        guard let departedAt = departedAt else { return nil }
        return departedAt.timeIntervalSince(arrivedAt) / 60.0
    }

    var formattedDuration: String {
        guard let minutes = durationMinutes else {
            return "Still here"
        }

        if minutes < 60 {
            return "\(Int(minutes)) min"
        } else {
            let hours = Int(minutes / 60)
            let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
            if remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let arrival = formatter.string(from: arrivedAt)
        if let departedAt = departedAt {
            let departure = formatter.string(from: departedAt)
            return "\(arrival) - \(departure)"
        }
        return "\(arrival) - now"
    }

    var displayName: String {
        locationName ?? address ?? "Unknown Location"
    }

    var isCurrentVisit: Bool {
        departedAt == nil
    }

    var accessibilityLabel: String {
        if isCurrentVisit {
            return "Current visit at \(displayName)"
        }
        return "Visit at \(displayName)"
    }

    var accessibilityValue: String {
        var parts: [String] = [formattedTimeRange, formattedDuration]
        parts.append("\(source.displayName), \(confirmationStatus.displayName)")

        if let address, !address.isEmpty, address != displayName {
            parts.append(address)
        }

        parts.append(String(format: "Latitude %.4f, longitude %.4f", latitude, longitude))
        return parts.joined(separator: ". ")
    }

    var accessibilityHint: String {
        "Opens visit details."
    }

    func matchesDetectedPlace(latitude: Double, longitude: Double, toleranceMeters: Double) -> Bool {
        let target = CLLocation(latitude: latitude, longitude: longitude)
        let candidateCoordinates = [
            detectedCoordinate,
            originalCoordinate,
            coordinate
        ].compactMap { $0 }

        return candidateCoordinates.contains { candidate in
            let location = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
            return location.distance(from: target) <= toleranceMeters
        }
    }
}

extension Visit {
    static var preview: Visit {
        Visit(
            latitude: 37.7749,
            longitude: -122.4194,
            arrivedAt: Date().addingTimeInterval(-3600),
            departedAt: Date(),
            locationName: "Blue Bottle Coffee",
            address: "123 Main St, San Francisco, CA",
            geocodingCompleted: true
        )
    }

    static var currentPreview: Visit {
        Visit(
            latitude: 37.7849,
            longitude: -122.4094,
            arrivedAt: Date().addingTimeInterval(-1800),
            locationName: "Starbucks",
            address: "456 Market St, San Francisco, CA",
            geocodingCompleted: true
        )
    }
}
