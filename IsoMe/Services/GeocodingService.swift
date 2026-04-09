import Foundation
import CoreLocation

struct GeocodingResult {
    let name: String?
    let address: String?
}

actor GeocodingService {
    private let geocoder = CLGeocoder()
    private var cache: [String: GeocodingResult] = [:]
    private var pendingRequests: [String: Task<GeocodingResult, Error>] = [:]

    // Rate limiting
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 0.5 // 500ms between requests

    private func cacheKey(for location: CLLocation) -> String {
        // Round to ~11 meter precision to group nearby locations
        let lat = (location.coordinate.latitude * 10000).rounded() / 10000
        let lon = (location.coordinate.longitude * 10000).rounded() / 10000
        return "\(lat),\(lon)"
    }

    func reverseGeocode(location: CLLocation) async throws -> GeocodingResult {
        let key = cacheKey(for: location)

        // Check cache first
        if let cached = cache[key] {
            return cached
        }

        // Check if there's already a pending request for this location
        if let pending = pendingRequests[key] {
            return try await pending.value
        }

        // Create a new request task
        let task = Task<GeocodingResult, Error> {
            // Rate limiting
            if let lastTime = lastRequestTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                if elapsed < minimumRequestInterval {
                    try await Task.sleep(nanoseconds: UInt64((minimumRequestInterval - elapsed) * 1_000_000_000))
                }
            }

            lastRequestTime = Date()

            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            guard let placemark = placemarks.first else {
                let result = GeocodingResult(name: nil, address: nil)
                cache[key] = result
                return result
            }

            let result = GeocodingResult(
                name: extractPlaceName(from: placemark),
                address: formatAddress(from: placemark)
            )

            cache[key] = result
            return result
        }

        pendingRequests[key] = task

        do {
            let result = try await task.value
            pendingRequests.removeValue(forKey: key)
            return result
        } catch {
            pendingRequests.removeValue(forKey: key)
            throw error
        }
    }

    private func extractPlaceName(from placemark: CLPlacemark) -> String? {
        // Try to get a meaningful place name
        if let name = placemark.name,
           !name.isEmpty,
           name != placemark.thoroughfare,
           !name.contains(placemark.subThoroughfare ?? "NONE") {
            return name
        }

        // Fallback to area of interest
        if let areasOfInterest = placemark.areasOfInterest, let first = areasOfInterest.first {
            return first
        }

        // Use neighborhood or sublocality
        if let neighborhood = placemark.subLocality {
            return neighborhood
        }

        return nil
    }

    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        // Street address
        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            components.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }

        // City, State
        var cityState: [String] = []
        if let city = placemark.locality {
            cityState.append(city)
        }
        if let state = placemark.administrativeArea {
            cityState.append(state)
        }
        if !cityState.isEmpty {
            components.append(cityState.joined(separator: ", "))
        }

        // Postal code
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }

        return components.joined(separator: ", ")
    }

    func clearCache() {
        cache.removeAll()
    }
}
