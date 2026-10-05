#if DEBUG
import SwiftUI
import SwiftData
import Photos
import Observation
import UIKit
import CryptoKit

/// Only registered by a future isolated DEBUG app target, never the production app.
@main
@MainActor
struct PhotoMapIntegrationHostApp: App {
    @State private var fixture: PhotoMapFixture?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        precondition(Bundle.main.bundleIdentifier == PhotoMapFixture.bundleID,
                     "Synthetic photo host requires its isolated bundle")
        do {
            _fixture = State(initialValue: try PhotoMapFixture())
        } catch {
            // Fail closed: no production App, store, or SDK fallback.
            _fixture = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let fixture {
                PhotoMapFixtureRoot(fixture: fixture)
                    .defaultAppStorage(fixture.preferences)
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .background { fixture.applyArmedInput() }
                    }
            } else {
                Text("Synthetic fixture initialization failed")
                    .accessibilityIdentifier("photo.fixture.failed")
            }
        }
    }
}

@MainActor
@Observable
private final class PhotoMapSDKInputs {
    var access: PhotoLibraryAccessState = .authorized
    var metadata: [PhotoAssetLibraryMetadata] = []
    var allowedIDs = Set<String>()
    var requestedIDs = Set<String>()
    var authorizationRequests = 0
    var observationStarts = 0
    var metadataReads = 0

    func read(_ range: ClosedRange<Date>) -> [PhotoAssetLibraryMetadata] {
        metadataReads += 1
        guard access.canRead else { return [] }
        return metadata.filter {
            range.contains($0.takenAt) && (access == .authorized || allowedIDs.contains($0.id))
        }
    }

    func thumbnail(_ identifier: String, _ size: CGSize, _ mode: PHImageContentMode) -> UIImage? {
        // All identifiers are synthetic; bound diagnostics, not the real loader.
        precondition(identifier.hasPrefix("fixture-photo-"))
        precondition(requestedIDs.count <= 1_100)
        requestedIDs.insert(identifier)
        return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}

@MainActor
@Observable
private final class PhotoMapFixture {
    static let bundleID = "tech.isolated.synthetic.IsoMePhotoMapHost"
    private static let preferencesID = bundleID + ".preferences"
    let preferences: UserDefaults
    // Strong lifetime: no SwiftData model/context may outlive this container.
    let container: ModelContainer
    let viewModel: LocationViewModel
    let inputs: PhotoMapSDKInputs
    let fullRange: ClosedRange<Date>
    let instanceID = UUID().uuidString
    var appliedInputCount = 0
    private var armedInput: InputChange?
    var failure = false

    enum InputChange: String { case limited, range, replacement }

    func arm(_ change: InputChange) {
        precondition(armedInput == nil)
        armedInput = change
    }

    func applyArmedInput() {
        guard let change = armedInput else { return }
        armedInput = nil
        switch change {
        case .limited: changeAccess(.limited, lastIDsOnly: true)
        case .range: narrowRange()
        case .replacement: replaceOneMember()
        }
        appliedInputCount += 1
    }

    init() throws {
        let arguments = ProcessInfo.processInfo.arguments
        guard let preferences = UserDefaults(suiteName: Self.preferencesID) else {
            throw FixtureError.preferencesUnavailable
        }
        if arguments.contains("--fixture-reset-preferences") {
            preferences.removePersistentDomain(forName: Self.preferencesID)
        }
        self.preferences = preferences
        if preferences.object(forKey: PhotoMapMarkerStyle.imagesKey) == nil {
            preferences.set(!arguments.contains("--fixture-legacy-pins"), forKey: PhotoMapMarkerStyle.imagesKey)
        }
        if preferences.object(forKey: PhotoMapMarkerStyle.dotsKey) == nil {
            preferences.set(arguments.contains("--fixture-dots"), forKey: PhotoMapMarkerStyle.dotsKey)
        }
        preferences.set(true, forKey: LocationViewModel.showPhotoMarkersKey)
        preferences.set(false, forKey: LocationViewModel.showVisitSuggestionsKey)
        preferences.set(false, forKey: "snapTravelPathToRoads")
        preferences.set(true, forKey: "discordPromoDismissed")

        // This target owns its standard domain; do this BEFORE LocationManager init.
        UserDefaults.standard.set(false, forKey: "isTrackingEnabled")
        UserDefaults.standard.set(false, forKey: "isLiveActivityEnabled")
        UserDefaults.standard.set(false, forKey: "allowNetworkGeocoding")
        UserDefaults.standard.set(false, forKey: LocationViewModel.automaticPhotoSyncEnabledKey)

        let schema = Schema([Visit.self, LocationPoint.self, RecordingSession.self,
                             PhotoMoment.self, SavedPlace.self])
        let container = try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        self.container = container
        let context = container.mainContext
        let inputs = PhotoMapSDKInputs()
        self.inputs = inputs
        let count = arguments.contains("--fixture-dense") ? 1_003 : 3
        let end = Date()
        let today = Calendar.current.startOfDay(for: end)
        let span = min(1_800, max(0, end.timeIntervalSince(today)))
        let start = end.addingTimeInterval(-span)
        let range = start...end
        fullRange = range
        for index in 0..<count {
            let coordinate: (Double, Double)
            if count == 3 {
                coordinate = index == 0 ? (37.70, -122.40) : (37.78, -122.42)
            } else if index < 501 {
                coordinate = (37.78, -122.42) // One complete 501-photo place.
            } else {
                // More than 500 distinct places; the production builder coarsens them.
                coordinate = (30 + Double(index - 501) * 0.01, -120)
            }
            let identifier = String(format: "fixture-photo-%04d", index)
            let date = start.addingTimeInterval(span * Double(index) / Double(count))
            let photo = PhotoMoment(assetLocalIdentifier: identifier, takenAt: date,
                                    latitude: coordinate.0, longitude: coordinate.1)
            context.insert(photo)
            inputs.metadata.append(PhotoAssetLibraryMetadata(assetLocalIdentifier: identifier,
                takenAt: date, latitude: coordinate.0, longitude: coordinate.1))
        }
        inputs.allowedIDs = Set(inputs.metadata.map(\.id))
        try context.save()
        let manager = LocationManager()
        precondition(!manager.isTrackingEnabled)
        let viewModel = LocationViewModel(modelContext: context, locationManager: manager,
            photoAuthorizationProvider: { inputs.access },
            accessiblePhotoIdentifiersProvider: { Set($0).intersection(inputs.allowedIDs) },
            photoAuthorizationRequester: {
                inputs.authorizationRequests += 1
                return inputs.access
            },
            photoMetadataProvider: { inputs.read($0) },
            photoChangeObservationStarter: { inputs.observationStarts += 1 })
        self.viewModel = viewModel
        viewModel.mapDateRange = range
        viewModel.loadMapPhotoMoments()
    }

    /// Input mutations ONLY. Never assign photoDetails or reproduce navigation logic.
    func changeAccess(_ access: PhotoLibraryAccessState, lastIDsOnly: Bool = false) {
        inputs.access = access
        inputs.allowedIDs = Set((lastIDsOnly ? Array(inputs.metadata.suffix(21)) : inputs.metadata).map(\.id))
        NotificationCenter.default.post(name: .photoLibraryDidChange, object: nil)
    }

    func reload() { viewModel.loadMapPhotoMoments() }

    func narrowRange() {
        let middle = fullRange.lowerBound.addingTimeInterval(
            fullRange.upperBound.timeIntervalSince(fullRange.lowerBound) / 2)
        viewModel.mapDateRange = fullRange.lowerBound...middle
        viewModel.loadMapPhotoMoments()
    }

    func restoreRange() {
        viewModel.mapDateRange = fullRange
        viewModel.loadMapPhotoMoments()
    }

    func replaceOneMember() {
        do {
            let context = container.mainContext
            let rows = try context.fetch(FetchDescriptor<PhotoMoment>())
            // Replace a non-first member: the production place ID/count can stay unchanged.
            guard let old = rows.first(where: { $0.assetLocalIdentifier == "fixture-photo-0002" }),
                  let index = inputs.metadata.firstIndex(where: { $0.id == old.assetLocalIdentifier }) else {
                failure = true
                return
            }
            let replacement = PhotoMoment(assetLocalIdentifier: "fixture-photo-replacement",
                takenAt: old.takenAt, latitude: old.latitude, longitude: old.longitude)
            context.delete(old)
            context.insert(replacement)
            inputs.metadata[index] = PhotoAssetLibraryMetadata(assetLocalIdentifier: replacement.assetLocalIdentifier,
                takenAt: replacement.takenAt, latitude: replacement.latitude, longitude: replacement.longitude)
            inputs.allowedIDs.remove("fixture-photo-0002")
            inputs.allowedIDs.insert(replacement.assetLocalIdentifier)
            try context.save()
            viewModel.loadMapPhotoMoments()
        } catch { failure = true }
    }

    /// Visible read-only synthetic receipts complement, never replace, native UI assertions.
    var receipt: String {
        do {
            let rows = try container.mainContext.fetch(FetchDescriptor<PhotoMoment>()).sorted {
                $0.assetLocalIdentifier < $1.assetLocalIdentifier
            }
            let fields = rows.map {
                [$0.id.uuidString, $0.assetLocalIdentifier, String($0.takenAt.timeIntervalSince1970),
                 String($0.latitude), String($0.longitude), $0.coordinateSourceRawValue,
                 String($0.lastSyncedAt.timeIntervalSince1970)].joined(separator: "|")
            }.joined(separator: "\n")
            let digest = SHA256.hash(data: Data(fields.utf8)).map { String(format: "%02x", $0) }.joined()
            let membership = rows.map(\.assetLocalIdentifier).joined(separator: "\n")
            let membershipDigest = SHA256.hash(data: Data(membership.utf8))
                .map { String(format: "%02x", $0) }.joined()
            let object: [String: Any] = [
                "failed": failure, "cachedCount": rows.count, "cachedDigest": digest,
                "membershipDigest": membershipDigest,
                "rawRangeCount": viewModel.mapPhotoMomentCount,
                "accessibleCount": viewModel.mapAccessiblePhotoMoments.count,
                "places": viewModel.mapPhotoPlaces.count,
                "instanceID": instanceID, "appliedInputCount": appliedInputCount,
                "armedInput": armedInput?.rawValue ?? "none",
                "access": inputs.access.rawValue,
                "images": preferences.bool(forKey: PhotoMapMarkerStyle.imagesKey),
                "dots": preferences.bool(forKey: PhotoMapMarkerStyle.dotsKey),
                "annotations": viewModel.mapPhotoMomentClusters.count,
                "revision": viewModel.photoPresentationRevision,
                "requestedIDs": inputs.requestedIDs.sorted(),
                "authorizationRequests": inputs.authorizationRequests,
                "metadataReads": inputs.metadataReads, "observationStarts": inputs.observationStarts,
                "singletonPresented": viewModel.photoDetails.photo != nil,
                "clusterPresented": viewModel.photoDetails.cluster != nil,
                "directoryPresented": viewModel.photoDetails.showsPlaces,
                "placePresented": viewModel.photoDetails.place != nil,
                "browserPresented": viewModel.photoDetails.browserPhoto != nil
            ]
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            precondition(data.count <= 24 * 1_024)
            return String(decoding: data, as: UTF8.self)
        } catch { return "{\"failed\":true}" }
    }

    private enum FixtureError: Error { case preferencesUnavailable }
}

@MainActor
private struct PhotoMapFixtureRoot: View {
    let fixture: PhotoMapFixture

    var body: some View {
        VStack(spacing: 4) {
            Text(fixture.receipt)
                .font(.system(size: 8, design: .monospaced))
                .lineLimit(3)
                .accessibilityIdentifier("photo.fixture.receipt")
            Menu("Fixture inputs") {
                Button("Reload unchanged", action: fixture.reload)
                Button("Limit same IDs") { fixture.changeAccess(.limited) }
                Button("Limit last 21 IDs") { fixture.changeAccess(.limited, lastIDsOnly: true) }
                Button("Deny access") { fixture.changeAccess(.denied) }
                Button("Restore access") { fixture.changeAccess(.authorized) }
                Button("Narrow range", action: fixture.narrowRange)
                Button("Restore range", action: fixture.restoreRange)
                Button("Replace same-count member", action: fixture.replaceOneMember)
                Button("Arm limited access on background") { fixture.arm(.limited) }
                Button("Arm range change on background") { fixture.arm(.range) }
                Button("Arm replacement on background") { fixture.arm(.replacement) }
            }
            .accessibilityIdentifier("photo.fixture.inputs")
            LocationMapView(viewModel: fixture.viewModel, photoThumbnailLoader: {
                fixture.inputs.thumbnail($0, $1, $2)
            })
        }
    }
}
#endif
