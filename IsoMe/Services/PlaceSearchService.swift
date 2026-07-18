import Foundation
import CoreLocation
import MapKit
import Combine

struct PlaceSearchResult: Identifiable {
    let id: String
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
}

protocol PlaceSearchServicing {
    func search(
        query: String,
        region: MKCoordinateRegion?,
        limit: Int
    ) async throws -> [PlaceSearchResult]
}

actor PlaceSearchService: PlaceSearchServicing {
    static let shared = PlaceSearchService()

    private var activeSearch: MKLocalSearch?
    private var cache: [String: [PlaceSearchResult]] = [:]

    func search(
        query: String,
        region: MKCoordinateRegion? = nil,
        limit: Int = 10
    ) async throws -> [PlaceSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= 2 else { return [] }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--seed-screenshot-data") {
            return Array(Self.demoResults.filter {
                $0.name.localizedCaseInsensitiveContains(normalizedQuery) ||
                ($0.address?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
            }.prefix(limit))
        }
        #endif

        let key = cacheKey(query: normalizedQuery, region: region)
        if let cached = cache[key] {
            return Array(cached.prefix(limit))
        }

        activeSearch?.cancel()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = normalizedQuery
        request.resultTypes = [.address, .pointOfInterest]
        if let region {
            request.region = region
        }

        let search = MKLocalSearch(request: request)
        activeSearch = search

        do {
            let response = try await withTaskCancellationHandler {
                try await search.start()
            } onCancel: {
                search.cancel()
            }

            guard !Task.isCancelled else { throw CancellationError() }

            let results = Self.makeResults(from: response.mapItems)
            cache[key] = results
            if activeSearch === search {
                activeSearch = nil
            }
            return Array(results.prefix(limit))
        } catch {
            if activeSearch === search {
                activeSearch = nil
            }
            throw error
        }
    }

    func clearCache() {
        cache.removeAll()
        activeSearch?.cancel()
        activeSearch = nil
    }

    private func cacheKey(query: String, region: MKCoordinateRegion?) -> String {
        let normalized = query.lowercased()
        guard let region else { return normalized }
        let latitude = (region.center.latitude * 100).rounded() / 100
        let longitude = (region.center.longitude * 100).rounded() / 100
        return "\(normalized)|\(latitude),\(longitude)"
    }

    private static func makeResults(from mapItems: [MKMapItem]) -> [PlaceSearchResult] {
        var seen = Set<String>()

        return mapItems.compactMap { mapItem in
            let coordinate = mapItem.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate),
                  coordinate.latitude.isFinite,
                  coordinate.longitude.isFinite else {
                return nil
            }

            let address = MapItemPlaceFormatter.formattedAddress(for: mapItem)
            let trimmedName = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (trimmedName?.isEmpty == false ? trimmedName : nil) ?? address
            guard let name, !name.isEmpty else { return nil }

            let id = resultID(name: name, coordinate: coordinate)
            guard seen.insert(id).inserted else { return nil }

            return PlaceSearchResult(
                id: id,
                name: name,
                address: address,
                coordinate: coordinate
            )
        }
    }

    private static func resultID(name: String, coordinate: CLLocationCoordinate2D) -> String {
        let latitude = Int((coordinate.latitude * 100_000).rounded())
        let longitude = Int((coordinate.longitude * 100_000).rounded())
        return "\(name.lowercased())-\(latitude)-\(longitude)"
    }

    #if DEBUG
    private static let demoResults: [PlaceSearchResult] = [
        PlaceSearchResult(
            id: "demo-tartine",
            name: "Tartine Bakery",
            address: "600 Guerrero St, San Francisco, CA 94110",
            coordinate: CLLocationCoordinate2D(latitude: 37.7614, longitude: -122.4240)
        ),
        PlaceSearchResult(
            id: "demo-ferry-building",
            name: "Ferry Building Marketplace",
            address: "1 Ferry Building, San Francisco, CA 94111",
            coordinate: CLLocationCoordinate2D(latitude: 37.7955, longitude: -122.3937)
        )
    ]
    #endif
}

enum MapItemPlaceFormatter {
    static func formattedAddress(for mapItem: MKMapItem) -> String? {
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

        let mapItemName = mapItem.name ?? ""
        let fallback = placemark.title?.replacingOccurrences(of: "\(mapItemName), ", with: "")
        guard let fallback, !fallback.isEmpty, fallback != mapItemName else {
            return nil
        }
        return fallback
    }
}

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [PlaceSearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    private let service: any PlaceSearchServicing
    private let debounceNanoseconds: UInt64
    private var searchTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(
        service: any PlaceSearchServicing = PlaceSearchService.shared,
        debounceNanoseconds: UInt64 = 300_000_000
    ) {
        self.service = service
        self.debounceNanoseconds = debounceNanoseconds
    }

    func queryChanged(region: MKCoordinateRegion?) {
        scheduleSearch(region: region, waitsForDebounce: true)
    }

    func submit(region: MKCoordinateRegion?) {
        scheduleSearch(region: region, waitsForDebounce: false)
    }

    func clear() {
        requestGeneration += 1
        searchTask?.cancel()
        searchTask = nil
        results = []
        errorMessage = nil
        isSearching = false
    }

    private func scheduleSearch(region: MKCoordinateRegion?, waitsForDebounce: Bool) {
        requestGeneration += 1
        let generation = requestGeneration
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        errorMessage = nil

        searchTask = Task { [weak self] in
            guard let self else { return }

            do {
                if waitsForDebounce, debounceNanoseconds > 0 {
                    try await Task.sleep(nanoseconds: debounceNanoseconds)
                }
                let newResults = try await service.search(
                    query: trimmedQuery,
                    region: region,
                    limit: 10
                )
                try Task.checkCancellation()
                guard generation == requestGeneration else { return }
                results = newResults
                isSearching = false
            } catch is CancellationError {
                // A newer query or dismissal superseded this request.
            } catch {
                guard generation == requestGeneration else { return }
                results = []
                isSearching = false
                errorMessage = String(localized: "Apple Maps search is unavailable right now. Please try again.")
            }
        }
    }

    deinit {
        searchTask?.cancel()
    }
}
