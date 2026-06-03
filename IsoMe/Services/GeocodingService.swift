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

struct PlaceCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let source: VisitPlaceSource
    let categoryRaw: String?
    let distanceMeters: Double?
    let confidence: Double

    init(
        id: String? = nil,
        name: String,
        address: String? = nil,
        latitude: Double,
        longitude: Double,
        source: VisitPlaceSource = .appleMaps,
        categoryRaw: String? = nil,
        distanceMeters: Double? = nil,
        confidence: Double = 0
    ) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
        self.categoryRaw = categoryRaw
        self.distanceMeters = distanceMeters
        self.confidence = confidence
        self.id = id ?? "\(source.rawValue):\(latitude.roundedForPlaceID):\(longitude.roundedForPlaceID):\(name.lowercased())"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var placeUpdate: VisitPlaceUpdate {
        VisitPlaceUpdate(
            latitude: latitude,
            longitude: longitude,
            locationName: name,
            address: address,
            placeSource: source,
            placeCategoryRaw: categoryRaw,
            placeDistanceMeters: distanceMeters,
            placeConfidence: confidence
        )
    }

    static func custom(
        name: String,
        coordinate: CLLocationCoordinate2D,
        around referenceCoordinate: CLLocationCoordinate2D
    ) -> PlaceCandidate {
        let distance = CLLocation(latitude: referenceCoordinate.latitude, longitude: referenceCoordinate.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))

        return PlaceCandidate(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            source: .userEntered,
            distanceMeters: distance,
            confidence: 0.5
        )
    }

    static func ranked(
        _ candidates: [PlaceCandidate],
        around coordinate: CLLocationCoordinate2D,
        query: String?
    ) -> [PlaceCandidate] {
        let reference = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let normalizedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return candidates
            .map { candidate -> PlaceCandidate in
                let distance = candidate.distanceMeters ?? reference.distance(
                    from: CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
                )
                let distanceScore = max(0, 0.5 - min(distance, 1_000) / 2_000)
                let queryScore: Double = {
                    guard let normalizedQuery, !normalizedQuery.isEmpty else { return 0 }
                    let name = candidate.name.lowercased()
                    let category = candidate.categoryRaw?.lowercased() ?? ""
                    if name == normalizedQuery { return 0.6 }
                    if name.contains(normalizedQuery) { return 0.45 }
                    if category.contains(normalizedQuery) { return 0.25 }
                    return 0
                }()
                let categoryScore = candidate.categoryRaw == nil ? 0 : 0.05
                let confidence = min(1, max(candidate.confidence, distanceScore + queryScore + categoryScore))

                return PlaceCandidate(
                    id: candidate.id,
                    name: candidate.name,
                    address: candidate.address,
                    latitude: candidate.latitude,
                    longitude: candidate.longitude,
                    source: candidate.source,
                    categoryRaw: candidate.categoryRaw,
                    distanceMeters: distance,
                    confidence: confidence
                )
            }
            .sorted {
                if $0.confidence == $1.confidence {
                    if ($0.distanceMeters ?? .greatestFiniteMagnitude) == ($1.distanceMeters ?? .greatestFiniteMagnitude) {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    return ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude)
                }
                return $0.confidence > $1.confidence
            }
    }
}

protocol PlaceSearching {
    func search(
        near coordinate: CLLocationCoordinate2D,
        query: String?,
        allowNetworkGeocoding: Bool
    ) async throws -> [PlaceCandidate]
}

final class PlaceSearchService: PlaceSearching {
    private var cache: [String: [PlaceCandidate]] = [:]

    func search(
        near coordinate: CLLocationCoordinate2D,
        query: String?,
        allowNetworkGeocoding: Bool
    ) async throws -> [PlaceCandidate] {
        guard allowNetworkGeocoding else { return [] }

        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = cacheKey(for: coordinate, query: trimmedQuery)
        if let cached = cache[key] {
            return cached
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery?.isEmpty == false ? trimmedQuery : "point of interest"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 800,
            longitudinalMeters: 800
        )

        let response = try await MKLocalSearch(request: request).start()
        let reference = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let candidates = response.mapItems.compactMap { item -> PlaceCandidate? in
            let itemCoordinate = item.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(itemCoordinate) else { return nil }
            let name = item.name ?? item.placemark.name ?? item.placemark.title
            guard let name, !name.isEmpty else { return nil }

            let distance = reference.distance(from: CLLocation(latitude: itemCoordinate.latitude, longitude: itemCoordinate.longitude))
            return PlaceCandidate(
                name: name,
                address: Self.formattedAddress(from: item.placemark),
                latitude: itemCoordinate.latitude,
                longitude: itemCoordinate.longitude,
                source: .appleMaps,
                categoryRaw: item.pointOfInterestCategory?.rawValue,
                distanceMeters: distance
            )
        }

        let ranked = PlaceCandidate.ranked(candidates, around: coordinate, query: trimmedQuery)
        cache[key] = ranked
        return ranked
    }

    func clearCache() {
        cache.removeAll()
    }

    private func cacheKey(for coordinate: CLLocationCoordinate2D, query: String?) -> String {
        let lat = (coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (coordinate.longitude * 10_000).rounded() / 10_000
        let queryKey = query?.lowercased() ?? ""
        return "\(lat),\(lon),\(queryKey)"
    }

    private static func formattedAddress(from placemark: MKPlacemark) -> String? {
        let pieces = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        guard !pieces.isEmpty else { return placemark.title }
        return pieces.joined(separator: ", ")
    }
}

private extension Double {
    var roundedForPlaceID: String {
        String(format: "%.6f", self)
    }
}
