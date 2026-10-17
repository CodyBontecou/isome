import CoreLocation
import Foundation
import MapKit
import UIKit

enum VisitMapOpener {
    static func navigationURL(for coordinate: CLLocationCoordinate2D) -> URL? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

        var components = URLComponents()
        components.scheme = "geo-navigation"
        components.host = ""
        components.path = "/place"
        components.queryItems = [
            URLQueryItem(name: "coordinate", value: "\(coordinate.latitude),\(coordinate.longitude)")
        ]
        return components.url
    }

    @MainActor
    @discardableResult
    static func open(coordinate: CLLocationCoordinate2D, name: String) async -> Bool {
        let supportsDefaultNavigation: Bool
        if #available(iOS 18.4, *) {
            supportsDefaultNavigation = true
        } else {
            supportsDefaultNavigation = false
        }

        return await open(
            coordinate: coordinate,
            name: name,
            supportsDefaultNavigation: supportsDefaultNavigation,
            openDefaultNavigation: { url in
                await withCheckedContinuation { continuation in
                    UIApplication.shared.open(url, options: [:]) { didOpen in
                        continuation.resume(returning: didOpen)
                    }
                }
            },
            openAppleMaps: { coordinate, name in
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                mapItem.name = name
                return mapItem.openInMaps(launchOptions: nil)
            }
        )
    }

    @MainActor
    static func open(
        coordinate: CLLocationCoordinate2D,
        name: String,
        supportsDefaultNavigation: Bool,
        openDefaultNavigation: @MainActor (URL) async -> Bool,
        openAppleMaps: @MainActor (CLLocationCoordinate2D, String) -> Bool
    ) async -> Bool {
        guard let url = navigationURL(for: coordinate) else { return false }

        if supportsDefaultNavigation, await openDefaultNavigation(url) {
            return true
        }

        return openAppleMaps(coordinate, name)
    }
}
