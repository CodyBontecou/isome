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
    var locationName: String?
    var address: String?
    var notes: String?

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
