import Foundation
import SwiftData
import CoreLocation

@Model
final class LocationPoint {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var altitude: Double?
    var speed: Double?
    var horizontalAccuracy: Double

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        altitude: Double? = nil,
        speed: Double? = nil,
        horizontalAccuracy: Double
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.altitude = altitude
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
    }

    convenience init(from location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            altitude: location.altitude,
            speed: location.speed >= 0 ? location.speed : nil,
            horizontalAccuracy: location.horizontalAccuracy
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: LocationPoint) -> Double {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }
}

extension LocationPoint {
    static var preview: LocationPoint {
        LocationPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: Date(),
            altitude: 10.0,
            speed: 1.5,
            horizontalAccuracy: 5.0
        )
    }
}
