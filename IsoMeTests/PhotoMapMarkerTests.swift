import XCTest
import SwiftUI
import Photos
@testable import IsoMe

@MainActor
final class PhotoMapMarkerTests: XCTestCase {
    private func photo(_ identifier: String, latitude: Double = 37.7749) -> PhotoMoment {
        PhotoMoment(
            assetLocalIdentifier: identifier,
            takenAt: Date(timeIntervalSince1970: 1_700_000_000),
            latitude: latitude,
            longitude: -122.4194
        )
    }

    func testModeSwitchingPreservesLegacyImageAndPinChoices() {
        XCTAssertEqual(PhotoMapMarkerStyle.resolve(showsImages: true, showsDots: false), .images)
        XCTAssertEqual(PhotoMapMarkerStyle.resolve(showsImages: false, showsDots: false), .pins)
        for images in [true, false] {
            XCTAssertEqual(PhotoMapMarkerStyle.resolve(showsImages: images, showsDots: true), .dots)
            XCTAssertEqual(
                PhotoMapMarkerStyle.resolve(showsImages: images, showsDots: false),
                images ? .images : .pins
            )
        }
    }

    func testAppStoragePersistsDotsAndDoesNotOverwriteLegacyPreference() throws {
        let suite = "PhotoMapMarkerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let images = AppStorage(wrappedValue: true, PhotoMapMarkerStyle.imagesKey, store: defaults)
        let dots = AppStorage(wrappedValue: false, PhotoMapMarkerStyle.dotsKey, store: defaults)
        XCTAssertTrue(images.wrappedValue)
        XCTAssertFalse(dots.wrappedValue)
        // Simulate an existing user who chose compact pins before dots existed.
        images.wrappedValue = false
        dots.wrappedValue = true

        let reopenedDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let reopenedDots = AppStorage(wrappedValue: false, PhotoMapMarkerStyle.dotsKey, store: reopenedDefaults)
        let reopenedImages = AppStorage(wrappedValue: true, PhotoMapMarkerStyle.imagesKey, store: reopenedDefaults)
        XCTAssertTrue(reopenedDots.wrappedValue)
        XCTAssertFalse(reopenedImages.wrappedValue)
        reopenedDots.wrappedValue = false
        XCTAssertEqual(
            PhotoMapMarkerStyle.resolve(showsImages: reopenedImages.wrappedValue, showsDots: reopenedDots.wrappedValue),
            .pins
        )
        XCTAssertFalse(defaults.bool(forKey: PhotoMapMarkerStyle.imagesKey))
    }

    func testSingletonAndClusterActivationKeepsDrillDownInEveryMode() throws {
        let single = photo("single", latitude: 38)
        let first = photo("first")
        let second = photo("second")
        let clusters = PhotoMomentClusterBuilder.clusters(for: [single, second, first])
        let singleton = try XCTUnwrap(clusters.first { $0.onlyPhoto != nil })
        let group = try XCTUnwrap(clusters.first { $0.count == 2 })
        XCTAssertEqual(singleton.onlyPhoto?.id, single.id)
        XCTAssertEqual(Set(group.photos.map(\.id)), Set([first.id, second.id]))
        XCTAssertFalse(single.accessibilityLabel.isEmpty)
        XCTAssertFalse(group.accessibilityLabel.isEmpty)
        XCTAssertFalse(group.accessibilityValue.isEmpty)

        for (images, dots) in [(true, false), (false, false), (true, true), (false, true)] {
            var selectedPhoto: PhotoMoment?
            var selectedCluster: PhotoMomentCluster?
            let singleMarker = PhotoMomentMapMarker(
                photo: single, isSelected: false, showsImage: images, showsDots: dots,
                action: { selectedPhoto = single }
            )
            let clusterMarker = PhotoMomentClusterMapMarker(
                cluster: group, isSelected: false, showsImage: images, showsDots: dots,
                action: { selectedCluster = group }
            )
            // Exercise the same activation callbacks used by the semantic Buttons.
            // Physical taps / MapKit hit testing still require device QA.
            singleMarker.activate()
            clusterMarker.activate()
            XCTAssertEqual(selectedPhoto?.id, single.id)
            XCTAssertEqual(selectedCluster?.id, group.id)
            XCTAssertEqual(selectedCluster?.sortedPhotos.map(\.id), group.sortedPhotos.map(\.id))
        }
    }

    func testRenderedDotsDoNotRequestThumbnailsAndSwitchingToImagesDoes() async throws {
        let single = photo("single")
        let group = try XCTUnwrap(PhotoMomentClusterBuilder.clusters(for: [photo("first"), photo("second")]).first)
        var requestedIdentifiers: [String] = []
        let imagesLoaded = expectation(description: "Image mode requests all three previews")
        imagesLoaded.expectedFulfillmentCount = 3
        imagesLoaded.assertForOverFulfill = false
        let loader: PhotoThumbnailLoader = { identifier, _, _ in
            requestedIdentifiers.append(identifier)
            imagesLoaded.fulfill()
            return nil
        }
        func markers(dots: Bool) -> some View {
            HStack {
                PhotoMomentMapMarker(
                    photo: single, isSelected: false, showsImage: true, showsDots: dots,
                    thumbnailLoader: loader, action: {}
                )
                PhotoMomentClusterMapMarker(
                    cluster: group, isSelected: false, showsImage: true, showsDots: dots,
                    thumbnailLoader: loader, action: {}
                )
            }
        }
        let host = UIHostingController(rootView: AnyView(markers(dots: true)))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.layoutIfNeeded()
        // Allow SwiftUI's .task work to run; a positive image-mode control below
        // ensures this test cannot pass simply because hosting never rendered.
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(requestedIdentifiers.isEmpty)
        host.rootView = AnyView(markers(dots: false))
        host.view.layoutIfNeeded()
        await fulfillment(of: [imagesLoaded], timeout: 5)
        XCTAssertEqual(Set(requestedIdentifiers), Set(["single", "first", "second"]))
    }

    func testDotLayoutKeeps44PointTargetForSingleAndGroupedPhotos() {
        for isCluster in [false, true] {
            let host = UIHostingController(rootView: PhotoMapDot(isSelected: false, isCluster: isCluster))
            let size = host.sizeThatFits(in: CGSize(width: 200, height: 200))
            XCTAssertEqual(size.width, 44, accuracy: 0.01)
            XCTAssertEqual(size.height, 44, accuracy: 0.01)
        }
    }
}
