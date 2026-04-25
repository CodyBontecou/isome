import SwiftUI
import MapKit

/// Full-screen detail for a movement segment between two visits.
/// 4 stat cards over a route map; reached from the Timeline tab.
struct RouteDetailView: View {
    let segment: RouteSegment

    private var usesMetric: Bool {
        Locale.current.measurementSystem == .metric
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)

                statGrid
                    .padding(.horizontal, DS.Spacing.lg)

                routeMap
                    .padding(.horizontal, DS.Spacing.lg)

                legend
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle(routeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            CategoryIcon(symbol: segment.activity.symbol, palette: segment.activity.palette, size: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(routeTitle)
                    .font(DS.Font.title())
                    .foregroundStyle(DS.Color.textPrimary)

                Text(dateLine)
                    .font(DS.Font.body(.medium))
                    .foregroundStyle(DS.Color.textMuted)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Stats

    private var statGrid: some View {
        let columns = [GridItem(.flexible(), spacing: DS.Spacing.md), GridItem(.flexible(), spacing: DS.Spacing.md)]
        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            StatCard(
                symbol: "ruler",
                palette: .blue,
                value: distanceValue,
                unit: distanceUnit,
                label: "Distance"
            )
            StatCard(
                symbol: "clock.fill",
                palette: .purple,
                value: durationValue,
                unit: durationUnit,
                label: "Duration"
            )
            StatCard(
                symbol: "flag.fill",
                palette: .green,
                value: timeValue(segment.startTime),
                unit: timePeriod(segment.startTime),
                label: "Start"
            )
            StatCard(
                symbol: "flag.checkered",
                palette: .peach,
                value: timeValue(segment.endTime),
                unit: timePeriod(segment.endTime),
                label: "End"
            )
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var routeMap: some View {
        if segment.coordinates.count >= 2 {
            Map(initialPosition: .region(routeRegion)) {
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(
                        segment.activity.palette.icon,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )

                if let start = segment.coordinates.first {
                    Annotation("", coordinate: start) {
                        PathStartMarker(timestamp: segment.startTime)
                    }
                }
                if let end = segment.coordinates.last {
                    Annotation("", coordinate: end) {
                        PathEndMarker(timestamp: segment.endTime)
                    }
                }
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: 0, y: DS.Shadow.cardY)
        } else {
            DSCard {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "map")
                        .font(.system(size: 28))
                        .foregroundStyle(DS.Color.textMuted)
                    Text("Not enough points to draw this route")
                        .font(DS.Font.body())
                        .foregroundStyle(DS.Color.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.lg)
            }
        }
    }

    private var legend: some View {
        DSCard(padding: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.lg) {
                LegendItem(color: .green, label: "Start")
                LegendItem(color: .red, label: "End")
                Spacer(minLength: 0)
                Text("\(segment.pointCount) pts")
                    .font(DS.Font.caption(.medium))
                    .foregroundStyle(DS.Color.textMuted)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Computed labels

    private var routeTitle: String {
        let period = timeOfDay(segment.startTime)
        return "\(period) \(segment.activity.label)"
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: segment.startTime)
    }

    private var distanceValue: String {
        if usesMetric {
            return segment.distanceMeters >= 1000
                ? String(format: "%.1f", segment.distanceMeters / 1000)
                : String(Int(segment.distanceMeters))
        }
        let miles = segment.distanceMeters / 1609.344
        if miles >= 0.1 {
            return String(format: "%.1f", miles)
        }
        return String(Int(segment.distanceMeters * 3.28084))
    }

    private var distanceUnit: String {
        if usesMetric {
            return segment.distanceMeters >= 1000 ? "km" : "m"
        }
        let miles = segment.distanceMeters / 1609.344
        return miles >= 0.1 ? "mi" : "ft"
    }

    private var durationValue: String {
        let totalMinutes = Int(segment.durationSeconds / 60)
        if totalMinutes < 60 { return "\(totalMinutes)" }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return mins == 0 ? "\(hours)" : "\(hours):\(String(format: "%02d", mins))"
    }

    private var durationUnit: String {
        let totalMinutes = Int(segment.durationSeconds / 60)
        if totalMinutes < 60 { return "min" }
        let mins = totalMinutes % 60
        return mins == 0 ? "h" : "h"
    }

    private func timeValue(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    private func timePeriod(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: date)
    }

    private func timeOfDay(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }

    private var routeRegion: MKCoordinateRegion {
        MKCoordinateRegion(coordinates: segment.coordinates)
    }
}

private struct LegendItem: View {
    let color: Color
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(DS.Font.caption(.medium))
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}
