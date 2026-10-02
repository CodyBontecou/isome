import XCTest
import CoreLocation
import SwiftData
@testable import IsoMe

@MainActor
final class PhotoMomentMembershipTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func test501SamePlaceHasCompleteCountPagesAndFullScreenMembership() throws {
        let photos = fixture(count: 501)
        let cluster = try XCTUnwrap(PhotoMomentClusterBuilder.clusters(for: Array(photos.reversed())).first)
        XCTAssertEqual(cluster.count, 501)
        XCTAssertFalse(cluster.isArea)
        XCTAssertEqual(cluster.accessibilityLabel, "501 photos taken here")
        XCTAssertEqual(cluster.sortedPhotos.map(\.id), photos.map(\.id))

        var pagedIDs: [UUID] = []
        let pageCount = PhotoMomentDetailPage(photos: cluster.sortedPhotos, index: 0).count
        XCTAssertEqual(pageCount, 9)
        for index in 0..<pageCount {
            let page = PhotoMomentDetailPage(photos: cluster.sortedPhotos, index: index)
            XCTAssertLessThanOrEqual(page.photos.count, 60)
            pagedIDs += page.photos.map(\.id)
        }
        XCTAssertEqual(pagedIDs, photos.map(\.id))
        XCTAssertEqual(PhotoMomentDetailPage(photos: cluster.sortedPhotos, index: 8).photos.count, 21)

        // This is the same initializer used when tapping any grid page, including
        // the last page. It must receive all members, not just that page's slice.
        let browser = PhotoMomentFullScreenView(photo: photos[500], photos: cluster.sortedPhotos)
        XCTAssertEqual(browser.photos.map(\.id), photos.map(\.id))
        var index = 0
        var visited: [UUID] = []
        for _ in 0..<browser.photos.count {
            visited.append(browser.photos[index].id)
            index = PhotoMomentDetailPage.nextPhotoIndex(from: index, by: 1, count: browser.photos.count)
        }
        XCTAssertEqual(visited, photos.map(\.id))
        XCTAssertEqual(index, 0)
        XCTAssertEqual(PhotoMomentDetailPage.nextPhotoIndex(from: 0, by: -1, count: 501), 500)
    }

    func testAbove500AcrossMultiplePlacesPreservesEachPlaceAndStableOrder() {
        let first = fixture(count: 1_001)
        let second = fixture(count: 701, latitude: 38, prefix: "second")
        let clusters = PhotoMomentClusterBuilder.clusters(for: Array((first + second).reversed()))
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(Set(clusters.map(\.count)), Set([1_001, 701]))
        XCTAssertTrue(clusters.allSatisfy { !$0.isArea })
        assertCompleteMembership(clusters, photos: first + second)
        XCTAssertEqual(
            clusters.map(\.id),
            PhotoMomentClusterBuilder.clusters(for: first + second).map(\.id)
        )
    }

    func testMoreThan500DistinctPlacesCoarsensAnnotationsWithoutDroppingMembers() {
        let photos = (0..<1_001).map { index in
            PhotoMoment(
                assetLocalIdentifier: "place-\(index)",
                takenAt: start.addingTimeInterval(Double(index)),
                latitude: 37 + Double(index / 100) * 0.01,
                longitude: -122 + Double(index % 100) * 0.01
            )
        }
        let clusters = PhotoMomentClusterBuilder.clusters(for: photos)
        XCTAssertLessThanOrEqual(clusters.count, 500)
        XCTAssertTrue(clusters.contains { $0.isArea && $0.count > 1 })
        assertCompleteMembership(clusters, photos: photos)
        let one = PhotoMomentClusterBuilder.clusters(for: photos, maximumCount: 1)
        XCTAssertEqual(one.count, 1)
        XCTAssertEqual(one.first?.count, photos.count)
    }

    func testDateRangeReloadAndAuthorizationClearOnlyPresentationNotStoredMetadata() throws {
        let schema = Schema([Visit.self, LocationPoint.self, RecordingSession.self, PhotoMoment.self, SavedPlace.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let first = fixture(count: 501)
        let second = fixture(count: 601, latitude: 38, prefix: "tomorrow", offset: 86_400)
        for photo in first + second { context.insert(photo) }
        try context.save()

        var access = PhotoLibraryAccessState.authorized
        let manager = LocationManager()
        manager.isTrackingEnabled = false
        let viewModel = LocationViewModel(
            modelContext: context,
            locationManager: manager,
            photoAuthorizationProvider: { access }
        )
        let firstRange = start...start.addingTimeInterval(500)
        viewModel.mapDateRange = firstRange
        viewModel.loadMapPhotoMoments()
        XCTAssertEqual(viewModel.mapPhotoMomentCount, 501)
        assertCompleteMembership(viewModel.mapPhotoMomentClusters, photos: first)
        XCTAssertEqual(viewModel.mapPhotoMoments.count, 501)

        let secondRange = start.addingTimeInterval(86_400)...start.addingTimeInterval(87_000)
        viewModel.mapDateRange = secondRange
        viewModel.loadMapPhotoMoments()
        XCTAssertEqual(viewModel.mapPhotoMomentCount, 601)
        assertCompleteMembership(viewModel.mapPhotoMomentClusters, photos: second)
        XCTAssertTrue(viewModel.mapPhotoMoments.allSatisfy { secondRange.contains($0.takenAt) })

        viewModel.mapDateRange = start.addingTimeInterval(-100)...start.addingTimeInterval(-1)
        viewModel.loadMapPhotoMoments()
        XCTAssertEqual(viewModel.mapPhotoMomentCount, 0)
        XCTAssertTrue(viewModel.mapPhotoMomentClusters.isEmpty)
        viewModel.loadMapPhotoMoments(in: firstRange)
        XCTAssertEqual(viewModel.mapPhotoMomentClusters.first?.count, 501)

        access = .denied
        viewModel.loadMapPhotoMoments(in: firstRange)
        XCTAssertTrue(viewModel.mapPhotoMoments.isEmpty)
        XCTAssertTrue(viewModel.mapPhotoMomentClusters.isEmpty)
        XCTAssertEqual(viewModel.mapPhotoMomentCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PhotoMoment>()), 1_102)
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<PhotoMoment>()).map(\.id)), Set((first + second).map(\.id)))

        access = .limited
        viewModel.loadMapPhotoMoments(in: secondRange)
        assertCompleteMembership(viewModel.mapPhotoMomentClusters, photos: second)
    }

    func testDetailPageClampsEmptyAndOutOfBoundsRequests() {
        let empty = PhotoMomentDetailPage(photos: [], index: 10)
        XCTAssertEqual(empty.count, 1)
        XCTAssertEqual(empty.index, 0)
        XCTAssertTrue(empty.photos.isEmpty)
        let photos = fixture(count: 61)
        XCTAssertEqual(PhotoMomentDetailPage(photos: photos, index: -10).photos.count, 60)
        XCTAssertEqual(PhotoMomentDetailPage(photos: photos, index: 10).photos.map(\.id), [photos[60].id])
        XCTAssertEqual(PhotoMomentDetailPage.nextPhotoIndex(from: 0, by: 1, count: 0), 0)
    }

    private func fixture(
        count: Int, latitude: Double = 37, prefix: String = "photo", offset: TimeInterval = 0
    ) -> [PhotoMoment] {
        (0..<count).map { index in
            PhotoMoment(
                assetLocalIdentifier: "\(prefix)-\(index)",
                takenAt: start.addingTimeInterval(offset + Double(index)),
                latitude: latitude,
                longitude: -122
            )
        }
    }

    private func assertCompleteMembership(
        _ clusters: [PhotoMomentCluster], photos: [PhotoMoment],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let members = clusters.flatMap(\.photos)
        XCTAssertEqual(members.count, photos.count, file: file, line: line)
        XCTAssertEqual(Set(members.map(\.id)), Set(photos.map(\.id)), file: file, line: line)
    }
}
