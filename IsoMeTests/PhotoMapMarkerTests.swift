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

    func testDotsAndPinsRetainCompletePlaceAndAreaSelection() throws {
        let photos = (0..<501).map { photo("dense-\($0)") }
        let singleton = photo("separate", latitude: 38)
        let places = PhotoMomentClusterBuilder.placeClusters(for: photos + [singleton])
        let dense = try XCTUnwrap(places.first { $0.count == 501 })
        let area = try XCTUnwrap(PhotoMomentClusterBuilder.annotations(for: places, maximumCount: 1).first)
        XCTAssertTrue(area.isArea)
        XCTAssertEqual(area.count, 502)
        XCTAssertTrue(area.accessibilityLabel.contains("in this area"))
        let selection = PhotoMomentDetailSelection()
        for (images, dots) in [(true, false), (false, false), (true, true), (false, true)] {
            for cluster in [dense, area] {
                PhotoMomentClusterMapMarker(
                    cluster: cluster, isSelected: false, showsImage: images, showsDots: dots,
                    action: { selection.cluster = cluster }
                ).activate()
                XCTAssertEqual(selection.cluster?.count, cluster.count)
                XCTAssertEqual(selection.cluster?.places.map(\.id), cluster.places.map(\.id))
            }
            PhotoMomentMapMarker(
                photo: singleton, isSelected: false, showsImage: images, showsDots: dots,
                action: { selection.photo = singleton }
            ).activate()
            selection.place = dense
            selection.browserPhoto = dense.sortedPhotos.last
            let browser = PhotoMomentFullScreenView(photo: try XCTUnwrap(selection.browserPhoto), photos: dense.sortedPhotos)
            XCTAssertEqual(browser.photos.count, 501)
            XCTAssertEqual(Set(browser.photos.map(\.id)), Set(photos.map(\.id)))
            selection.dismissAll()
            XCTAssertNil(selection.photo)
            XCTAssertNil(selection.cluster)
            XCTAssertNil(selection.place)
            XCTAssertNil(selection.browserPhoto)
        }
    }

    func testHostedAreaDotsDeferImagesUntilCompletePlaceBrowsing() async throws {
        let photos = (0..<501).map { photo("dense-\($0)") }
        let places = PhotoMomentClusterBuilder.placeClusters(for: photos + [photo("separate", latitude: 38)])
        let dense = try XCTUnwrap(places.first { $0.count == 501 })
        let area = try XCTUnwrap(PhotoMomentClusterBuilder.annotations(for: places, maximumCount: 1).first)
        let selection = PhotoMomentDetailSelection()
        var requested: [String] = []
        var browsing = false
        let loaded = expectation(description: "Opening the complete place loads its last photo")
        loaded.assertForOverFulfill = false
        let last = try XCTUnwrap(dense.sortedPhotos.last)
        let loader: PhotoThumbnailLoader = { identifier, _, _ in
            requested.append(identifier)
            if browsing && identifier == last.assetLocalIdentifier { loaded.fulfill() }
            return nil
        }
        let marker = PhotoMomentClusterMapMarker(
            cluster: area, isSelected: false, showsImage: true, showsDots: true,
            thumbnailLoader: loader, action: { selection.cluster = area }
        )
        let host = UIHostingController(rootView: AnyView(marker))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(requested.isEmpty)
        marker.activate()
        let selectedArea = try XCTUnwrap(selection.cluster)
        selection.place = try XCTUnwrap(selectedArea.places.first { $0.id == dense.id })
        let selectedPlace = try XCTUnwrap(selection.place)
        XCTAssertEqual(selectedPlace.count, 501)
        browsing = true
        host.rootView = AnyView(PhotoMomentFullScreenView(photo: last, photos: selectedPlace.sortedPhotos, loader: loader))
        host.view.layoutIfNeeded()
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertEqual(Set(requested), Set([last.assetLocalIdentifier]))
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
