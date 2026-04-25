import SwiftUI

struct TimelineView: View {
    let viewModel: LocationViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DS.Color.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        TimelineHeader(date: Date())
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.top, DS.Spacing.md)

                        if viewModel.todayTimeline.isEmpty {
                            TrackingHeroView(locationManager: viewModel.locationManager)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.top, DS.Spacing.lg)
                        } else {
                            TimelineList(entries: viewModel.todayTimeline)
                                .padding(.horizontal, DS.Spacing.lg)
                        }
                    }
                    .padding(.bottom, DS.Spacing.xxl)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Visit.self) { visit in
                VisitDetailView(visit: visit, viewModel: viewModel)
            }
            .navigationDestination(for: RouteSegment.self) { segment in
                RouteDetailView(segment: segment)
            }
        }
    }
}

// MARK: - Header

private struct TimelineHeader: View {
    let date: Date

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Text("Today")
                    .font(DS.Font.title())
                    .foregroundStyle(DS.Color.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.Color.textMuted)

                Spacer()

                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DS.Color.textPrimary)
                    .padding(8)
            }

            Text("Today's Timeline")
                .font(DS.Font.display())
                .foregroundStyle(DS.Color.textPrimary)

            Text(Self.weekdayFormatter.string(from: date))
                .font(DS.Font.body(.medium))
                .foregroundStyle(DS.Color.textMuted)
        }
    }
}

// MARK: - List

private struct TimelineList: View {
    let entries: [TimelineEntry]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                TimelineRow(
                    entry: entry,
                    isFirst: index == 0,
                    isLast: index == entries.count - 1
                )
            }
        }
    }
}

// MARK: - Row

private struct TimelineRow: View {
    let entry: TimelineEntry
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        switch entry {
        case .visit(let visit):
            NavigationLink(value: visit) {
                rowContent(
                    palette: paletteFor(visit: visit),
                    symbol: symbolFor(visit: visit),
                    title: visit.displayName,
                    timeRange: visit.formattedTimeRange,
                    secondary: visit.address ?? visit.locationName.flatMap { $0 == visit.displayName ? nil : $0 }
                )
            }
            .buttonStyle(.plain)
        case .route(let segment):
            NavigationLink(value: segment) {
                rowContent(
                    palette: segment.activity.palette,
                    symbol: segment.activity.symbol,
                    title: segment.activity.label,
                    timeRange: timeRange(for: segment),
                    secondary: routeSubtitle(for: segment)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func rowContent(
        palette: DS.Palette,
        symbol: String,
        title: String,
        timeRange: String,
        secondary: String?
    ) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ConnectorRail(palette: palette, isFirst: isFirst, isLast: isLast)

            DSCard(padding: DS.Spacing.md) {
                HStack(alignment: .center, spacing: DS.Spacing.md) {
                    CategoryIcon(symbol: symbol, palette: palette, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(DS.Font.headline())
                            .foregroundStyle(DS.Color.textPrimary)
                            .lineLimit(1)
                        Text(timeRange)
                            .font(DS.Font.caption(.medium))
                            .foregroundStyle(DS.Color.textSecondary)
                        if let secondary {
                            Text(secondary)
                                .font(DS.Font.caption())
                                .foregroundStyle(DS.Color.textMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func timeRange(for segment: RouteSegment) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: segment.startTime)) – \(f.string(from: segment.endTime))"
    }

    private func routeSubtitle(for segment: RouteSegment) -> String {
        let distance = formatDistance(segment.distanceMeters)
        let duration = formatDuration(segment.durationSeconds)
        return "\(distance) · \(duration)"
    }

    private func formatDistance(_ meters: Double) -> String {
        let useMetric = Locale.current.measurementSystem == .metric
        if useMetric {
            return meters >= 1000
                ? String(format: "%.1f km", meters / 1000)
                : String(format: "%d m", Int(meters))
        }
        let miles = meters / 1609.344
        return miles >= 0.1 ? String(format: "%.1f mi", miles) : String(format: "%d ft", Int(meters * 3.28084))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes < 60 { return "\(totalMinutes) min" }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }

    private func paletteFor(visit: Visit) -> DS.Palette {
        let lower = visit.displayName.lowercased()
        if lower.contains("home") { return .brown }
        if lower.contains("coffee") || lower.contains("cafe") || lower.contains("café") { return .peach }
        if lower.contains("beach") || lower.contains("park") { return .green }
        return .purple
    }

    private func symbolFor(visit: Visit) -> String {
        let lower = visit.displayName.lowercased()
        if lower.contains("home") { return "house.fill" }
        if lower.contains("coffee") || lower.contains("cafe") || lower.contains("café") { return "cup.and.saucer.fill" }
        if lower.contains("beach") { return "beach.umbrella.fill" }
        if lower.contains("park") { return "tree.fill" }
        if lower.contains("work") || lower.contains("office") { return "briefcase.fill" }
        if lower.contains("gym") { return "dumbbell.fill" }
        return "mappin.and.ellipse"
    }
}

// MARK: - Connector rail

private struct ConnectorRail: View {
    let palette: DS.Palette
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : palette.icon.opacity(0.4))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .frame(height: 12)
            Circle()
                .fill(palette.icon)
                .frame(width: 10, height: 10)
            Rectangle()
                .fill(isLast ? Color.clear : palette.icon.opacity(0.4))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 16)
    }
}

// MARK: - Empty state

private struct TimelineEmptyState: View {
    var body: some View {
        DSCard {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(DS.Color.textMuted)
                Text("Nothing yet today")
                    .font(DS.Font.headline())
                    .foregroundStyle(DS.Color.textPrimary)
                Text("Visits and routes you record will appear here.")
                    .font(DS.Font.body())
                    .foregroundStyle(DS.Color.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, DS.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
    }
}

