import Foundation
import CoreLocation
import MapKit

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

struct NearbyPlaceSuggestion: Identifiable {
    let id: String
    let name: String
    let address: String?
    let distanceMeters: CLLocationDistance

    var distanceLabel: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distanceMeters)
    }
}

actor NearbyPlaceSearchService {
    static let shared = NearbyPlaceSearchService()

    private var cache: [String: [NearbyPlaceSuggestion]] = [:]
    private var pendingRequests: [String: Task<[NearbyPlaceSuggestion], Error>] = [:]
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 0.5
    private let defaultSearchRadius: CLLocationDistance = 1_000

    private static let businessPointOfInterestCategories: [MKPointOfInterestCategory] = [
        .restaurant,
        .cafe,
        .bakery,
        .brewery,
        .foodMarket,
        .store,
        .hotel,
        .nightlife,
        .pharmacy,
        .bank,
        .atm,
        .gasStation,
        .fitnessCenter,
        .laundry,
        .movieTheater,
        .theater,
        .winery,
        .carRental,
        .evCharger
    ]

    private static let fallbackBusinessQueries = [
        "restaurant",
        "coffee",
        "bar",
        "hotel",
        "shop"
    ]

    func suggestions(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance? = nil,
        limit: Int = 8
    ) async throws -> [NearbyPlaceSuggestion] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--seed-screenshot-data") {
            return Array(Self.demoSuggestions(near: coordinate).prefix(limit))
        }
        #endif

        let searchRadius = min(radius ?? defaultSearchRadius, MKLocalPointsOfInterestRequest.maxRadius)
        let key = cacheKey(for: coordinate, radius: searchRadius)

        if let cached = cache[key] {
            return Array(cached.prefix(limit))
        }

        if let pending = pendingRequests[key] {
            let suggestions = try await pending.value
            return Array(suggestions.prefix(limit))
        }

        let task = Task<[NearbyPlaceSuggestion], Error> {
            if let lastTime = lastRequestTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                if elapsed < minimumRequestInterval {
                    try await Task.sleep(nanoseconds: UInt64((minimumRequestInterval - elapsed) * 1_000_000_000))
                }
            }

            lastRequestTime = Date()

            let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let businessFilter = MKPointOfInterestFilter(including: Self.businessPointOfInterestCategories)
            var mapItems = try await Self.searchMapItems(
                near: coordinate,
                radius: searchRadius,
                pointOfInterestFilter: businessFilter
            )

            var suggestions = Self.makeSuggestions(from: mapItems, origin: origin, radius: searchRadius)

            if suggestions.isEmpty {
                mapItems = try await Self.searchMapItems(
                    near: coordinate,
                    radius: searchRadius,
                    pointOfInterestFilter: nil
                )
                suggestions = Self.makeSuggestions(from: mapItems, origin: origin, radius: searchRadius)
            }

            if suggestions.isEmpty {
                var fallbackMapItems: [MKMapItem] = []
                for query in Self.fallbackBusinessQueries {
                    let results = try await Self.searchMapItems(
                        near: coordinate,
                        radius: searchRadius,
                        naturalLanguageQuery: query
                    )
                    fallbackMapItems.append(contentsOf: results)
                }
                suggestions = Self.makeSuggestions(from: fallbackMapItems, origin: origin, radius: searchRadius)
            }

            cache[key] = suggestions
            return suggestions
        }

        pendingRequests[key] = task

        do {
            let suggestions = try await task.value
            pendingRequests.removeValue(forKey: key)
            return Array(suggestions.prefix(limit))
        } catch {
            pendingRequests.removeValue(forKey: key)
            throw error
        }
    }

    func clearCache() {
        cache.removeAll()
        pendingRequests.removeAll()
    }

    #if DEBUG
    private static func demoSuggestions(near coordinate: CLLocationCoordinate2D) -> [NearbyPlaceSuggestion] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let places: [(name: String, address: String, latitude: Double, longitude: Double)] = [
            ("Four Barrel Coffee", "375 Valencia St, San Francisco, CA", 37.7670, -122.4219),
            ("Tartine Bakery", "600 Guerrero St, San Francisco, CA", 37.7614, -122.4240),
            ("The Grove", "690 Mission St, San Francisco, CA", 37.7867, -122.4027),
            ("Ferry Building Marketplace", "1 Ferry Building, San Francisco, CA", 37.7955, -122.3937),
            ("Ritual Coffee Roasters", "1026 Valencia St, San Francisco, CA", 37.7564, -122.4210),
            ("Dolores Park Café", "501 Dolores St, San Francisco, CA", 37.7601, -122.4268)
        ]

        return places.map { place in
            let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return NearbyPlaceSuggestion(
                id: "demo-\(place.name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                name: place.name,
                address: place.address,
                distanceMeters: origin.distance(from: location)
            )
        }
        .sorted { $0.distanceMeters < $1.distanceMeters }
    }
    #endif

    private func cacheKey(for coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) -> String {
        // Round to ~11 meter precision to reuse searches for adjacent visits.
        let lat = (coordinate.latitude * 10000).rounded() / 10000
        let lon = (coordinate.longitude * 10000).rounded() / 10000
        return "\(lat),\(lon),\(Int(radius.rounded()))"
    }

    private static func searchMapItems(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        pointOfInterestFilter: MKPointOfInterestFilter?
    ) async throws -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: radius)
        request.pointOfInterestFilter = pointOfInterestFilter
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems
    }

    private static func searchMapItems(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        naturalLanguageQuery: String
    ) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = naturalLanguageQuery
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        request.resultTypes = .pointOfInterest
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems
    }

    private static func makeSuggestions(
        from mapItems: [MKMapItem],
        origin: CLLocation,
        radius: CLLocationDistance
    ) -> [NearbyPlaceSuggestion] {
        var seenNames = Set<String>()

        return mapItems.compactMap { mapItem -> NearbyPlaceSuggestion? in
            guard let name = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                return nil
            }

            let normalizedName = name.lowercased()
            guard !seenNames.contains(normalizedName) else {
                return nil
            }

            let destination = CLLocation(
                latitude: mapItem.placemark.coordinate.latitude,
                longitude: mapItem.placemark.coordinate.longitude
            )
            let distance = origin.distance(from: destination)
            guard distance <= radius * 1.2 else {
                return nil
            }

            seenNames.insert(normalizedName)

            return NearbyPlaceSuggestion(
                id: suggestionID(for: name, coordinate: mapItem.placemark.coordinate),
                name: name,
                address: formattedAddress(for: mapItem),
                distanceMeters: distance
            )
        }
        .sorted { lhs, rhs in
            if lhs.distanceMeters == rhs.distanceMeters {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.distanceMeters < rhs.distanceMeters
        }
    }

    private static func suggestionID(for name: String, coordinate: CLLocationCoordinate2D) -> String {
        let lat = Int((coordinate.latitude * 100_000).rounded())
        let lon = Int((coordinate.longitude * 100_000).rounded())
        return "\(name.lowercased())-\(lat)-\(lon)"
    }

    private static func formattedAddress(for mapItem: MKMapItem) -> String? {
        let placemark = mapItem.placemark
        var components: [String] = []

        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            components.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }

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

        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }

        if !components.isEmpty {
            return components.joined(separator: ", ")
        }

        let name = mapItem.name ?? ""
        let fallback = placemark.title?.replacingOccurrences(of: "\(name), ", with: "")
        guard let fallback, !fallback.isEmpty, fallback != name else {
            return nil
        }
        return fallback
    }
}
