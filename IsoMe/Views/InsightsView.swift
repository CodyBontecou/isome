import SwiftUI
import Charts

struct InsightsView: View {
    let viewModel: LocationViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DS.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        WeeklyStatsCard(viewModel: viewModel)
                        DistanceChartCard(viewModel: viewModel)
                        TopPlacesCard(viewModel: viewModel)
                        ActivityBreakdownCard(viewModel: viewModel)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxl)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Weekly Stats

private struct WeeklyStatsCard: View {
    let viewModel: LocationViewModel

    private var stats: (distance: Double, places: Int, hours: Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return (0, 0, 0)
        }

        let pointsInWindow = viewModel.locationPoints
            .filter { !$0.isOutlier && $0.timestamp >= weekAgo && $0.timestamp <= now }
            .sorted { $0.timestamp < $1.timestamp }

        let distance: Double = {
            guard pointsInWindow.count > 1 else { return 0 }
            return zip(pointsInWindow.dropLast(), pointsInWindow.dropFirst())
                .map { $0.distance(to: $1) }
                .reduce(0, +)
        }()

        let visitsInWindow = viewModel.allVisits.filter { $0.arrivedAt >= weekAgo }
        let placeCount = Set(visitsInWindow.map { $0.displayName }).count

        let hours: Double = {
            let byDay = Dictionary(grouping: pointsInWindow) { calendar.startOfDay(for: $0.timestamp) }
            return byDay.values.reduce(0.0) { acc, dayPoints in
                guard let first = dayPoints.first, let last = dayPoints.last else { return acc }
                return acc + last.timestamp.timeIntervalSince(first.timestamp) / 3600
            }
        }()

        return (distance, placeCount, hours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "This week")

            let s = stats
            let columns = [
                GridItem(.flexible(), spacing: DS.Spacing.md),
                GridItem(.flexible(), spacing: DS.Spacing.md),
                GridItem(.flexible(), spacing: DS.Spacing.md),
            ]
            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                StatCard(
                    symbol: "ruler",
                    palette: .blue,
                    value: distanceValue(s.distance),
                    unit: distanceUnit(s.distance),
                    label: "Distance"
                )
                StatCard(
                    symbol: "mappin.and.ellipse",
                    palette: .purple,
                    value: "\(s.places)",
                    label: "Places"
                )
                StatCard(
                    symbol: "clock.fill",
                    palette: .green,
                    value: hoursValue(s.hours),
                    unit: "h",
                    label: "Tracked"
                )
            }
        }
    }

    private func distanceValue(_ meters: Double) -> String {
        if Locale.current.measurementSystem == .metric {
            return meters >= 1000
                ? String(format: "%.0f", meters / 1000)
                : String(Int(meters))
        }
        let miles = meters / 1609.344
        return String(format: "%.0f", miles)
    }

    private func distanceUnit(_ meters: Double) -> String {
        if Locale.current.measurementSystem == .metric {
            return meters >= 1000 ? "km" : "m"
        }
        return "mi"
    }

    private func hoursValue(_ hours: Double) -> String {
        hours < 10 ? String(format: "%.1f", hours) : String(Int(hours))
    }
}

// MARK: - Distance chart

private struct DistanceChartCard: View {
    let viewModel: LocationViewModel

    private struct DayBucket: Identifiable {
        let id: Date
        let day: Date
        let meters: Double
    }

    private var dailyTotals: [DayBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [Date] = (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }

        return days.map { day in
            let dayStart = day
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let points = viewModel.locationPoints
                .filter { !$0.isOutlier && $0.timestamp >= dayStart && $0.timestamp < dayEnd }
                .sorted { $0.timestamp < $1.timestamp }
            let meters: Double = points.count > 1
                ? zip(points.dropLast(), points.dropFirst()).map { $0.distance(to: $1) }.reduce(0, +)
                : 0
            return DayBucket(id: day, day: day, meters: meters)
        }
    }

    private var usesMetric: Bool { Locale.current.measurementSystem == .metric }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "Daily distance")

            DSCard {
                let buckets = dailyTotals
                if buckets.allSatisfy({ $0.meters == 0 }) {
                    chartEmptyState
                } else {
                    Chart(buckets) { bucket in
                        BarMark(
                            x: .value("Day", bucket.day, unit: .day),
                            y: .value("Distance", convert(bucket.meters))
                        )
                        .foregroundStyle(DS.Color.iconPurple)
                        .cornerRadius(6)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(DS.Color.divider)
                            AxisValueLabel().foregroundStyle(DS.Color.textMuted)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                    }
                    .frame(height: 180)
                }
            }
        }
    }

    private var chartEmptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(DS.Color.textMuted)
            Text("No movement recorded this week")
                .font(DS.Font.body())
                .foregroundStyle(DS.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }

    private func convert(_ meters: Double) -> Double {
        usesMetric ? meters / 1000 : meters / 1609.344
    }
}

// MARK: - Top Places

private struct TopPlacesCard: View {
    let viewModel: LocationViewModel

    private struct PlaceTotal: Identifiable {
        let id: String
        let name: String
        let count: Int
        let totalSeconds: TimeInterval
    }

    private var topPlaces: [PlaceTotal] {
        let calendar = Calendar.current
        guard let monthAgo = calendar.date(byAdding: .day, value: -30, to: Date()) else { return [] }
        let recent = viewModel.allVisits.filter { $0.arrivedAt >= monthAgo }

        let grouped = Dictionary(grouping: recent) { $0.displayName }
        return grouped
            .map { name, visits in
                let total = visits.reduce(0.0) { acc, v in
                    let end = v.departedAt ?? Date()
                    return acc + end.timeIntervalSince(v.arrivedAt)
                }
                return PlaceTotal(id: name, name: name, count: visits.count, totalSeconds: total)
            }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "Top places")

            DSCard {
                let places = topPlaces
                if places.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                            DSRow(showDivider: index < places.count - 1) {
                                placeRow(place: place, rank: index + 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func placeRow(place: PlaceTotal, rank: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text("\(rank)")
                .font(DS.Font.headline())
                .foregroundStyle(DS.Color.textMuted)
                .frame(width: 22)
            CategoryIcon(symbol: paletteSymbol(for: place.name), palette: paletteFor(name: place.name), size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(DS.Font.body(.medium))
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineLimit(1)
                Text("\(place.count) \(place.count == 1 ? "visit" : "visits") · \(formatDuration(place.totalSeconds))")
                    .font(DS.Font.caption())
                    .foregroundStyle(DS.Color.textMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 28))
                .foregroundStyle(DS.Color.textMuted)
            Text("No visits in the last 30 days")
                .font(DS.Font.body())
                .foregroundStyle(DS.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }

    private func paletteFor(name: String) -> DS.Palette {
        let lower = name.lowercased()
        if lower.contains("home") { return .brown }
        if lower.contains("coffee") || lower.contains("cafe") || lower.contains("café") { return .peach }
        if lower.contains("beach") || lower.contains("park") { return .green }
        return .purple
    }

    private func paletteSymbol(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("home") { return "house.fill" }
        if lower.contains("coffee") || lower.contains("cafe") || lower.contains("café") { return "cup.and.saucer.fill" }
        if lower.contains("beach") { return "beach.umbrella.fill" }
        if lower.contains("park") { return "tree.fill" }
        if lower.contains("work") || lower.contains("office") { return "briefcase.fill" }
        if lower.contains("gym") { return "dumbbell.fill" }
        return "mappin.and.ellipse"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes < 60 { return "\(totalMinutes)m" }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }
}

// MARK: - Activity Breakdown

private struct ActivityBreakdownCard: View {
    let viewModel: LocationViewModel

    private struct Slice: Identifiable {
        let id: RouteSegment.ActivityType
        let activity: RouteSegment.ActivityType
        let meters: Double
    }

    private var slices: [Slice] {
        let calendar = Calendar.current
        guard let monthAgo = calendar.date(byAdding: .day, value: -30, to: Date()) else { return [] }
        let visits = viewModel.allVisits.filter { $0.arrivedAt >= monthAgo }
        let points = viewModel.locationPoints.filter { !$0.isOutlier && $0.timestamp >= monthAgo }

        let timeline = RouteReconstructor.timeline(visits: visits, points: points)
        let segments: [RouteSegment] = timeline.compactMap {
            if case .route(let s) = $0 { return s } else { return nil }
        }

        let totals: [RouteSegment.ActivityType: Double] = segments.reduce(into: [:]) { acc, segment in
            acc[segment.activity, default: 0] += segment.distanceMeters
        }
        return [RouteSegment.ActivityType.walking, .cycling, .driving]
            .map { Slice(id: $0, activity: $0, meters: totals[$0] ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "How you move")

            DSCard {
                let s = slices
                let total = s.map(\.meters).reduce(0, +)
                if total == 0 {
                    emptyState
                } else {
                    VStack(spacing: DS.Spacing.md) {
                        proportionBar(slices: s, total: total)
                        ForEach(s) { slice in
                            HStack(spacing: DS.Spacing.md) {
                                CategoryIcon(symbol: slice.activity.symbol, palette: slice.activity.palette, size: 32)
                                Text(slice.activity.label)
                                    .font(DS.Font.body(.medium))
                                    .foregroundStyle(DS.Color.textPrimary)
                                Spacer()
                                Text(percentage(slice.meters, of: total))
                                    .font(DS.Font.body(.semibold))
                                    .foregroundStyle(DS.Color.textPrimary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    private func proportionBar(slices: [Slice], total: Double) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(slices) { slice in
                    if slice.meters > 0 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(slice.activity.palette.icon)
                            .frame(width: max(2, geo.size.width * (slice.meters / total) - 2))
                    }
                }
            }
        }
        .frame(height: 12)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 28))
                .foregroundStyle(DS.Color.textMuted)
            Text("No movement segments in the last 30 days")
                .font(DS.Font.body())
                .foregroundStyle(DS.Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }

    private func percentage(_ value: Double, of total: Double) -> String {
        let pct = value / total * 100
        return String(format: "%.0f%%", pct)
    }
}
