import ActivityKit
import WidgetKit
import SwiftUI

struct LocationTrackerLiveActivity: Widget {
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
                            Label(formatDistance(context.state.distanceTraveled), systemImage: "figure.walk")
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
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<LocationActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Left: Icon and mode
                VStack(spacing: 4) {
                    Image(systemName: context.state.trackingMode == .continuous ? "location.fill" : "mappin.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    Text(context.state.trackingMode.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60)
                
                // Center: Location and stats
                VStack(alignment: .leading, spacing: 4) {
                    if let name = context.state.locationName {
                        Text(name)
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text("Tracking Location")
                            .font(.headline)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(context.state.locationsRecorded) pts", systemImage: "mappin")
                        Label(formatDistance(context.state.distanceTraveled), systemImage: "figure.walk")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Right: Timer or duration
                VStack(alignment: .trailing, spacing: 4) {
                    if let remaining = context.state.remainingSeconds {
                        Text(formatTime(remaining))
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(context.attributes.startTime, style: .timer)
                            .font(.title3)
                            .monospacedDigit()
                        Text("elapsed")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 70)
            }
            
            // Stop Tracking Button
            Link(destination: URL(string: "locationtracker://stop")!) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop Tracking")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
        .activitySystemActionForegroundColor(.white)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: LocationActivityAttributes(startTime: .now)) {
    LocationTrackerLiveActivity()
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
