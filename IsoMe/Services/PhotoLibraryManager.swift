import Foundation
import Photos
import UIKit
import CoreLocation

enum PhotoLibraryAccessState: String, Equatable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
    case unavailable

    var canRead: Bool {
        self == .authorized || self == .limited
    }

    var isLimited: Bool {
        self == .limited
    }

    var statusLabel: String {
        switch self {
        case .notDetermined:
            return "Not Connected"
        case .authorized:
            return "Connected"
        case .limited:
            return "Limited"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .unavailable:
            return "Unavailable"
        }
    }

    var explanation: String {
        switch self {
        case .notDetermined:
            return "Connect Photos to show geotagged pictures on your map and outings. iso.me stores only local photo metadata."
        case .authorized:
            return "Geotagged photos from your library can appear on the map. Photo files stay in Photos."
        case .limited:
            return "Only photos you selected for iso.me can appear. Add more in iOS Photos privacy settings."
        case .denied:
            return "Photo access is off. Enable it in Settings to show photo pins on the map."
        case .restricted:
            return "Photo access is restricted on this device."
        case .unavailable:
            return "Photos are unavailable on this device."
        }
    }

    static func from(_ status: PHAuthorizationStatus) -> PhotoLibraryAccessState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unavailable
        }
    }
}

@MainActor
final class PhotoLibraryManager: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoLibraryManager()

    private let imageManager = PHCachingImageManager()
    private var isObservingChanges = false

    var authorizationState: PhotoLibraryAccessState {
        PhotoLibraryAccessState.from(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAuthorization() async -> PhotoLibraryAccessState {
        let current = authorizationState
        guard current == .notDetermined else {
            startObservingChangesIfNeeded()
            return current
        }

        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }

        let state = PhotoLibraryAccessState.from(status)
        if state.canRead {
            startObservingChangesIfNeeded()
        }
        return state
    }

    func startObservingChangesIfNeeded() {
        guard authorizationState.canRead, !isObservingChanges else { return }
        PHPhotoLibrary.shared().register(self)
        isObservingChanges = true
    }

    func fetchGeotaggedPhotoMetadata(in range: ClosedRange<Date>) -> [PhotoAssetMetadata] {
        guard authorizationState.canRead else { return [] }
        startObservingChangesIfNeeded()

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            range.lowerBound as NSDate,
            range.upperBound as NSDate
        )

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var moments: [PhotoAssetMetadata] = []
        moments.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            guard let takenAt = asset.creationDate,
                  let location = asset.location,
                  CLLocationCoordinate2DIsValid(location.coordinate) else {
                return
            }

            moments.append(PhotoAssetMetadata(
                assetLocalIdentifier: asset.localIdentifier,
                takenAt: takenAt,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                coordinateSource: .photoGPS
            ))
        }

        return moments
    }

    func thumbnail(
        for assetLocalIdentifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) async -> UIImage? {
        guard authorizationState.canRead else { return nil }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalIdentifier], options: nil)
        guard let asset = result.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact

        return await withCheckedContinuation { continuation in
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, _ in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .photoLibraryDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let photoLibraryDidChange = Notification.Name("photoLibraryDidChange")
}
