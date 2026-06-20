import Foundation
import SwiftData
import CoreLocation

enum PhotoMomentCoordinateSource: String, Codable, CaseIterable {
    case photoGPS = "photo_gps"
    case inferredFromRoute = "inferred_route"
    case inferredFromVisit = "inferred_visit"

    var displayName: String {
        switch self {
        case .photoGPS:
            return "Photo GPS"
        case .inferredFromRoute:
            return "Inferred from route"
        case .inferredFromVisit:
            return "Inferred from visit"
        }
    }
}

@Model
final class PhotoMoment {
    var id: UUID
    var assetLocalIdentifier: String
    var takenAt: Date
    var latitude: Double
    var longitude: Double
    var coordinateSourceRawValue: String
    var lastSyncedAt: Date

    init(
        id: UUID = UUID(),
        assetLocalIdentifier: String,
        takenAt: Date,
        latitude: Double,
        longitude: Double,
        coordinateSource: PhotoMomentCoordinateSource = .photoGPS,
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.assetLocalIdentifier = assetLocalIdentifier
        self.takenAt = takenAt
        self.latitude = latitude
        self.longitude = longitude
        self.coordinateSourceRawValue = coordinateSource.rawValue
        self.lastSyncedAt = lastSyncedAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var coordinateSource: PhotoMomentCoordinateSource {
        get { PhotoMomentCoordinateSource(rawValue: coordinateSourceRawValue) ?? .photoGPS }
        set { coordinateSourceRawValue = newValue.rawValue }
    }

    var formattedTakenTime: String {
        takenAt.formatted(date: .abbreviated, time: .shortened)
    }

    var accessibilityLabel: String {
        "Photo taken at \(formattedTakenTime)"
    }

    var accessibilityValue: String {
        [
            coordinateSource.displayName,
            String(format: "Latitude %.4f, longitude %.4f", latitude, longitude)
        ].joined(separator: ". ")
    }
}

struct PhotoAssetMetadata: Identifiable, Equatable {
    var id: String { assetLocalIdentifier }

    let assetLocalIdentifier: String
    let takenAt: Date
    let latitude: Double
    let longitude: Double
    let coordinateSource: PhotoMomentCoordinateSource

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
