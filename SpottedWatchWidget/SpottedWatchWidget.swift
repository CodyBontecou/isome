import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct SpottedProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpottedEntry {
        SpottedEntry(
            date: Date(),
            data: SharedLocationData(
                isTrackingEnabled: true,
                isContinuousTrackingEnabled: false,
                currentLocationName: "Home",
                currentAddress: nil,
                lastLatitude: nil,
                lastLongitude: nil,
                lastUpdateTime: Date(),
                todayVisitsCount: 5,
                todayDistanceMeters: 2500,
                todayPointsCount: 0,
                continuousTrackingStartTime: nil,
                continuousTrackingAutoOffHours: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SpottedEntry) -> Void) {
        let data = SharedLocationData.load() ?? .empty
        let entry = SpottedEntry(date: Date(), data: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpottedEntry>) -> Void) {
        let data = SharedLocationData.load() ?? .empty
        let entry = SpottedEntry(date: Date(), data: data)
        
        // Refresh every 15 minutes or sooner if tracking is active
        let refreshInterval: TimeInterval = data.isContinuousTrackingEnabled ? 300 : 900
        let nextUpdate = Date().addingTimeInterval(refreshInterval)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct SpottedEntry: TimelineEntry {
    let date: Date
    let data: SharedLocationData
}

// MARK: - Widget Definition

struct SpottedWatchWidget: Widget {
    let kind: String = "SpottedWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpottedProvider()) { entry in
            SpottedWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spotted")
        .description("View your tracking status and today's stats.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Widget Views

struct SpottedWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SpottedEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularWidgetView(data: entry.data)
        case .accessoryRectangular:
            RectangularWidgetView(data: entry.data)
        case .accessoryInline:
            InlineWidgetView(data: entry.data)
        case .accessoryCorner:
            CornerWidgetView(data: entry.data)
        default:
            CircularWidgetView(data: entry.data)
        }
    }
}

// MARK: - Circular Widget (Small circular complication)

struct CircularWidgetView: View {
    let data: SharedLocationData
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                
                if data.isContinuousTrackingEnabled {
                    Text("\(data.todayPointsCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                } else {
                    Text("\(data.todayVisitsCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var statusIcon: String {
        if data.isContinuousTrackingEnabled {
            return "location.fill"
        } else if data.isTrackingEnabled {
            return "mappin.circle.fill"
        } else {
            return "location.slash"
        }
    }
    
    private var statusColor: Color {
        if data.isContinuousTrackingEnabled {
            return .green
        } else if data.isTrackingEnabled {
            return .blue
        } else {
            return .secondary
        }
    }
}

// MARK: - Rectangular Widget (Larger complication)

struct RectangularWidgetView: View {
    let data: SharedLocationData
    
    var body: some View {
        HStack(spacing: 8) {
            // Left: Status icon
            VStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                Text(data.trackingStatus)
                    .font(.caption2)
            }
            .frame(width: 50)
            
            // Right: Stats
            VStack(alignment: .leading, spacing: 2) {
                if let locationName = data.currentLocationName {
                    Text(locationName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    Label("\(data.todayVisitsCount)", systemImage: "mappin")
                    Label(data.formattedDistance, systemImage: "figure.walk")
                }
                .font(.caption2)
                
                if data.isContinuousTrackingEnabled,
                   let remaining = data.formattedRemainingTime {
                    Text("\(remaining) left")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
    
    private var statusIcon: String {
        if data.isContinuousTrackingEnabled {
            return "location.fill"
        } else if data.isTrackingEnabled {
            return "mappin.circle.fill"
        } else {
            return "location.slash"
        }
    }
    
    private var statusColor: Color {
        if data.isContinuousTrackingEnabled {
            return .green
        } else if data.isTrackingEnabled {
            return .blue
        } else {
            return .secondary
        }
    }
}

// MARK: - Inline Widget (Single line text)

struct InlineWidgetView: View {
    let data: SharedLocationData
    
    var body: some View {
        if data.isContinuousTrackingEnabled {
            Label("\(data.todayPointsCount) pts • \(data.formattedDistance)", systemImage: "location.fill")
        } else if data.isTrackingEnabled {
            Label("\(data.todayVisitsCount) visits • \(data.formattedDistance)", systemImage: "mappin.circle.fill")
        } else {
            Label("Tracking Off", systemImage: "location.slash")
        }
    }
}

// MARK: - Corner Widget (Shown in corner of watch face)

struct CornerWidgetView: View {
    let data: SharedLocationData
    
    var body: some View {
        ZStack {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
        }
        .widgetLabel {
            if data.isContinuousTrackingEnabled {
                Text("\(data.todayPointsCount) pts")
            } else if data.isTrackingEnabled {
                Text("\(data.todayVisitsCount) visits")
            } else {
                Text("Off")
            }
        }
    }
    
    private var statusIcon: String {
        if data.isContinuousTrackingEnabled {
            return "location.fill"
        } else if data.isTrackingEnabled {
            return "mappin.circle.fill"
        } else {
            return "location.slash"
        }
    }
    
    private var statusColor: Color {
        if data.isContinuousTrackingEnabled {
            return .green
        } else if data.isTrackingEnabled {
            return .blue
        } else {
            return .secondary
        }
    }
}

// MARK: - Previews

#Preview("Circular - Active", as: .accessoryCircular) {
    SpottedWatchWidget()
} timeline: {
    SpottedEntry(date: .now, data: SharedLocationData(
        isTrackingEnabled: true,
        isContinuousTrackingEnabled: true,
        currentLocationName: "Coffee Shop",
        currentAddress: nil,
        lastLatitude: nil,
        lastLongitude: nil,
        lastUpdateTime: .now,
        todayVisitsCount: 3,
        todayDistanceMeters: 1500,
        todayPointsCount: 42,
        continuousTrackingStartTime: Date().addingTimeInterval(-1800),
        continuousTrackingAutoOffHours: 2
    ))
}

#Preview("Rectangular - Active", as: .accessoryRectangular) {
    SpottedWatchWidget()
} timeline: {
    SpottedEntry(date: .now, data: SharedLocationData(
        isTrackingEnabled: true,
        isContinuousTrackingEnabled: true,
        currentLocationName: "Coffee Shop",
        currentAddress: nil,
        lastLatitude: nil,
        lastLongitude: nil,
        lastUpdateTime: .now,
        todayVisitsCount: 3,
        todayDistanceMeters: 1500,
        todayPointsCount: 42,
        continuousTrackingStartTime: Date().addingTimeInterval(-1800),
        continuousTrackingAutoOffHours: 2
    ))
}

#Preview("Inline - Visits", as: .accessoryInline) {
    SpottedWatchWidget()
} timeline: {
    SpottedEntry(date: .now, data: SharedLocationData(
        isTrackingEnabled: true,
        isContinuousTrackingEnabled: false,
        currentLocationName: nil,
        currentAddress: nil,
        lastLatitude: nil,
        lastLongitude: nil,
        lastUpdateTime: .now,
        todayVisitsCount: 5,
        todayDistanceMeters: 3200,
        todayPointsCount: 0,
        continuousTrackingStartTime: nil,
        continuousTrackingAutoOffHours: nil
    ))
}

#Preview("Corner - Off", as: .accessoryCorner) {
    SpottedWatchWidget()
} timeline: {
    SpottedEntry(date: .now, data: SharedLocationData(
        isTrackingEnabled: false,
        isContinuousTrackingEnabled: false,
        currentLocationName: nil,
        currentAddress: nil,
        lastLatitude: nil,
        lastLongitude: nil,
        lastUpdateTime: nil,
        todayVisitsCount: 0,
        todayDistanceMeters: 0,
        todayPointsCount: 0,
        continuousTrackingStartTime: nil,
        continuousTrackingAutoOffHours: nil
    ))
}
