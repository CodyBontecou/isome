import ActivityKit
import WidgetKit
import SwiftUI
import UIKit

struct IsoMeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationActivityAttributes.self) { context in
            // Lock Screen / StandBy UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: context.state.trackingMode == .continuous ? "location.fill" : "mappin.circle.fill")
                            .foregroundStyle(.blue)
                        Text(context.state.trackingMode.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if let remaining = context.state.remainingSeconds {
                        Text(formatTime(remaining))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        if let name = context.state.locationName {
                            Text(name)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        HStack(spacing: 12) {
                            Label("\(context.state.locationsRecorded)", systemImage: "mappin")
                            Label(
                                formatDistance(
                                    context.state.distanceTraveled,
                                    usesMetricDistanceUnits: context.state.usesMetricDistanceUnits ?? true
                                ),
                                systemImage: "figure.walk"
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Tracking since \(context.attributes.startTime, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.trackingMode == .continuous ? "location.fill" : "mappin.circle.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text("\(context.state.locationsRecorded)")
                    .font(.caption)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func formatDistance(_ meters: Double, usesMetricDistanceUnits: Bool) -> String {
        DistanceFormatter.format(meters: meters, usesMetric: usesMetricDistanceUnits)
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<LocationActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Left: Metadata
            VStack(alignment: .leading, spacing: 8) {
                // Location name
                if let name = context.state.locationName {
                    Text(name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                } else {
                    Text("Tracking")
                        .font(.title3.weight(.semibold))
                }

                // Stats
                Label(
                    DistanceFormatter.format(
                        meters: context.state.distanceTraveled,
                        usesMetric: context.state.usesMetricDistanceUnits ?? true
                    ),
                    systemImage: "figure.walk"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                // Timer
                if let remaining = context.state.remainingSeconds {
                    Text(formatTime(remaining))
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.title2)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 0)

                // Stop button
                Link(destination: URL(string: "isome://stop")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer(minLength: 0)

            // Right: Square map snapshot
            if context.state.mapSnapshotVersion > 0, let snapshot = Self.loadMapSnapshot() {
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .id(context.state.mapSnapshotVersion)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
        .activitySystemActionForegroundColor(.white)
    }

    private static func loadMapSnapshot() -> UIImage? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.bontecou.isome")?
            .appendingPathComponent("map_snapshot.png"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: LocationActivityAttributes(startTime: .now)) {
    IsoMeLiveActivity()
} contentStates: {
    LocationActivityAttributes.ContentState(
        trackingMode: .continuous,
        locationName: "Coffee Shop",
        locationsRecorded: 42,
        distanceTraveled: 1234,
        remainingSeconds: 3600,
        lastUpdate: .now
    )
    LocationActivityAttributes.ContentState(
        trackingMode: .visits,
        locationName: nil,
        locationsRecorded: 5,
        distanceTraveled: 8500,
        remainingSeconds: nil,
        lastUpdate: .now
    )
}
