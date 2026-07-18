import XCTest
import CoreLocation
import MapKit
@testable import IsoMe

@MainActor
final class RemotePastVisitTests: XCTestCase {
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
