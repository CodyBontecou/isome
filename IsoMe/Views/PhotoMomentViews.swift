import SwiftUI
import Photos
import CoreLocation

struct PhotoThumbnailView: View {
    @Environment(\.displayScale) private var displayScale

    let assetLocalIdentifier: String
    let targetPointSize: CGSize
    var cornerRadius: CGFloat = 4
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var hasAttemptedLoad = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: targetPointSize.width, height: targetPointSize.height)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(TE.textMuted.opacity(0.12))
                    .overlay {
                        Image(systemName: hasAttemptedLoad ? "photo.badge.exclamationmark" : "photo")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(TE.textMuted)
                    }
            }
        }
        .frame(width: targetPointSize.width, height: targetPointSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: taskID) {
            await loadThumbnail()
        }
    }

    private var taskID: String {
        "\(assetLocalIdentifier)-\(Int(targetPointSize.width))-\(Int(targetPointSize.height))-\(Int(displayScale * 100))"
    }

    private func loadThumbnail() async {
        hasAttemptedLoad = false
        let pixelSize = CGSize(
            width: max(1, targetPointSize.width * displayScale),
            height: max(1, targetPointSize.height * displayScale)
        )
        image = await PhotoLibraryManager.shared.thumbnail(
            for: assetLocalIdentifier,
            targetSize: pixelSize
        )
        hasAttemptedLoad = true
    }
}

struct PhotoMomentMapMarker: View {
    let photo: PhotoMoment
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(TE.accent)
                    .frame(width: isSelected ? 34 : 30, height: isSelected ? 34 : 30)
                    .shadow(color: TE.accent.opacity(0.35), radius: 6, y: 3)

                Image(systemName: "camera.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)

                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: -2)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.accessibilityLabel)
        .accessibilityValue(photo.accessibilityValue)
        .accessibilityHint("Opens photo details.")
    }
}

struct PhotoMomentMiniMarker: View {
    let photo: PhotoMoment

    var body: some View {
        ZStack {
            Circle()
                .fill(TE.accent)
                .frame(width: 22, height: 22)
                .shadow(color: TE.accent.opacity(0.3), radius: 4, y: 2)

            Image(systemName: "camera.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 32, height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.accessibilityLabel)
        .accessibilityValue(photo.accessibilityValue)
    }
}

struct PhotoMomentQuickView: View {
    let photo: PhotoMoment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    TESectionHeader(title: "PHOTO")

                    TECard {
                        VStack(spacing: 0) {
                            TERow {
                                PhotoThumbnailView(
                                    assetLocalIdentifier: photo.assetLocalIdentifier,
                                    targetPointSize: CGSize(width: 280, height: 280),
                                    cornerRadius: 6
                                )
                                .frame(maxWidth: .infinity)
                            }

                            detailRow(label: "TAKEN", value: photo.formattedTakenTime)
                            detailRow(label: "SOURCE", value: photo.coordinateSource.displayName.uppercased())
                            detailRow(
                                label: "COORDS",
                                value: String(format: "%.5f, %.5f", photo.latitude, photo.longitude),
                                showDivider: false
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    TESectionFooter(text: "iso.me stores only this photo's local identifier, timestamp, and coordinates. The photo file stays in your Photos library.")
                }
                .padding(.bottom, 28)
            }
            .background(TE.surface.ignoresSafeArea())
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func detailRow(label: String, value: String, showDivider: Bool = true) -> some View {
        TERow(showDivider: showDivider) {
            HStack(spacing: 12) {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(TE.textMuted)

                Spacer()

                Text(value)
                    .font(TE.mono(.caption, weight: .semibold))
                    .foregroundStyle(TE.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
        }
    }
}
