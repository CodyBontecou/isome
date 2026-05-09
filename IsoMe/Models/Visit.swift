import Foundation
import SwiftData
import CoreLocation

enum TripPurpose: String, Codable, CaseIterable, Identifiable {
    case business
    case personal
    case commuting
    case unclassified

    var id: String { rawValue }

    var label: String {
        switch self {
        case .business: return "Business"
        case .personal: return "Personal"
        case .commuting: return "Commuting"
        case .unclassified: return "Unclassified"
        }
    }

    var iconName: String {
        switch self {
        case .business: return "briefcase.fill"
        case .personal: return "person.fill"
        case .commuting: return "car.fill"
        case .unclassified: return "questionmark.circle.fill"
        }
    }
}

typealias TripClassification = TripPurpose

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
    var purposeRawValue: String = TripPurpose.unclassified.rawValue
    var subPurpose: String? = nil
    var businessPurpose: String? = nil
    var businessSubPurpose: String? = nil
    var vehicleID: UUID?
    var vehicleName: String?
    var vehicleDetectionSource: String?
    var vehicleBluetoothPortName: String?

    // Tracking if geocoding has been attempted
    var geocodingCompleted: Bool

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        arrivedAt: Date,
        departedAt: Date? = nil,
        locationName: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        purpose: TripPurpose = .unclassified,
        subPurpose: String? = nil,
        tripClassificationRaw: String? = nil,
        businessPurpose: String? = nil,
        businessSubPurpose: String? = nil,
        vehicleID: UUID? = nil,
        vehicleName: String? = nil,
        vehicleDetectionSource: String? = nil,
        vehicleBluetoothPortName: String? = nil,
        geocodingCompleted: Bool = false
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.arrivedAt = arrivedAt
        self.departedAt = departedAt
        self.locationName = locationName
        self.address = address
        self.notes = notes
        let resolvedPurpose = tripClassificationRaw.flatMap(TripPurpose.init(rawValue:)) ?? purpose
        self.purposeRawValue = resolvedPurpose.rawValue
        self.subPurpose = subPurpose ?? businessSubPurpose
        self.businessPurpose = businessPurpose
        self.businessSubPurpose = businessSubPurpose
        self.vehicleID = vehicleID
        self.vehicleName = vehicleName
        self.vehicleDetectionSource = vehicleDetectionSource
        self.vehicleBluetoothPortName = vehicleBluetoothPortName
        self.geocodingCompleted = geocodingCompleted
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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

    var purpose: TripPurpose {
        get { TripPurpose(rawValue: purposeRawValue) ?? .unclassified }
        set {
            purposeRawValue = newValue.rawValue
            if newValue != .business {
                subPurpose = nil
                businessPurpose = nil
                businessSubPurpose = nil
            }
        }
    }

    var tripClassification: TripClassification {
        get { purpose }
        set { purpose = newValue }
    }

    var isVehicleAutoDetected: Bool {
        vehicleDetectionSource == "bluetooth"
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
