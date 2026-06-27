import Foundation
import SwiftData
import CoreLocation

@Model
final class Visit {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var arrivedAt: Date
    var departedAt: Date?
    var customName: String?
    var locationName: String?
    var address: String?
    var notes: String?

    // Tracking if geocoding has been attempted
    var geocodingCompleted: Bool

    // Confirmation/correction metadata. These are optional for lightweight
    // migration: existing visits default to automatic + unconfirmed via computed
    // properties below.
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
    var placeDistanceMeters: Double?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        arrivedAt: Date,
        departedAt: Date? = nil,
        customName: String? = nil,
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
        placeDistanceMeters: Double? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.arrivedAt = arrivedAt
        self.departedAt = departedAt
        self.customName = customName
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
        self.detectedLatitude = detectedLatitude ?? (source == .automatic ? latitude : nil)
        self.detectedLongitude = detectedLongitude ?? (source == .automatic ? longitude : nil)
        self.detectedLocationName = detectedLocationName ?? (source == .automatic ? locationName : nil)
        self.detectedAddress = detectedAddress ?? (source == .automatic ? address : nil)
        self.placeSourceRaw = placeSource?.rawValue
        self.placeDistanceMeters = placeDistanceMeters
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
        get { placeSourceRaw.flatMap(VisitPlaceSource.init(rawValue:)) }
        set { placeSourceRaw = newValue?.rawValue }
    }

    var isConfirmed: Bool {
        confirmationStatus == .confirmed || confirmationStatus == .corrected
    }

    var canReceiveAutomaticGeocodeUpdates: Bool {
        source == .automatic && confirmationStatus == .unconfirmed
    }

    var originalCoordinate: CLLocationCoordinate2D? {
        guard let originalLatitude, let originalLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: originalLatitude, longitude: originalLongitude)
    }

    var detectedCoordinate: CLLocationCoordinate2D? {
        guard let detectedLatitude, let detectedLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: detectedLatitude, longitude: detectedLongitude)
    }

    func preserveOriginalValuesIfNeeded() {
        if originalLatitude == nil { originalLatitude = latitude }
        if originalLongitude == nil { originalLongitude = longitude }
        if originalLocationName == nil { originalLocationName = exportLocationName }
        if originalAddress == nil { originalAddress = address }
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

    var automaticDisplayName: String {
        locationName ?? address ?? "Unknown Location"
    }

    var normalizedCustomName: String? {
        guard let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    var displayName: String {
        normalizedCustomName ?? automaticDisplayName
    }

    var exportLocationName: String? {
        normalizedCustomName ?? locationName
    }

    var hasCustomName: Bool {
        normalizedCustomName != nil
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

        if let address, !address.isEmpty, address != displayName {
            parts.append(address)
        }

        parts.append(String(format: "Latitude %.4f, longitude %.4f", latitude, longitude))
        return parts.joined(separator: ". ")
    }

    var accessibilityHint: String {
        "Opens visit details."
    }
}

enum VisitSource: String, Codable, CaseIterable {
    case automatic
    case manual
    case imported

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .manual: return "Manual"
        case .imported: return "Imported"
        }
    }
}

enum VisitConfirmationStatus: String, Codable, CaseIterable {
    case unconfirmed
    case confirmed
    case corrected

    var displayName: String {
        switch self {
        case .unconfirmed: return "Unconfirmed"
        case .confirmed: return "Confirmed"
        case .corrected: return "Corrected"
        }
    }
}

enum VisitPlaceSource: String, Codable, CaseIterable {
    case coreLocationGeocode
    case appleMaps
    case userEntered
    case `import`

    var displayName: String {
        switch self {
        case .coreLocationGeocode: return "Core Location"
        case .appleMaps: return "Apple Maps"
        case .userEntered: return "User entered"
        case .import: return "Import"
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
