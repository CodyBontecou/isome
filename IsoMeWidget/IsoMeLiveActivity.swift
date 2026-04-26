import ActivityKit
import WidgetKit
import SwiftUI
import UIKit

// MARK: - Widget tokens
// Mirrors values from IsoMe/DesignSystem.swift so the widget extension stays
// self-contained without sharing the DS namespace across targets.
private enum WidgetTokens {
    static let background = Color(red: 253/255, green: 248/255, blue: 245/255)
    static let card = Color.white
    static let textPrimary = Color(red: 0.118, green: 0.149, blue: 0.282)
    static let textMuted = Color(red: 0.541, green: 0.580, blue: 0.671)
    static let accent = Color(red: 0.482, green: 0.467, blue: 0.929)
    static let accentGreen = Color(red: 0.298, green: 0.667, blue: 0.467)
    static let danger = Color(red: 0.929, green: 0.302, blue: 0.310)
    static let warning = Color(red: 0.929, green: 0.510, blue: 0.388)
}

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
                        Image(systemName: "location.fill")
                            .foregroundStyle(WidgetTokens.accent)
                        Text("Tracking")
                            .font(.caption)
                            .foregroundStyle(WidgetTokens.textMuted)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let remaining = context.state.remainingSeconds {
                        Text(formatTime(remaining))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(WidgetTokens.warning)
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
                        .foregroundStyle(WidgetTokens.textMuted)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Tracking since \(context.attributes.startTime, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(WidgetTokens.textMuted)
                    }
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(WidgetTokens.accent)
            } compactTrailing: {
                Text("\(context.state.locationsRecorded)")
                    .font(.caption)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(WidgetTokens.accent)
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
                .foregroundStyle(WidgetTokens.textMuted)

                // Timer
                if let remaining = context.state.remainingSeconds {
                    Text(formatTime(remaining))
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundStyle(WidgetTokens.warning)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundStyle(WidgetTokens.textPrimary)
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
                    .background(WidgetTokens.danger, in: RoundedRectangle(cornerRadius: 10))
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
        .activityBackgroundTint(WidgetTokens.background)
        .activitySystemActionForegroundColor(WidgetTokens.textPrimary)
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
        locationName: "Coffee Shop",
        locationsRecorded: 42,
        distanceTraveled: 1234,
        remainingSeconds: 3600,
        lastUpdate: .now
    )
    LocationActivityAttributes.ContentState(
        locationName: nil,
        locationsRecorded: 5,
        distanceTraveled: 8500,
        remainingSeconds: nil,
        lastUpdate: .now
    )
}
