import XCTest
import CoreLocation
import MapKit
@testable import IsoMe

@MainActor
final class RemotePastVisitTests: XCTestCase {
    func testNetworkOptOutBlocksAllPlaceLookupServicesAndViewModel() async throws {
        let previous = UserDefaults.standard.object(forKey: "allowNetworkGeocoding")
        defer { UserDefaults.standard.set(previous, forKey: "allowNetworkGeocoding") }
        UserDefaults.standard.set(false, forKey: "allowNetworkGeocoding")
        let stub = PlaceSearchStub()
        let model = PlaceSearchViewModel(service: stub, debounceNanoseconds: 0)
        model.query = "Cafe"
        model.submit(region: nil)
        XCTAssertTrue(stub.queries.isEmpty)
        XCTAssertTrue(model.results.isEmpty)
        XCTAssertNotNil(model.errorMessage)
        do {
            _ = try await PlaceSearchService().search(query: "Cafe")
            XCTFail("Text search ignored opt-out")
        } catch { XCTAssertTrue(error is NetworkGeocodingPolicy.LookupError) }
        do {
            _ = try await NearbyPlaceSearchService().suggestions(near: CLLocationCoordinate2D(latitude: 1, longitude: 2))
            XCTFail("Nearby search ignored opt-out")
        } catch { XCTAssertTrue(error is NetworkGeocodingPolicy.LookupError) }
        do {
            _ = try await GeocodingService().reverseGeocode(location: CLLocation(latitude: 1, longitude: 2))
            XCTFail("Pin lookup ignored opt-out")
        } catch { XCTAssertTrue(error is NetworkGeocodingPolicy.LookupError) }
    }

    func testDisablingNetworkDuringSearchDiscardsTheResponse() async throws {
        let previous = UserDefaults.standard.object(forKey: "allowNetworkGeocoding")
        defer { UserDefaults.standard.set(previous, forKey: "allowNetworkGeocoding") }
        UserDefaults.standard.set(true, forKey: "allowNetworkGeocoding")
        let started = expectation(description: "Search started")
        let stub = PlaceSearchStub(onSlowRequestStarted: { started.fulfill() })
        let model = PlaceSearchViewModel(service: stub, debounceNanoseconds: 0)
        model.query = "slow"
        model.submit(region: nil)
        await fulfillment(of: [started], timeout: 1)
        UserDefaults.standard.set(false, forKey: "allowNetworkGeocoding")
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(model.results.isEmpty)
        XCTAssertFalse(model.isSearching)
        XCTAssertNotNil(model.errorMessage)
    }

    func testSavedCurrentVisitExtendsExpiredMapRange() {
        let start = Date(timeIntervalSince1970: 1000)
        let previousEnd = start.addingTimeInterval(60)
        let savedArrival = previousEnd.addingTimeInterval(30)
        let range = LocationMapView.rangeIncludingSavedVisit(savedArrival, in: start...previousEnd)
        XCTAssertTrue(range.contains(savedArrival))
        XCTAssertEqual(range.lowerBound, start)
        XCTAssertEqual(range.upperBound, savedArrival)
        XCTAssertEqual(LocationMapView.rangeIncludingSavedVisit(start, in: range), range)
    }

    func testVisitMarkerStatesDistinguishManualAndCorrectionStatus() {
        let visit = Visit(latitude: 1, longitude: 2, arrivedAt: Date())
        XCTAssertEqual(VisitMarkerState(visit: visit), .unconfirmed)
        visit.confirmationStatus = .confirmed
        XCTAssertEqual(VisitMarkerState(visit: visit), .confirmed)
        visit.confirmationStatus = .corrected
        XCTAssertEqual(VisitMarkerState(visit: visit), .corrected)
        visit.source = .manual
        XCTAssertEqual(VisitMarkerState(visit: visit), .manual)
        XCTAssertEqual(Set(VisitMarkerState.allCases.map(\.symbol)).count, 4)
    }

    func testNearbyRankingIsDeterministicAndRemovesDuplicatePlaces() {
        let origin = CLLocation(latitude: 1, longitude: 2)
        func item(_ name: String, _ latitude: Double) -> MKMapItem {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 2)))
            item.name = name
            return item
        }
        let items = [item("Far", 1.001), item("Zulu", 1), item("Alpha", 1), item("Alpha", 1), item("Outside", 2)]
        let results = NearbyPlaceSearchService.makeSuggestions(from: items, origin: origin, radius: 200)
        XCTAssertEqual(results.map(\.name), ["Alpha", "Zulu", "Far"])
    }

    func testTextSearchRanksNameCategoryAndDistanceDeterministically() {
        func item(_ name: String, _ latitude: Double, category: MKPointOfInterestCategory? = nil) -> MKMapItem {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 2)))
            item.name = name
            item.pointOfInterestCategory = category
            return item
        }
        let items = [item("Other", 1), item("Far Cafe", 1.002), item("Near Cafe", 1.001),
                     item("Cafe", 1.003), item("Bakery", 1, category: .cafe)]
        let results = PlaceSearchService.makeResults(from: items, query: "cafe", center: CLLocationCoordinate2D(latitude: 1, longitude: 2))
        XCTAssertEqual(results.map(\.name), ["Cafe", "Near Cafe", "Far Cafe", "Bakery", "Other"])
    }

    func testPastVisitNeverFallsBackToCurrentLocation() throws {
        let currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)

        XCTAssertFalse(ManualVisitMode.addPastVisit.requestsCurrentLocation)
        XCTAssertTrue(ManualVisitMode.addPlaceManually.requestsCurrentLocation)
        XCTAssertTrue(ManualVisitMode.saveCurrentPlace.requestsCurrentLocation)
        XCTAssertNil(
            ManualVisitMode.addPastVisit.resolvedCoordinate(
                selection: nil,
                currentLocation: currentLocation
            )
        )

        let currentCoordinate = try XCTUnwrap(ManualVisitMode.addPlaceManually.resolvedCoordinate(
            selection: nil,
            currentLocation: currentLocation
        ))
        XCTAssertEqual(currentCoordinate.latitude, currentLocation.coordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(currentCoordinate.longitude, currentLocation.coordinate.longitude, accuracy: 0.000_001)
    }

    func testPastVisitUsesExplicitRemoteSelectionInsteadOfCurrentLocation() throws {
        let currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let remoteCoordinate = CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.2945)
        let selection = ManualLocationSelection(
            name: "Eiffel Tower",
            address: "5 Avenue Anatole France, Paris",
            coordinate: remoteCoordinate,
            source: .appleMaps
        )

        let resolved = try XCTUnwrap(
            ManualVisitMode.addPastVisit.resolvedCoordinate(
                selection: selection,
                currentLocation: currentLocation
            )
        )

        XCTAssertEqual(resolved.latitude, remoteCoordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(resolved.longitude, remoteCoordinate.longitude, accuracy: 0.000_001)
        XCTAssertEqual(selection.visitPlaceSource, .appleMaps)
    }

    func testEditingSelectionMetadataKeepsCoordinateAndChangesProvenance() {
        let coordinate = CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.2945)
        var selection = ManualLocationSelection(
            name: "Eiffel Tower",
            address: "Paris",
            coordinate: coordinate,
            source: .appleMaps
        )

        selection.updateUserEnteredMetadata(
            name: "Dinner near the tower",
            address: "Personal note"
        )

        XCTAssertEqual(selection.name, "Dinner near the tower")
        XCTAssertEqual(selection.address, "Personal note")
        XCTAssertEqual(selection.coordinate.latitude, coordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(selection.coordinate.longitude, coordinate.longitude, accuracy: 0.000_001)
        XCTAssertEqual(selection.visitPlaceSource, .userEntered)
    }

    func testSavedLocationIsAValidRemoteSelection() {
        let place = SavedPlace(
            name: "Home",
            latitude: 40.7128,
            longitude: -74.0060,
            address: "New York, NY"
        )

        let selection = ManualLocationSelection.savedPlace(place)

        XCTAssertEqual(selection.savedPlaceID, place.id)
        XCTAssertEqual(selection.name, "Home")
        XCTAssertEqual(selection.coordinate.latitude, 40.7128, accuracy: 0.000_001)
        XCTAssertEqual(selection.coordinate.longitude, -74.0060, accuracy: 0.000_001)
        XCTAssertEqual(selection.visitPlaceSource, .userEntered)
    }

    func testSearchViewModelIgnoresSupersededResults() async throws {
        let slowRequestStarted = expectation(description: "Slow request started")
        let service = PlaceSearchStub(onSlowRequestStarted: {
            slowRequestStarted.fulfill()
        })
        let viewModel = PlaceSearchViewModel(service: service, debounceNanoseconds: 0)

        viewModel.query = "slow"
        viewModel.submit(region: nil)
        await fulfillment(of: [slowRequestStarted], timeout: 1)

        viewModel.query = "fast"
        viewModel.submit(region: nil)

        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.results.map(\.name), ["Fast Result"])
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSearchViewModelClearsShortQueriesWithoutSearching() async throws {
        let service = PlaceSearchStub()
        let viewModel = PlaceSearchViewModel(service: service, debounceNanoseconds: 0)

        viewModel.query = "a"
        viewModel.submit(region: nil)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(service.queries, [])
    }
}

private final class PlaceSearchStub: PlaceSearchServicing {
    private(set) var queries: [String] = []
    private let onSlowRequestStarted: (() -> Void)?

    init(onSlowRequestStarted: (() -> Void)? = nil) {
        self.onSlowRequestStarted = onSlowRequestStarted
    }

    func search(
        query: String,
        region: MKCoordinateRegion?,
        limit: Int
    ) async throws -> [PlaceSearchResult] {
        queries.append(query)

        if query == "slow" {
            onSlowRequestStarted?()
            // Deliberately ignore cancellation so the view model's generation guard
            // is responsible for rejecting this stale response.
            try? await Task.sleep(nanoseconds: 120_000_000)
            return [Self.result(name: "Slow Result", latitude: 1, longitude: 1)]
        }

        try? await Task.sleep(nanoseconds: 10_000_000)
        return [Self.result(name: "Fast Result", latitude: 2, longitude: 2)]
    }

    private static func result(
        name: String,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees
    ) -> PlaceSearchResult {
        PlaceSearchResult(
            id: name,
            name: name,
            address: nil,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }
}
