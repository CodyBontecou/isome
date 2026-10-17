import CoreLocation
import XCTest
@testable import IsoMe

final class VisitMapOpenerTests: XCTestCase {
    private let coordinate = CLLocationCoordinate2D(latitude: 38.7223, longitude: -9.1393)

    func testNavigationURLDisplaysTheCoordinateWithoutStartingDirections() throws {
        let url = try XCTUnwrap(VisitMapOpener.navigationURL(for: coordinate))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "geo-navigation")
        XCTAssertEqual(components.host, "")
        XCTAssertEqual(components.path, "/place")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "coordinate", value: "38.7223,-9.1393")])
        XCTAssertEqual(url.absoluteString, "geo-navigation:///place?coordinate=38.7223,-9.1393")
    }

    func testNavigationURLRejectsInvalidAndNonFiniteCoordinates() {
        let invalidCoordinates = [
            CLLocationCoordinate2D(latitude: 90.1, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: -180.1),
            CLLocationCoordinate2D(latitude: .infinity, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: .nan)
        ]

        for coordinate in invalidCoordinates {
            XCTAssertNil(VisitMapOpener.navigationURL(for: coordinate))
        }
    }

    @MainActor
    func testSuccessfulDefaultNavigationDoesNotAlsoOpenAppleMaps() async {
        var defaultURLs: [URL] = []
        var appleMapsCalls = 0

        let didOpen = await VisitMapOpener.open(
            coordinate: coordinate,
            name: "Lisbon",
            supportsDefaultNavigation: true,
            openDefaultNavigation: { url in
                defaultURLs.append(url)
                return true
            },
            openAppleMaps: { _, _ in
                appleMapsCalls += 1
                return true
            }
        )

        XCTAssertTrue(didOpen)
        XCTAssertEqual(defaultURLs, [VisitMapOpener.navigationURL(for: coordinate)!])
        XCTAssertEqual(appleMapsCalls, 0)
    }

    @MainActor
    func testFailedDefaultNavigationFallsBackWithTheOriginalCoordinateAndName() async {
        var attemptedDefaultNavigation = false
        var fallbackCoordinate: CLLocationCoordinate2D?
        var fallbackName: String?

        let didOpen = await VisitMapOpener.open(
            coordinate: coordinate,
            name: "Cafe & Bakery",
            supportsDefaultNavigation: true,
            openDefaultNavigation: { _ in
                attemptedDefaultNavigation = true
                return false
            },
            openAppleMaps: { coordinate, name in
                XCTAssertTrue(attemptedDefaultNavigation)
                fallbackCoordinate = coordinate
                fallbackName = name
                return true
            }
        )

        XCTAssertTrue(didOpen)
        XCTAssertEqual(fallbackCoordinate?.latitude, coordinate.latitude)
        XCTAssertEqual(fallbackCoordinate?.longitude, coordinate.longitude)
        XCTAssertEqual(fallbackName, "Cafe & Bakery")
    }

    @MainActor
    func testOlderSystemOpensAppleMapsWithoutAttemptingDefaultNavigation() async {
        var attemptedDefaultNavigation = false
        var appleMapsCalls = 0

        let didOpen = await VisitMapOpener.open(
            coordinate: coordinate,
            name: "Lisbon",
            supportsDefaultNavigation: false,
            openDefaultNavigation: { _ in
                attemptedDefaultNavigation = true
                return true
            },
            openAppleMaps: { _, _ in
                appleMapsCalls += 1
                return true
            }
        )

        XCTAssertTrue(didOpen)
        XCTAssertFalse(attemptedDefaultNavigation)
        XCTAssertEqual(appleMapsCalls, 1)
    }

    @MainActor
    func testInvalidCoordinatesDoNotLaunchEitherApp() async {
        var attemptedDefaultNavigation = false
        var attemptedAppleMaps = false

        let didOpen = await VisitMapOpener.open(
            coordinate: CLLocationCoordinate2D(latitude: .nan, longitude: 0),
            name: "Invalid place",
            supportsDefaultNavigation: true,
            openDefaultNavigation: { _ in
                attemptedDefaultNavigation = true
                return true
            },
            openAppleMaps: { _, _ in
                attemptedAppleMaps = true
                return true
            }
        )

        XCTAssertFalse(didOpen)
        XCTAssertFalse(attemptedDefaultNavigation)
        XCTAssertFalse(attemptedAppleMaps)
    }

    @MainActor
    func testFailedAppleMapsFallbackReturnsFailure() async {
        let didOpen = await VisitMapOpener.open(
            coordinate: coordinate,
            name: "Lisbon",
            supportsDefaultNavigation: true,
            openDefaultNavigation: { _ in false },
            openAppleMaps: { _, _ in false }
        )

        XCTAssertFalse(didOpen)
    }
}
